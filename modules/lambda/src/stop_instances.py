import datetime
import os
import time

import boto3
from botocore.exceptions import ClientError


def _list_manual_snapshots(rds_client, rds_instance_id):
    snapshots = []
    marker = None

    while True:
        params = {
            "DBInstanceIdentifier": rds_instance_id,
            "SnapshotType": "manual",
        }
        if marker:
            params["Marker"] = marker

        response = rds_client.describe_db_snapshots(**params)
        snapshots.extend(response.get("DBSnapshots", []))

        marker = response.get("Marker")
        if not marker:
            break

    return snapshots


def _find_latest_daily_snapshot(rds_client, rds_instance_id, daily_prefix):
    all_snapshots = _list_manual_snapshots(rds_client, rds_instance_id)
    matches = [
        snapshot
        for snapshot in all_snapshots
        if snapshot["DBSnapshotIdentifier"].startswith(daily_prefix)
    ]
    if not matches:
        return None
    matches.sort(key=lambda snapshot: snapshot["SnapshotCreateTime"], reverse=True)
    return matches[0]


def _wait_for_snapshot_available(rds_client, snapshot_id, wait_seconds, poll_interval_seconds):
    deadline = time.monotonic() + wait_seconds

    while True:
        response = rds_client.describe_db_snapshots(DBSnapshotIdentifier=snapshot_id)
        snapshots = response.get("DBSnapshots", [])
        if not snapshots:
            raise RuntimeError(f"Snapshot '{snapshot_id}' was not found while waiting for readiness.")

        snapshot_state = snapshots[0]["Status"]
        if snapshot_state == "available":
            return snapshot_state

        if snapshot_state in ("failed", "deleted", "deleting"):
            raise RuntimeError(f"Snapshot '{snapshot_id}' entered terminal state '{snapshot_state}'.")

        remaining_seconds = int(deadline - time.monotonic())
        if remaining_seconds <= 0:
            return snapshot_state

        sleep_seconds = min(poll_interval_seconds, remaining_seconds)
        print(
            f"Snapshot '{snapshot_id}' is '{snapshot_state}'. "
            f"Waiting {sleep_seconds}s (remaining budget: {remaining_seconds}s)."
        )
        time.sleep(sleep_seconds)


def lambda_handler(event, context):
    asg = boto3.client("autoscaling")
    rds = boto3.client("rds")

    asg_name = os.environ["ASG_NAME"]
    rds_id = os.environ["RDS_INSTANCE_ID"]
    snapshot_wait_seconds = int(os.getenv("STOP_SNAPSHOT_WAIT_SECONDS", "240"))
    snapshot_poll_interval_seconds = int(os.getenv("STOP_SNAPSHOT_POLL_INTERVAL_SECONDS", "20"))
    errors = []
    snapshot_status = "not-requested"

    try:
        asg.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            MinSize=0,
            DesiredCapacity=0,
        )
        print("Set ASG MinSize and DesiredCapacity to 0")
    except ClientError as error:
        message = f"Failed to update ASG '{asg_name}': {error}"
        print(message)
        errors.append(message)

    try:
        asg.suspend_processes(
            AutoScalingGroupName=asg_name,
            ScalingProcesses=["Launch", "ReplaceUnhealthy"],
        )
        print("Suspended Launch and ReplaceUnhealthy processes")
    except ClientError as error:
        message = f"Failed to suspend ASG processes for '{asg_name}': {error}"
        print(message)
        errors.append(message)

    if rds_id:
        try:
            response = rds.describe_db_instances(DBInstanceIdentifier=rds_id)
            db_instance = response["DBInstances"][0]
            state = db_instance["DBInstanceStatus"]
            print(f"RDS '{rds_id}' current state: {state}")

            if state == "available":
                utc_day = datetime.datetime.utcnow().strftime("%Y%m%d")
                daily_prefix = f"{rds_id}-manual-{utc_day}"
                latest_daily_snapshot = _find_latest_daily_snapshot(rds, rds_id, daily_prefix)
                snapshot_id = None

                if latest_daily_snapshot is None:
                    snapshot_id = f"{rds_id}-manual-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
                    print(f"Creating snapshot: {snapshot_id}")
                    rds.create_db_snapshot(
                        DBInstanceIdentifier=rds_id,
                        DBSnapshotIdentifier=snapshot_id,
                    )
                    snapshot_status = "creating"
                else:
                    snapshot_id = latest_daily_snapshot["DBSnapshotIdentifier"]
                    snapshot_status = latest_daily_snapshot["Status"]

                if snapshot_status != "available":
                    snapshot_status = _wait_for_snapshot_available(
                        rds_client=rds,
                        snapshot_id=snapshot_id,
                        wait_seconds=snapshot_wait_seconds,
                        poll_interval_seconds=snapshot_poll_interval_seconds,
                    )

                if snapshot_status != "available":
                    raise RuntimeError(
                        f"Snapshot '{snapshot_id}' is in state '{snapshot_status}' after waiting "
                        f"{snapshot_wait_seconds}s; retry later before stopping RDS."
                    )

                print(f"Stopping RDS instance: {rds_id}")
                rds.stop_db_instance(DBInstanceIdentifier=rds_id)
            elif state in ("stopped", "stopping"):
                print(f"RDS is in state '{state}', skipping stop")
            else:
                raise RuntimeError(f"RDS '{rds_id}' is in state '{state}', retry later.")
        except ClientError as error:
            message = f"Error handling RDS '{rds_id}': {error}"
            print(message)
            errors.append(message)
        except RuntimeError as error:
            message = str(error)
            print(message)
            errors.append(message)

    if errors:
        raise RuntimeError(" ; ".join(errors))

    return {
        "status": "stopped_rds_and_ec2",
        "asg": asg_name,
        "terminated_instances": [],
        "rds_instance": rds_id,
        "snapshot_status": snapshot_status,
    }
