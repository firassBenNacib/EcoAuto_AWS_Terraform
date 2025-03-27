import boto3
import os
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    asg = boto3.client('autoscaling')
    ec2 = boto3.client('ec2')
    rds = boto3.client('rds')

    asg_name = os.environ['ASG_NAME']
    rds_id = os.environ['RDS_INSTANCE_ID']

    terminated_instances = []

    try:
        response = asg.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
        instances = response['AutoScalingGroups'][0]['Instances']
        instance_ids = [i['InstanceId'] for i in instances if i['LifecycleState'] == 'InService']
        print(f"ASG instances: {instance_ids}")
    except Exception as e:
        print(f"Error fetching ASG instances: {e}")
        instance_ids = []

    try:
        asg.update_auto_scaling_group(
            AutoScalingGroupName=asg_name,
            MinSize=0,
            DesiredCapacity=0
        )
        print("ASG MinSize and DesiredCapacity set to 0")
    except ClientError as e:
        print(f"Failed to update ASG config: {e}")

    for instance_id in instance_ids:
        try:
            asg.terminate_instance_in_auto_scaling_group(
                InstanceId=instance_id,
                ShouldDecrementDesiredCapacity=True
            )
            print(f"Terminated instance: {instance_id}")
            terminated_instances.append(instance_id)
        except ClientError as e:
            print(f"Failed to terminate instance {instance_id}: {e}")

    if rds_id:
        try:
            response = rds.describe_db_instances(DBInstanceIdentifier=rds_id)
            db_instance = response['DBInstances'][0]
            state = db_instance['DBInstanceStatus']

            if state == 'available':
                rds.stop_db_instance(DBInstanceIdentifier=rds_id)
                print(f"Stopping RDS instance: {rds_id}")
            else:
                print(f"RDS '{rds_id}' is in state '{state}', skipping stop.")
        except ClientError as e:
            print(f"Error checking/stopping RDS: {e}")

    return {
        'status': 'manual_ec2_terminated_and_rds_stopped',
        'asg': asg_name,
        'terminated_instances': terminated_instances,
        'rds_instance': rds_id
    }
