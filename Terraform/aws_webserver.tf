terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}

#Configurando o acesso ao provedor
provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

#Definindo a VPC/rede
resource "aws_vpc" "vpc_brq" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "VPC_brq"
  }
}

#Definindo a porta de entrada
resource "aws_internet_gateway" "gw_brq" {
  vpc_id = aws_vpc.vpc_brq.id

  tags = {
    Name = "internetgateway_brq"
  }
}

#Defindo a tabela de rotas
resource "aws_route_table" "rotas_brq" {
  vpc_id = aws_vpc.vpc_brq.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_brq.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw_brq.id
  }

  tags = {
    Name = "rotas_brq"
  }
}

#Definindo a sub-rede
resource "aws_subnet" "subrede_brq" {
  vpc_id            = aws_vpc.vpc_brq.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "subrede_brq"
  }
}

#Definindo as associações da tabela de rotas
resource "aws_route_table_association" "associacao" {
  subnet_id      = aws_subnet.subrede_brq.id
  route_table_id = aws_route_table.rotas_brq.id
}


#Definindo o grupo de segurança 
resource "aws_security_group" "firewall" {
  name        = "abrir_portas"
  description = "Abrir portas 22(SSH), 443(HTTPS) E 80 (HTTP)"
  vpc_id      = aws_vpc.vpc_brq.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "portas_brq"
  }
}

#Definindo uma interface de rede
resource "aws_network_interface" "interface_rede" {
  subnet_id       = aws_subnet.subrede_brq.id
  private_ips     = ["10.0.1.51"]
  security_groups = [aws_security_group.firewall.id]
  tags = {
    Name = "interface_brq"
  }
}

#Defindo um IP público 
resource "aws_eip" "ip_publico" {
  vpc                       = true
  network_interface         = aws_network_interface.interface_rede.id
  associate_with_private_ip = "10.0.1.51"
  depends_on                = [aws_internet_gateway.gw_brq]
  tags = {
    Name = "ippublico_brq"
  }
}

#Definindo uma instância associada a interface de rede
resource "aws_instance" "app_web" {
  ami               = "ami-04505e74c0741db8d"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface_rede.id
  }
  user_data = <<-EOF
               #! /bin/bash
               sudo apt-get update -y
               sudo apt-get install -y apache2
               sudo systemctl start apache2
               sudo systemctl enable apache2
               sudo bash -c 'echo "<h1>WEB SERVER TEST - MATHEUS OLIVEIRA</h1>"  > /var/www/html/index.html'
             EOF
  tags = {
    Name = "webserver_brq"
  }
}