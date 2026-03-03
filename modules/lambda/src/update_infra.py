import json
import os
import hashlib
import random
import time
import urllib.error
import urllib.request

import boto3
from botocore.exceptions import ClientError, ConnectionClosedError, EndpointConnectionError, ReadTimeoutError


def _get_running_public_dns_for_asg(asg_name: str) -> list[str]:
    asg_client = boto3.client("autoscaling")
    ec2_client = boto3.client("ec2")

    response = asg_client.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
    groups = response.get("AutoScalingGroups", [])
    if not groups:
        raise RuntimeError(f"Auto Scaling Group not found: {asg_name}")

    instance_ids = [
        instance["InstanceId"]
        for instance in groups[0].get("Instances", [])
        if instance.get("LifecycleState") == "InService"
    ]

    if not instance_ids:
        return []

    reservations = ec2_client.describe_instances(
        InstanceIds=instance_ids,
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}],
    ).get("Reservations", [])

    dns_names = []
    for reservation in reservations:
        for instance in reservation.get("Instances", []):
            dns_name = instance.get("PublicDnsName")
            if dns_name:
                dns_names.append(dns_name)

    return sorted(set(dns_names))


def _origin_id_for_domain(domain_name: str) -> str:
    digest = hashlib.sha1(domain_name.encode("utf-8")).hexdigest()[:12]
    return f"backend-origin-{digest}"


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _normalize_path(path: str) -> str:
    return path if path.startswith("/") else f"/{path}"


def _is_retryable_cloudfront_error(error: Exception) -> bool:
    if isinstance(error, ClientError):
        code = error.response.get("Error", {}).get("Code", "")
        retryable_codes = {
            "Throttling",
            "ThrottlingException",
            "TooManyRequestsException",
            "ServiceUnavailable",
            "InternalError",
            "RequestTimeout",
            "PriorRequestNotComplete",
        }
        return code in retryable_codes

    return isinstance(error, (EndpointConnectionError, ConnectionClosedError, ReadTimeoutError))


def _call_with_backoff(
    operation_name: str,
    fn,
    *args,
    max_attempts: int,
    base_backoff_seconds: int,
    max_backoff_seconds: int,
    **kwargs,
):
    attempt = 1
    while attempt <= max_attempts:
        try:
            return fn(*args, **kwargs)
        except Exception as error:
            should_retry = attempt < max_attempts and _is_retryable_cloudfront_error(error)
            if not should_retry:
                raise

            sleep_seconds = min(max_backoff_seconds, base_backoff_seconds * (2 ** (attempt - 1)))
            jitter_seconds = random.uniform(0, sleep_seconds / 4)
            wait_seconds = sleep_seconds + jitter_seconds
            print(
                f"{operation_name} attempt {attempt} failed with retryable error: {error}. "
                f"Retrying in {wait_seconds:.2f}s."
            )
            time.sleep(wait_seconds)
            attempt += 1


def _probe_origin(
    domain_name: str,
    backend_port: int,
    health_path: str,
    use_https: bool,
    timeout_seconds: int,
    headers: dict[str, str] | None = None,
) -> bool:
    scheme = "https" if use_https else "http"
    url = f"{scheme}://{domain_name}:{backend_port}{health_path}"
    req = urllib.request.Request(url=url, method="GET", headers=headers or {})

    try:
        with urllib.request.urlopen(req, timeout=timeout_seconds) as response:
            return 200 <= response.status < 400
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        print(f"Health probe failed for {domain_name}: {error}")
        return False


def _build_origin(
    domain_name: str,
    origin_id: str,
    origin_domains: str,
    backend_port: int,
    auth_headers: list[tuple[str, str]],
    origin_protocol_policy: str,
) -> dict:
    headers = [{"HeaderName": "x-origin-list", "HeaderValue": origin_domains}]
    headers.extend([{"HeaderName": name, "HeaderValue": value} for name, value in auth_headers if value])

    return {
        "Id": origin_id,
        "DomainName": domain_name,
        "OriginPath": "",
        "CustomOriginConfig": {
            "HTTPPort": backend_port,
            "HTTPSPort": backend_port,
            "OriginProtocolPolicy": origin_protocol_policy,
            "OriginSslProtocols": {"Quantity": 1, "Items": ["TLSv1.2"]},
            "OriginReadTimeout": 30,
            "OriginKeepaliveTimeout": 5,
        },
        "CustomHeaders": {
            "Quantity": len(headers),
            "Items": headers,
        },
    }


def _is_backend_origin(origin: dict) -> bool:
    origin_id = origin.get("Id", "")
    return origin_id.startswith("backend-origin")


def _origin_signature(origin: dict) -> dict:
    custom_origin_config = origin.get("CustomOriginConfig", {})
    custom_headers = {
        header.get("HeaderName", "").lower(): header.get("HeaderValue", "")
        for header in origin.get("CustomHeaders", {}).get("Items", [])
        if header.get("HeaderName")
    }

    return {
        "Id": origin.get("Id"),
        "DomainName": origin.get("DomainName"),
        "HTTPPort": custom_origin_config.get("HTTPPort"),
        "HTTPSPort": custom_origin_config.get("HTTPSPort"),
        "OriginProtocolPolicy": custom_origin_config.get("OriginProtocolPolicy"),
        "CustomHeaders": custom_headers,
    }


def _backend_origins_equal(current_origins: list[dict], desired_origins: list[dict]) -> bool:
    if len(current_origins) != len(desired_origins):
        return False

    current_by_id = {}
    for origin in current_origins:
        signature = _origin_signature(origin)
        current_by_id[signature["Id"]] = signature

    desired_by_id = {}
    for origin in desired_origins:
        signature = _origin_signature(origin)
        desired_by_id[signature["Id"]] = signature

    return current_by_id == desired_by_id


def lambda_handler(event, context):
    cloudfront_distribution_id = os.environ["CLOUDFRONT_DIST_ID"]
    asg_name = os.environ["ASG_NAME"]
    backend_port = int(os.getenv("BACKEND_PORT", "8080"))
    max_origins = int(os.getenv("MAX_ORIGINS", "20"))
    origin_protocol_policy = os.getenv("ORIGIN_PROTOCOL_POLICY", "http-only").strip().lower()

    enable_origin_auth_header = _env_bool("ENABLE_ORIGIN_AUTH_HEADER", True)
    origin_auth_header_name = os.getenv("ORIGIN_AUTH_HEADER_NAME", "X-Origin-Verify")
    origin_auth_header_value = os.getenv("ORIGIN_AUTH_HEADER_VALUE", "")
    origin_auth_previous_header_name = os.getenv("ORIGIN_AUTH_PREVIOUS_HEADER_NAME", "X-Origin-Verify-Prev")
    origin_auth_previous_header_value = os.getenv("ORIGIN_AUTH_PREVIOUS_HEADER_VALUE", "")

    enable_origin_health_probe = _env_bool("ENABLE_ORIGIN_HEALTH_PROBE", True)
    origin_health_fail_open = _env_bool("ORIGIN_HEALTH_FAIL_OPEN", True)
    origin_health_path = _normalize_path(os.getenv("ORIGIN_HEALTH_PATH", "/health"))
    origin_health_timeout_seconds = int(os.getenv("ORIGIN_HEALTH_TIMEOUT_SECONDS", "2"))
    use_https_for_probe = origin_protocol_policy == "https-only"
    cloudfront_api_max_attempts = int(os.getenv("CLOUDFRONT_API_MAX_ATTEMPTS", "5"))
    cloudfront_api_base_backoff_seconds = int(os.getenv("CLOUDFRONT_API_BASE_BACKOFF_SECONDS", "1"))
    cloudfront_api_max_backoff_seconds = int(os.getenv("CLOUDFRONT_API_MAX_BACKOFF_SECONDS", "16"))

    cf_client = boto3.client("cloudfront")

    auth_headers = []
    if enable_origin_auth_header and origin_auth_header_value:
        auth_headers.append((origin_auth_header_name, origin_auth_header_value))
    if enable_origin_auth_header and origin_auth_previous_header_value:
        auth_headers.append((origin_auth_previous_header_name, origin_auth_previous_header_value))
    probe_headers = {name: value for name, value in auth_headers if value}

    public_dns_list = _get_running_public_dns_for_asg(asg_name)
    if len(public_dns_list) > max_origins:
        public_dns_list = public_dns_list[:max_origins]

    dist_config_response = _call_with_backoff(
        "get_distribution_config",
        cf_client.get_distribution_config,
        Id=cloudfront_distribution_id,
        max_attempts=cloudfront_api_max_attempts,
        base_backoff_seconds=cloudfront_api_base_backoff_seconds,
        max_backoff_seconds=cloudfront_api_max_backoff_seconds,
    )
    config = dist_config_response["DistributionConfig"]
    current_origins = config.get("Origins", {}).get("Items", [])
    non_backend_origins = [origin for origin in current_origins if not _is_backend_origin(origin)]

    if enable_origin_health_probe and public_dns_list:
        healthy_dns_list = [
            dns_name
            for dns_name in public_dns_list
            if _probe_origin(
                domain_name=dns_name,
                backend_port=backend_port,
                health_path=origin_health_path,
                use_https=use_https_for_probe,
                timeout_seconds=origin_health_timeout_seconds,
                headers=probe_headers,
            )
        ]
        if healthy_dns_list:
            public_dns_list = healthy_dns_list
        else:
            if origin_health_fail_open:
                print(
                    "No healthy origins were found by direct Lambda probes. "
                    "Continuing with the full running ASG origin list because ORIGIN_HEALTH_FAIL_OPEN=true."
                )
            else:
                return {
                    "statusCode": 200,
                    "body": json.dumps(
                        {
                            "message": "No healthy origins found; CloudFront origins unchanged",
                            "asg_name": asg_name,
                            "origin_count": 0,
                        }
                    ),
                }

    if not public_dns_list:
        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "No running in-service instances found in ASG; CloudFront origins unchanged",
                    "asg_name": asg_name,
                    "origin_count": 0,
                }
            ),
        }

    origin_domains = ",".join(public_dns_list)
    backend_origins = [
        _build_origin(
            domain_name=dns_name,
            origin_id=_origin_id_for_domain(dns_name),
            origin_domains=origin_domains,
            backend_port=backend_port,
            auth_headers=auth_headers,
            origin_protocol_policy=origin_protocol_policy,
        )
        for dns_name in public_dns_list
    ]
    target_origin_id = backend_origins[0]["Id"]

    current_backend_origins = [origin for origin in current_origins if _is_backend_origin(origin)]
    current_target_origin_id = config.get("DefaultCacheBehavior", {}).get("TargetOriginId")
    if _backend_origins_equal(current_backend_origins, backend_origins) and current_target_origin_id == target_origin_id:
        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "CloudFront backend origins already up-to-date",
                    "asg_name": asg_name,
                    "origin_count": len(public_dns_list),
                    "origins": public_dns_list,
                }
            ),
        }

    merged_origins = non_backend_origins + backend_origins
    config["Origins"] = {"Quantity": len(merged_origins), "Items": merged_origins}
    config["DefaultCacheBehavior"]["TargetOriginId"] = target_origin_id

    _call_with_backoff(
        "update_distribution",
        cf_client.update_distribution,
        Id=cloudfront_distribution_id,
        IfMatch=dist_config_response["ETag"],
        DistributionConfig=config,
        max_attempts=cloudfront_api_max_attempts,
        base_backoff_seconds=cloudfront_api_base_backoff_seconds,
        max_backoff_seconds=cloudfront_api_max_backoff_seconds,
    )

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "CloudFront backend origins updated",
                "asg_name": asg_name,
                "origin_count": len(public_dns_list),
                "origins": public_dns_list,
            }
        ),
    }
