import boto3
import os
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    asg = boto3.client('autoscaling')
    rds = boto3.client('rds')

    asg_name = os.environ['ASG_NAME']
    rds_id = os.environ['RDS_INSTANCE_ID']

    started = False

    try:
        asg.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            MinSize=1,
            DesiredCapacity=1,
            MaxSize=2
        )
        print(f"Scaled up ASG '{asg_name}' to desired capacity 1.")
        started = True
    except ClientError as e:
        print(f"Error scaling ASG: {e}")

    try:
        asg.resume_processes(
            AutoScalingGroupName=asg_name,
            ScalingProcesses=['Launch', 'ReplaceUnhealthy']
        )
        print("Resumed Launch and ReplaceUnhealthy")
    except ClientError as e:
        print(f"Failed to resume processes: {e}")

 
    try:
        response = rds.describe_db_instances(DBInstanceIdentifier=rds_id)
        db_instance = response['DBInstances'][0]
        state = db_instance['DBInstanceStatus']

        if state == 'stopped':
            rds.start_db_instance(DBInstanceIdentifier=rds_id)
            print(f"Starting RDS instance: {rds_id}")
        else:
            print(f"RDS '{rds_id}' is in state '{state}', skipping start.")
    except ClientError as e:
        print(f"Error checking/starting RDS: {e}")

    return {
        'status': 'asg_scaled_up_and_rds_checked',
        'asg': asg_name,
        'asg_scaled': started,
        'rds_instance': rds_id
    }
