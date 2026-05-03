resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { 
    Name   = "${var.project_name}-vpc-${var.environment}" 
    Owner  = "MarlonChavez"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { 
    Name  = "subnet-priv-a-${var.environment}"
    Owner = "MarlonChavez"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { 
    Name  = "subnet-priv-b-${var.environment}"
    Owner = "MarlonChavez"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.main.default_route_table_id]

  tags = { 
    Name  = "vpce-s3-${var.environment}"
    Owner = "MarlonChavez"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sqs_sg.id]

  tags = { 
    Name  = "vpce-sqs-${var.environment}"
    Owner = "MarlonChavez"
  }
}

resource "aws_security_group" "vpce_sqs_sg" {
  name        = "vpce-sqs-${var.environment}"
  description = "Acceso HTTPS interno para SQS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { 
    Name  = "vpce-sqs-sg-${var.environment}"
    Owner = "MarlonChavez"
  }
}