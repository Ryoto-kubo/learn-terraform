terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.3.0"
    }
  }
}

locals {
  app_name = "001"
  public_key_file  = "${local.app_name}-ec2-key-pair.pub"
  private_key_file = "${local.app_name}-ec2-key-pair.pem"
}

provider "aws" {
  region = "ap-northeast-1"
}

####################################################
# VPC
####################################################
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16" // 65,536 個の IP アドレスを提供

  tags = {
    Name = "${local.app_name}-vpc"
  }
}


####################################################
# Subnet
####################################################
resource "aws_subnet" "public_subnet_1a" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "${local.app_name}-public-subnet-1a"
  }
}

resource "aws_subnet" "public_subnet_1c" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${local.app_name}-public-subnet-1c"
  }
}

resource "aws_subnet" "public_subnet_1d" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-northeast-1d"

  tags = {
    Name = "${local.app_name}-public-subnet-1d"
  }
}


####################################################
# Internet Gateway
####################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.app_name}-igw"
  }
}


####################################################
# Route Table
####################################################
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0" // 内部からの外部への通信は全てインターネットとなる
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.app_name}-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_1a_association" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_1c_association" {
  subnet_id      = aws_subnet.public_subnet_1c.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_1d_association" {
  subnet_id      = aws_subnet.public_subnet_1d.id
  route_table_id = aws_route_table.public_route_table.id
}


####################################################
# Security Group
####################################################
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSHを全世界に開放（本番環境では制限する）
  }

  tags = {
    Name = "${local.app_name}-sg"
  }
}


####################################################
# Key Pair
####################################################
resource "tls_private_key" "key_gen" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key_openssh" {
  filename = "${path.module}/${local.public_key_file}"
  content  = tls_private_key.key_gen.public_key_openssh
  file_permission = "0600"
}

resource "local_file" "private_key_pem" {
  filename = "${path.module}/${local.private_key_file}"
  content  = tls_private_key.key_gen.private_key_pem
  file_permission = "0600"
}

resource "aws_key_pair" "key_pair" {
  key_name   = "${local.app_name}-ec2-key-pair"
  public_key = tls_private_key.key_gen.public_key_openssh
}


####################################################
# EC2
####################################################
data "aws_ami" "linux2023" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"] # Amazon Linux 2023 のAMI
  }

  filter {
    name   = "architecture"
    values = ["x86_64"] # 64ビットアーキテクチャを指定
  }
}

resource "aws_instance" "ec2" {
  ami = data.aws_ami.linux2023.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name = aws_key_pair.key_pair.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${local.app_name}-ec2"
  }
}


####################################################
# Elastic IP
####################################################
resource "aws_eip" "eip" {
  instance = aws_instance.ec2.id
  domain = "vpc"
  tags = {
    Name = "${local.app_name}-eip"
  }
}


####################################################
# Acm
####################################################
resource "aws_acm_certificate" "certificate" {
  domain_name = "*.${var.domain}"
  validation_method = "DNS"

  tags = {
    Name = "${local.app_name}-certificate"
  }
}


####################################################
# Route53
####################################################
resource "aws_route53_zone" "zone" {
  name = var.domain
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 300
}