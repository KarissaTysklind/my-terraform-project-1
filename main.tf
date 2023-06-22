provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAUGR5LL4XP5CIZR4G"
  secret_key = "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"
}

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  # default =
  # type = string  
}

# 1. Create VPC

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prod"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "main"
  }
}

# 3. Create Route Table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

# 4. Create Subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# 5. Associate Route Table

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.prod-vpc.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create Security Group

resource "aws_security_group" "allow-web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create Network Interface

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]
}

# 8. Create Elastic IP

resource "aws_eip" "one" {
  instance = aws_instance.web-server-instance.id
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

output "server-public-ip" {
  value = aws_eip.one.public_ip
  
}

# 9. Create Instance

resource "aws_instance" "web-server-instance" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
    }

  user_data = <<-EOF
        #! /bin/bash
        sudo apt-get update
        sudo apt-get install -y apache2
        sudo systemctl start apache2
        sudo systemctl enable apache2
        echo "The page was created by the user data" | sudo tee /var/www/html/index.html
        EOF

  tags = {
    Name = "Ubuntu"
  }

}

output "server-private-ip" {
  value = aws_instance.web-server-instance.private_ip
  
}

output "server_id" {
  value = aws_instance.web-server-instance.id
  
}