resource "aws_db_instance" "this" {
  identifier           = var.identifier
  engine               = "mysql"
  engine_version       = "8.0.40"
  instance_class       = "db.t4g.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  username             = var.username
  password             = var.password
  db_name              = var.db_name
  parameter_group_name = "default.mysql8.0"
  option_group_name    = "default:mysql-8-0"
  publicly_accessible  = false
  multi_az             = false
  storage_encrypted    = true
  kms_key_id           = var.kms_key_id
  skip_final_snapshot  = true
  db_subnet_group_name = var.db_subnet_group

  vpc_security_group_ids = [
    var.rds_sg_id
  ]

  tags = {
    Name = var.identifier
  }
}
