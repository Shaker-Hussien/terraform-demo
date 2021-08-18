provider "aws" {
    region = "eu-west-3"
}


variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}

resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet" {
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name = "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

// create new route table and attach it to subnet
/*
resource "aws_route_table" "myapp-rtb" {
    vpc_id = aws_vpc.myapp-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-rtb"
    }
}

resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet.id
    route_table_id = aws_route_table.myapp-route-table.id
}
*/

// use main route table which is attached to all subnets in the vpc by default
// just add the last resort route "0.0.0.0/0"
resource "aws_default_route_table" "myapp-main-rtb" {
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-main-rtb"
    }
}

// create new security group
/*
resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # egress {
    #     from_port = 0
    #     to_port = 0
    #     protocol = "-1"
    #     cidr_blocks = ["0.0.0.0/0"]
    # }

    tags = {
        Name = "${var.env_prefix}-sg"
    }
}
*/

// using default security group
resource "aws_default_security_group" "myapp-default-sg" {
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # egress {
    #     from_port = 0
    #     to_port = 0
    #     protocol = "-1"
    #     cidr_blocks = ["0.0.0.0/0"]
    # }

    tags = {
        Name = "${var.env_prefix}-default-sg"
    }
}

data "aws_ami" "latest_amazon_linux_image" {
    most_recent = true
    owners = ["amazon"]
    filter {
        name = "name"
        values = ["amzn2-ami-hvm-*-x86_64-gp2"]
    }

}
/*
output "aws_ami" {
    value = data.aws_ami.latest_amazon_linux_image.id
}
*/

resource "aws_key_pair" "ssh-key" {
    key_name = "myapp-server-key"
    public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
    //required attributes
    ami = data.aws_ami.latest_amazon_linux_image.id
    instance_type =  var.instance_type

    //optional attributes , take default if not defined
    subnet_id = aws_subnet.myapp-subnet.id
    vpc_security_group_ids = [aws_default_security_group.myapp-default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name
    
    # user_data = file("entry-script.sh")
    user_data = <<EOF
                    #!/bin/bash
                    sudo yum update -y && sudo yum install -y docker
                    sudo systemctl start docker
                    sudo usermod -aG docker ec2-user
                    docker run -p 8080:80 nginx
                EOF
    tags = {
        Name = "${var.env_prefix}-server"
    }
}


output "myapp_server_public_ip" {
    value = aws_instance.myapp-server.public_ip
}
