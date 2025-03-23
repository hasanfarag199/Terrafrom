# % export AWS_ACCESS_KEY_ID=""
# % export AWS_SECRET_ACCESS_KEY=""

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.91.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}
resource "aws_subnet" "bastion_subnet"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "bastion-subnet"
  }
}
resource "aws_subnet" "app_subnet"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-north-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "app-subnet"
  }
}
resource "aws_subnet" "db_subnet"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-north-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "db-subnet"
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "app" {
  subnet_id = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "db" {
  subnet_id = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "bastion" {
  subnet_id = aws_subnet.bastion_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name = "app-sg"
  description = "Security group for application servers"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "app-sg"
  } 
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.app.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
  cidr_ipv4         = aws_subnet.app_subnet.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.app.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
  cidr_ipv4         = aws_subnet.app_subnet.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "allow_app_ssh" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         =  aws_subnet.app_subnet.cidr_block
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.app.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
  
  
resource "aws_security_group" "db" {
  name = "db-sg"
  description = "Security group for database servers"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "db-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_mysql" {
  security_group_id = aws_security_group.db.id
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
  cidr_ipv4         = aws_subnet.db_subnet.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "allow_db_ssh" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = aws_subnet.db_subnet.cidr_block
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
}

resource "aws_security_group" "bastion" {
  name = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "bastion-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = aws_subnet.bastion_subnet.cidr_block
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_instance" "app" {
  ami = "ami-0c1ac8a41498c1a9c" # Ubuntu 24.04 LTS
  instance_type = "t3.micro"
  subnet_id = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = {
    Name = "app-server"
  }
}

resource "aws_instance" "db" {
  ami = "ami-0c1ac8a41498c1a9c" # Ubuntu 24.04 LTS
  instance_type = "t3.micro"
  subnet_id = aws_subnet.db_subnet.id
  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Name = "db-server"
  }
}

# Create bastion host
resource "aws_instance" "bastion" {
  ami           = "ami-0c1ac8a41498c1a9c"  # Ubuntu 24.04 LTS
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.bastion_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "bastion-host"
  }
}
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets           = [aws_subnet.app_subnet.id, aws_subnet.db_subnet.id]
  tags = {
    Name = "app-lb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    timeout             = 5
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 2
  }

  tags = {
    Name = "app-tg"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = 80
}
