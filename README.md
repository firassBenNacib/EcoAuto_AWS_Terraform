# EcoAuto AWS Terraform

This is my terraform project that provisions a modular, cost-optimized, auto-scaled, and resilient AWS infrastructure. It is composed of multiple reusable Terraform modules for EC2 with Auto Scaling, RDS, S3 static hosting, CloudFront (frontend and backend distributions with Lambda@Edge), IAM roles, security groups, and CloudWatch automation for lifecycle and routing management using serverless Lambda functions.

It does NOT include any application-specific code or business logic — it is designed to be plugged into a wide range of backend/frontend use cases.

> ⚡️ **Lambda@Edge for backend origin routing**  
> This module uses a low-cost Lambda@Edge function to dynamically route CloudFront requests to running EC2 instances. While it's a cost-effective alternative to using an Application Load Balancer (ALB), using ALB is still the recommended option for production-grade systems requiring robust health checks and native load balancing.



- [EcoAuto AWS Terraform](#ecoauto-aws-terraform)
  - [Prerequisites](#prerequisites)
  - [Resource Types](#resource-types)
  - [Features](#features)
  - [Lambda Functions Explained](#lambda-functions-explained)
  - [IAM Roles & Permissions](#iam-roles--permissions)
  - [Inputs](#inputs)
  - [Outputs](#outputs)
  - [Deployment Notes](#%EF%B8%8F-deployment-notes)
  - [License](#license)
  - [Authors](#authors)

## Prerequisites

Before you start using this project, ensure you have the following prerequisites set up and ready:

- **AWS Account**: You need an active AWS account. Sign up or log in at [AWS Management Console](https://aws.amazon.com/console/).
- **Terraform Installed**: Install Terraform (version 0.14 or later). Download it from [Terraform's official site](https://www.terraform.io/downloads).
- **AWS CLI Installed** *(Optional but recommended)*: For managing AWS credentials and services. See [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
- **Git**: For cloning the repository and version control. [Install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) if you haven't already.

## Resource Types

* aws_autoscaling_group  
* aws_launch_template  
* aws_db_instance  
* aws_s3_bucket  
* aws_cloudfront_distribution  
* aws_lambda_function  
* aws_iam_role  
* aws_security_group  
* aws_cloudwatch_event_rule  
* aws_route53_record  

## Features

These modules provide a flexible and automated foundation for hosting cost-efficient applications using EC2 and RDS, with global delivery via CloudFront.

- Scheduled RDS and EC2 start/stop with Lambda + EventBridge  
- EC2 Auto Scaling with CPU-based policies  
- S3 static website hosting with CloudFront (OAC secured)  
- Lambda@Edge-based origin switching for backend EC2 (low-cost ALB alternative)  
- IAM roles and policies are designed to follow the least-privilege principle for all services, including Lambda and EC2
- Security groups auto-updated with latest CloudFront IPs  
- Route53 alias records for frontend/backend  

> Lambda functions are triggered via CloudWatch Events for start/stop schedules and EC2 lifecycle events to update backend routing and security rules dynamically.


## Lambda Functions Explained

| Function                               | Description                                                  | Trigger                          |
|----------------------------------------|--------------------------------------------------------------|----------------------------------|
| `UpdateEC2SecurityGroupFromCloudFrontIPs` | Updates SG with latest CloudFront IPs                         | CloudWatch (EC2 state change)    |
| `UpdateInfraRouting`                   | Updates backend origin and Route53 DNS records               | CloudWatch (EC2 lifecycle)       |
| `StartComputeResources`                | Starts EC2 and RDS instances at scheduled times              | EventBridge (cron)               |
| `StopComputeResources`                 | Stops EC2 and RDS instances at scheduled times               | EventBridge (cron)               |
| `EdgeOriginSelector` (Lambda@Edge)     | Dynamic origin routing to backend EC2 via CloudFront header  | CloudFront (origin-request)      |


## IAM Roles & Permissions

This project provisions several IAM roles to follow the least-privilege principle and enable secure execution of EC2, Lambda, and CloudFront tasks:

- `ec2_basic_role`: EC2 read-only role attached to instances in the Auto Scaling Group
- `scheduler_lambda_role`: Manages EC2/RDS lifecycle using CloudWatch EventBridge (start/stop, scale)
- `lambda_edge_role`: Required for Lambda@Edge functions invoked by CloudFront origin requests
- `infra_update_lambda_role`: Updates CloudFront origin configuration and Route 53 DNS records
- `lambda_sg_update_role`: Updates security groups with current CloudFront IP ranges


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| ec2_ami_id | AMI ID for EC2 instances | string | n/a | yes |
| ec2_key_name | EC2 SSH key name | string | n/a | yes |
| instance_type | EC2 instance type | string | `"t4g.micro"` | no |
| acm_cert_backend | ACM certificate ARN for backend CloudFront | string | n/a | yes |
| acm_cert_frontend | ACM certificate ARN for frontend CloudFront | string | n/a | yes |
| kms_key_id | KMS Key for RDS encryption | string | n/a | yes |
| route53_zone_id | Route 53 Hosted Zone ID | string | n/a | yes |
| rds_username | RDS database master username | string | n/a | yes |
| rds_password | RDS database password | string | n/a | yes |
| bucket_name | Name of S3 bucket for frontend | string | n/a | yes |
| user_data_script | User-data filename for EC2 | string | `"your-user-data-script.sh"` | no |
| launch_template_prefix | Prefix for EC2 launch template name | string | `"your-launch-template-prefix-"` | no |
| ec2_instance_name | Name tag for EC2 instances | string | `"your-ec2-instance-name"` | no |
| asg_name | Auto Scaling Group name | string | `"your-asg-name"` | no |
| desired_capacity | Desired number of EC2 instances | number | 1 | no |
| min_size | Minimum number of EC2 instances | number | 1 | no |
| max_size | Maximum number of EC2 instances | number | 2 | no |
| cpu_target_value | Target CPU utilization for ASG | number | 70.0 | no |
| vpc_id | ID of the existing VPC | string | n/a | yes |
| subnet_ids | List of subnet IDs used by EC2/RDS | list(string) | n/a | yes |
| db_subnet_group | Name of the RDS DB subnet group | string | n/a | yes |

> 💡 This project expects an existing VPC and subnet list as inputs (vpc_id, subnet_ids).
You can use the default VPC and its subnets for cost-efficiency and faster setup if you don’t require advanced networking features.

> 🐳 **User-data Script**  
> Update the `user-data/your-user-data-script.sh` script with your container image and Docker Hub details before deployment.

## Outputs:

| Name | Description | Type |
|------|-------------|------|
| frontend_cloudfront_url | URL of the frontend CloudFront distribution | string |
| backend_cloudfront_url | URL of the backend CloudFront distribution | string |
| rds_endpoint | Endpoint of the RDS instance | string |
| ec2_asg_name | Name of the EC2 Auto Scaling Group | string |
| bucket_name | S3 bucket used for frontend | string |
| update_sgs_lambda_arn | ARN of Lambda for SG CloudFront IP updates | string |
| update_infra_lambda_arn | ARN of Lambda for updating backend origin | string |
| start_lambda_arn | ARN of the Lambda function to start EC2 and RDS | string |
| stop_lambda_arn | ARN of the Lambda function to stop EC2 and RDS | string |
| lambda_edge_selector_arn | ARN of Lambda@Edge selector function | string |


## ⚠️ Deployment Notes

> ✅ Please read carefully before deploying to ensure a smooth setup.


### 1. Domain and Route 53 Setup
- You must own a domain name and have a public hosted zone created in Route 53.
- Update the following input variables accordingly:
  - `route53_zone_id` – your hosted zone ID
  - `frontend_alias` and `backend_alias` – e.g., `www.example.com`, `api.example.com`
- The backend CloudFront alias must match the domain you plan to use for routing.

### 2. Lambda@Edge Deployment Region

>  **Note:** Lambda@Edge functions must be deployed in `us-east-1`, even if your infrastructure is in another region.  
> This is handled in this project via a dedicated provider block with alias `us_east_1`.

Make sure ACM certificates for both frontend and backend CloudFront distributions are also created in `us-east-1`.

### 3. Manual Upload for Frontend Static Files (S3)

This project provisions the S3 bucket and sets permissions, but it does not upload your website files.

You need to upload them manually or use a script after `terraform apply` completes.

To upload files to S3 using the AWS CLI:

```bash
aws s3 cp ./dist/ s3://your-s3-bucket-name/ --recursive

```
## License

This project is licensed under the [MIT License](./LICENSE).

## Authors

Created and maintained by [Firas Ben Nacib](https://github.com/firassBenNacib) - bennacibfiras@gmail.com
