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
  public_key_file  = "~/.ssh/id_rsa-ec2-key-${local.app_name}.id_rsa.pub"
  private_key_file = "~/.ssh/id_rsa-ec2-key-${local.app_name}.id_rsa"
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
  algorithm = "SA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_pem" {
  filename = local.private_key_file
  content  = tls_private_key.key_gen.private_key_pem
  provisioner "local-exec" {
    command = "chmod 600 ${local.private_key_file}"
  }
}

resource "local_file" "public_key_openssh" {
  filename = local.public_key_file
  content  = tls_private_key.key_gen.public_key_openssh
  provisioner "local-exec" {
    command = "chmod 600 ${local.public_key_file}"
  }
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

  tags = {
    Name = "${local.app_name}-ec2"
  }
}