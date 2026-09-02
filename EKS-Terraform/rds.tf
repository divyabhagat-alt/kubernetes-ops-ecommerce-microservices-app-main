############################
# RDS SECURITY GROUP
############################

resource "aws_security_group" "sd_rds_sg" {

  name        = "sd-rds-sg"
  description = "Allow MySQL access from EKS nodes"
  vpc_id      = aws_vpc.sd_vpc.id

  ingress {

    description = "MySQL from VPC"

    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sd-rds-sg"
  }
}

############################
# DB SUBNET GROUP
############################

resource "aws_db_subnet_group" "sd_sub_grp" {

  name = "sd-db-subnet-group"

  subnet_ids = [
    aws_subnet.sd_private1.id,
    aws_subnet.sd_private2.id
  ]

  tags = {
    Name = "sd-db-subnet-group"
  }
}

############################
# RDS MYSQL INSTANCE
############################

resource "aws_db_instance" "sd_rds" {

  identifier = "sd-microservices-rds"

  allocated_storage = 20
  storage_type      = "gp2"

  engine         = "mysql"
  engine_version = "8.4.8"

  instance_class = "db.t3.micro"

  multi_az = true

  db_name  = "mydb"
  username = "admin"
  password = "Cloud123"

  port = 3306

  publicly_accessible = false

  db_subnet_group_name = aws_db_subnet_group.sd_sub_grp.name

  vpc_security_group_ids = [
    aws_security_group.sd_rds_sg.id
  ]

  backup_retention_period = 7

  skip_final_snapshot = true

  deletion_protection = false

  depends_on = [
    aws_db_subnet_group.sd_sub_grp
  ]

  tags = {
    Name = "sd-book-rds"
  }
}