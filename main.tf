resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}

module "myapp-subnet" {
    source = "./modules/subnet"
    vpc_id = aws_vpc.myapp-vpc.id
    subnet_cidr_block = var.subnet_cidr_block
    avail_zone = var.avail_zone
    env_prefix = var.env_prefix
    vpc_default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
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

resource "aws_key_pair" "ssh-key" {
    key_name = "myapp-server-key"
    public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
    //required attributes
    ami = data.aws_ami.latest_amazon_linux_image.id
    instance_type =  var.instance_type

    //optional attributes , take default if not defined
    subnet_id = module.myapp-subnet.subnet.id
    vpc_security_group_ids = [aws_default_security_group.myapp-default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.ssh-key.key_name
    
    user_data = file("entry-script.sh")

    tags = {
        Name = "${var.env_prefix}-server"
    }
}