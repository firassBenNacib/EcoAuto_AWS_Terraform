#tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs VPC flow logs are optional and controlled by enable_vpc_flow_logs.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_default_security_group" "lockdown" {
  count = var.lockdown_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-default-sg-lockdown"
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name               = "${var.vpc_name}-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.vpc_name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  iam_role_arn             = aws_iam_role.vpc_flow_logs[0].arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type             = "ALL"
  max_aggregation_interval = 60
  vpc_id                   = aws_vpc.this.id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_subnet" "public_app" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_app_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true #tfsec:ignore:aws-ec2-no-public-ip-subnet Backend instances intentionally run in public app subnets for the no-ALB/no-NAT cost profile, with ingress restricted by CloudFront managed prefix list SG rules.

  tags = {
    Name = "${var.vpc_name}-public-app-${count.index + 1}"
    Tier = "public-app"
  }
}

resource "aws_subnet" "private_db" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_db_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.vpc_name}-private-db-${count.index + 1}"
    Tier = "private-db"
  }
}

resource "aws_route_table" "public_app" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.vpc_name}-public-app-rt"
  }
}

resource "aws_route_table_association" "public_app" {
  count = length(aws_subnet.public_app)

  subnet_id      = aws_subnet.public_app[count.index].id
  route_table_id = aws_route_table.public_app.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db" {
  count = length(aws_subnet.private_db)

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}
