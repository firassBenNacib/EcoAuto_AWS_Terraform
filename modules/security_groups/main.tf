resource "aws_security_group" "cloudfront_sg" {
  count       = 3
  name        = "cloudfront-sg-${count.index + 1}"
  description = "Allow CloudFront IPs - Chunk ${count.index + 1}"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_rds_sg" {
  name        = "ec2-to-db-sg"
  description = "Allow EC2 to connect to DB"
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "rds_ec2_sg" {
  name        = "db-from-ec2-sg"
  description = "Allow DB access from EC2 SG"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ec2_to_rds_egress" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2_rds_sg.id
  source_security_group_id = aws_security_group.rds_ec2_sg.id
  description              = "Allow EC2 to send to DB on MySQL"
}

resource "aws_security_group_rule" "rds_from_ec2_ingress" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_ec2_sg.id
  source_security_group_id = aws_security_group.ec2_rds_sg.id
  description              = "Allow DB to accept from EC2 on MySQL"
}
