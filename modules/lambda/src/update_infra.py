import boto3
import os
import json

def lambda_handler(event, context):
    ec2_client = boto3.client('ec2')
    cf_client = boto3.client('cloudfront')
    route53_client = boto3.client('route53')

    cloudfront_distribution_id = os.environ['CLOUDFRONT_DIST_ID']
    hosted_zone_id = os.environ['ROUTE53_ZONE_ID']
    frontend_cf_domain = os.environ['FRONTEND_CF_DOMAIN']
    backend_cf_alias = os.environ['BACKEND_ALIAS']
    frontend_cf_alias = os.environ['FRONTEND_ALIAS']

    try:
        
        instances_response = ec2_client.describe_instances(
            Filters=[
                {'Name': 'tag:Name', 'Values': ['backend-app']},
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )

        public_dns_list = [
            instance['PublicDnsName']
            for reservation in instances_response['Reservations']
            for instance in reservation['Instances']
            if instance.get('PublicDnsName')
        ]

        if not public_dns_list:
            raise Exception("No running EC2 instance found with tag Name=backend-app")

        print(f"Running EC2 public DNS names: {public_dns_list}")

        
        dist_config_response = cf_client.get_distribution_config(Id=cloudfront_distribution_id)
        etag = dist_config_response['ETag']
        config = dist_config_response['DistributionConfig']

        origin_domains = ','.join(public_dns_list)

        if len(public_dns_list) == 1:

            config['Origins'] = {
                'Quantity': 1,
                'Items': [{
                    'Id': 'backend-origin',
                    'DomainName': public_dns_list[0],
                    'OriginPath': "",
                    'CustomOriginConfig': {
                        'HTTPPort': 8088, #change to your backend port
                        'HTTPSPort': 443,
                        'OriginProtocolPolicy': 'http-only',
                        'OriginSslProtocols': {
                            'Quantity': 1,
                            'Items': ['TLSv1.2']
                        },
                        'OriginReadTimeout': 30,
                        'OriginKeepaliveTimeout': 5
                    },
                    'CustomHeaders': {
                        'Quantity': 1,
                        'Items': [{
                            'HeaderName': 'x-origin-list',
                            'HeaderValue': origin_domains
                        }]
                    }
                }]
            }
            config['DefaultCacheBehavior']['TargetOriginId'] = 'backend-origin'
            print(f"CloudFront set to single origin: backend-origin -> {public_dns_list[0]}")
        else:
           
            new_origins = []
            for idx, dns in enumerate(public_dns_list):
                origin_id = f"backend-origin-{idx+1}"
                new_origins.append({
                    'Id': origin_id,
                    'DomainName': dns,
                    'OriginPath': "",
                    'CustomOriginConfig': {
                        'HTTPPort': 8088,  #change to your backend port
                        'HTTPSPort': 443,
                        'OriginProtocolPolicy': 'http-only',
                        'OriginSslProtocols': {
                            'Quantity': 1,
                            'Items': ['TLSv1.2']
                        },
                        'OriginReadTimeout': 30,
                        'OriginKeepaliveTimeout': 5
                    },
                    'CustomHeaders': {
                        'Quantity': 1,
                        'Items': [{
                            'HeaderName': 'x-origin-list',
                            'HeaderValue': origin_domains
                        }]
                    }
                })

            config['Origins'] = {
                'Quantity': len(new_origins),
                'Items': new_origins
            }

            config['DefaultCacheBehavior']['TargetOriginId'] = 'backend-origin-1'
            print(f"CloudFront set to {len(new_origins)} origins, defaulting to backend-origin-1")

        
        update_response = cf_client.update_distribution(
            Id=cloudfront_distribution_id,
            IfMatch=etag,
            DistributionConfig=config
        )
        print("✅ CloudFront updated")

        
        change_batch = {
            "Changes": [
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": backend_cf_alias,
                        "Type": "A",
                        "AliasTarget": {
                            "HostedZoneId": "your-route53-zone-id",
                            "DNSName": update_response['Distribution']['DomainName'],
                            "EvaluateTargetHealth": False
                        }
                    }
                },
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": frontend_cf_alias,
                        "Type": "A",
                        "AliasTarget": {
                            "HostedZoneId": "your-route53-zone-id",
                            "DNSName": frontend_cf_domain,
                            "EvaluateTargetHealth": False
                        }
                    }
                },
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": f"www.{frontend_cf_alias}",
                        "Type": "A",
                        "AliasTarget": {
                            "HostedZoneId": "your-route53-zone-id",
                            "DNSName": frontend_cf_domain,
                            "EvaluateTargetHealth": False
                        }
                    }
                }
            ]
        }

        route53_client.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch=change_batch
        )

        print("Route 53 updated")
        return {
            'statusCode': 200,
            'body': json.dumps(f"Updated CloudFront with {len(public_dns_list)} EC2 origins.")
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        raise e
