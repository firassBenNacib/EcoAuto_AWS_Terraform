import os

import boto3
from botocore.exceptions import ClientError


def lambda_handler(event, context):
    asg = boto3.client("autoscaling")
    rds = boto3.client("rds")

    asg_name = os.environ["ASG_NAME"]
    rds_id = os.environ["RDS_INSTANCE_ID"]

    min_size = int(os.getenv("START_MIN_SIZE", "1"))
    desired_capacity = int(os.getenv("START_DESIRED_CAPACITY", "1"))
    max_size = int(os.getenv("START_MAX_SIZE", "2"))

    started = False
    errors = []

    try:
        asg.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            MinSize=min_size,
            DesiredCapacity=desired_capacity,
            MaxSize=max_size,
        )
        print(
            f"Scaled ASG '{asg_name}' to MinSize={min_size}, "
            f"DesiredCapacity={desired_capacity}, MaxSize={max_size}."
        )
        started = True
    except ClientError as error:
        message = f"Error scaling ASG '{asg_name}': {error}"
        print(message)
        errors.append(message)

    try:
        asg.resume_processes(
            AutoScalingGroupName=asg_name,
            ScalingProcesses=["Launch", "ReplaceUnhealthy"],
        )
        print("Resumed Launch and ReplaceUnhealthy processes")
    except ClientError as error:
        message = f"Failed to resume ASG processes for '{asg_name}': {error}"
        print(message)
        errors.append(message)

    try:
        response = rds.describe_db_instances(DBInstanceIdentifier=rds_id)
        db_instance = response["DBInstances"][0]
        state = db_instance["DBInstanceStatus"]

        if state == "stopped":
            rds.start_db_instance(DBInstanceIdentifier=rds_id)
            print(f"Starting RDS instance: {rds_id}")
        else:
            print(f"RDS '{rds_id}' is in state '{state}', skipping start.")
    except ClientError as error:
        message = f"Error checking/starting RDS '{rds_id}': {error}"
        print(message)
        errors.append(message)

    if errors:
        raise RuntimeError(" ; ".join(errors))

    return {
        "status": "asg_scaled_up_and_rds_checked",
        "asg": asg_name,
        "asg_scaled": started,
        "rds_instance": rds_id,
    }
