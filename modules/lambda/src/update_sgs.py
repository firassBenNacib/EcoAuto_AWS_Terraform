import json
import os
import urllib.request
import boto3

REGION = 'your-region'
PORT = 8088    # change to your backend port #  443 for HTTPS
MAX_RULES_PER_SG = 50

def lambda_handler(event, context):
    try:
        
        service = None
        try:
           
            message = json.loads(event['Records'][0]['Sns']['Message'])
            service = message.get('service')
        except (KeyError, IndexError, json.JSONDecodeError):
            print("No SNS message detected - likely manual or scheduled trigger")

       
        if service and service != "CLOUDFRONT":
            print(f"Ignored event for service: {service}")
            return {
                'statusCode': 200,
                'body': json.dumps(f"Ignored event for service: {service}")
            }

        print("Processing CloudFront IP range update...")

        
        sg_ids_env = os.environ.get('SECURITY_GROUP_IDS')
        if not sg_ids_env:
            raise ValueError("SECURITY_GROUP_IDS environment variable not set.")

        security_group_ids = sg_ids_env.split(',')

        
        url = 'https://ip-ranges.amazonaws.com/ip-ranges.json'
        response = urllib.request.urlopen(url, timeout=10)
        data = json.loads(response.read())

        
        cloudfront_ips = [
            prefix['ip_prefix']
            for prefix in data['prefixes']
            if prefix['service'] == 'CLOUDFRONT' and prefix['region'] == 'GLOBAL'
        ]

        
        chunks = [
            cloudfront_ips[i:i + MAX_RULES_PER_SG]
            for i in range(0, len(cloudfront_ips), MAX_RULES_PER_SG)
        ]

        ec2 = boto3.client('ec2', region_name=REGION)
        updated_sgs = 0

        for i, sg_id in enumerate(security_group_ids):
            sg_info = ec2.describe_security_groups(GroupIds=[sg_id])['SecurityGroups'][0]
            current_rules = sg_info['IpPermissions']

            
            for rule in current_rules:
                if rule['IpProtocol'] == 'tcp' and rule.get('FromPort') == PORT:
                    ec2.revoke_security_group_ingress(GroupId=sg_id, IpPermissions=[rule])

            
            if i < len(chunks):
                ip_chunk = chunks[i]
                new_rules = [{
                    'IpProtocol': 'tcp',
                    'FromPort': PORT,
                    'ToPort': PORT,
                    'IpRanges': [{'CidrIp': ip, 'Description': 'CloudFront IP'} for ip in ip_chunk]
                }]
                ec2.authorize_security_group_ingress(GroupId=sg_id, IpPermissions=new_rules)
                updated_sgs += 1

        return {
            'statusCode': 200,
            'body': json.dumps(f"Updated {updated_sgs} SGs with {len(cloudfront_ips)} CloudFront IPs")
        }

    except Exception as e:
        print(f"Error occurred: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error: {str(e)}")
        }

