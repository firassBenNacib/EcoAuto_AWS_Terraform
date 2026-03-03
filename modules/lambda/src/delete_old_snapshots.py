import datetime
import os

import boto3

RDS_INSTANCE_ID = os.environ.get("RDS_INSTANCE_ID")
SNAPSHOT_PREFIX = f"{RDS_INSTANCE_ID}-manual-"
SNAPSHOT_RETENTION_DAYS = int(os.environ.get("SNAPSHOT_RETENTION_DAYS", "14"))
SNAPSHOT_MIN_KEEP_COUNT = int(os.environ.get("SNAPSHOT_MIN_KEEP_COUNT", "3"))


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


def lambda_handler(event, context):
    rds = boto3.client("rds")

    all_snapshots = _list_manual_snapshots(rds, RDS_INSTANCE_ID)

    snapshots = [
        snapshot
        for snapshot in all_snapshots
        if snapshot["DBSnapshotIdentifier"].startswith(SNAPSHOT_PREFIX)
    ]

    snapshots.sort(key=lambda snapshot: snapshot["SnapshotCreateTime"], reverse=True)
    protected_snapshot_ids = {
        snapshot["DBSnapshotIdentifier"] for snapshot in snapshots[:SNAPSHOT_MIN_KEEP_COUNT]
    }

    cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=SNAPSHOT_RETENTION_DAYS)
    to_delete = []
    for snapshot in snapshots:
        snapshot_id = snapshot["DBSnapshotIdentifier"]
        snapshot_time = snapshot["SnapshotCreateTime"]
        if snapshot_id in protected_snapshot_ids:
            continue
        if snapshot_time < cutoff:
            to_delete.append(snapshot)

    for snapshot in to_delete:
        snapshot_id = snapshot["DBSnapshotIdentifier"]
        print(f"Deleting snapshot: {snapshot_id}")
        rds.delete_db_snapshot(DBSnapshotIdentifier=snapshot_id)

    return {
        "status": "completed",
        "total_snapshots": len(snapshots),
        "deleted": len(to_delete),
        "retention_days": SNAPSHOT_RETENTION_DAYS,
        "min_keep_count": SNAPSHOT_MIN_KEEP_COUNT,
    }
