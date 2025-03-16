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

# % export AWS_ACCESS_KEY_ID="anaccesskey"
# % export AWS_SECRET_ACCESS_KEY="asecretkey"


# # Create subnets
# resource "aws_subnet" "bastion_subnet" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.0.0/24"
#   availability_zone       = "eu-west-2a"
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "bastion-subnet"
#   }
# }
resource "aws_subnet" "public_subnet"{
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
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

# # Create Internet Gateway
# resource "aws_internet_gateway" "main" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "main-igw"
#   }
# }

# # Create route tables
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.main.id
#   }

#   tags = {
#     Name = "public-rt"
#   }
# }

# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "private-rt"
#   }
# }

# # Associate route tables with subnets
# resource "aws_route_table_association" "bastion" {
#   subnet_id      = aws_subnet.bastion_subnet.id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route_table_association" "app" {
#   subnet_id      = aws_subnet.app_subnet.id
#   route_table_id = aws_route_table.private.id
# }

# resource "aws_route_table_association" "db" {
#   subnet_id      = aws_subnet.db_subnet.id
#   route_table_id = aws_route_table.private.id
# }

# # Create security groups
# resource "aws_security_group" "bastion" {
#   name        = "bastion-sg"
#   description = "Security group for bastion host"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "bastion-sg"
#   }
# }

# resource "aws_security_group" "app" {
#   name        = "app-sg"
#   description = "Security group for application servers"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port       = 80
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.lb.id]
#   }

#   ingress {
#     from_port       = 443
#     to_port         = 443
#     protocol        = "tcp"
#     security_groups = [aws_security_group.lb.id]
#   }

#   ingress {
#     from_port       = 22
#     to_port         = 22
#     protocol        = "tcp"
#     security_groups = [aws_security_group.bastion.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "app-sg"
#   }
# }

# resource "aws_security_group" "db" {
#   name        = "db-sg"
#   description = "Security group for database servers"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port       = 3306
#     to_port         = 3306
#     protocol        = "tcp"
#     security_groups = [aws_security_group.app.id]
#   }

#   ingress {
#     from_port       = 22
#     to_port         = 22
#     protocol        = "tcp"
#     security_groups = [aws_security_group.bastion.id]
#   }

#   tags = {
#     Name = "db-sg"
#   }
# }
resource "aws_security_group" "app" {
  name = "app-sg"
  description = "Security group for application servers"
  vpc_id = aws_vpc.main.id
  
}
resource "aws_security_group" "db" {
  name = "db-sg"
  description = "Security group for database servers"
  vpc_id = aws_vpc.main.id
  
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


# # Create bastion host
# resource "aws_instance" "bastion" {
#   ami           = "ami-0eb260c4d5475b901"  # Ubuntu 20.04 LTS
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.bastion_subnet.id

#   vpc_security_group_ids = [aws_security_group.bastion.id]

#   root_block_device {
#     volume_size = 20
#     volume_type = "gp3"
#   }

#   tags = {
#     Name = "bastion-host"
#   }
# }

# # Create Application Load Balancer
# resource "aws_lb" "app_lb" {
#   name               = "app-lb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.lb.id]
#   subnets           = [aws_subnet.app_subnet.id]

#   tags = {
#     Name = "app-lb"
#   }
# }

# resource "aws_security_group" "lb" {
#   name        = "lb-sg"
#   description = "Security group for load balancer"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "lb-sg"
#   }
# }

# resource "aws_lb_target_group" "app_tg" {
#   name     = "app-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id

#   health_check {
#     enabled             = true
#     healthy_threshold   = 2
#     interval            = 30
#     timeout             = 5
#     path                = "/"
#     port                = "traffic-port"
#     protocol            = "HTTP"
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Name = "app-tg"
#   }
# }

# resource "aws_lb_listener" "app_listener" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }

# resource "aws_lb_target_group_attachment" "app_attachment" {
#   target_group_arn = aws_lb_target_group.app_tg.arn
#   target_id        = aws_instance.app.id
#   port             = 80
# } 