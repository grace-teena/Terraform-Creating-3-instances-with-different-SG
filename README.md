Here, i'm creating 3 Ec2 instance with 3 different security groups.

Prerequisite :
* Create an IAM user on AWS console with privilages to create required resources. 
* Create a dedicated directory where you can create terraform configuration files.
* Install Terraform. 

### Pre-Setup:

#### 1. Setting required variables for setting up VPC

````````
variable "region" {
  default = "ap-south-1"
}

variable "project" {
  default = "Ajio"
}

variable "vpc_cidr" { 
  default = "172.17.0.0/16"
}

````````

region   ---> AWS region where you are going to work
Project  ---> To set project name in terraform
vpc_cidr ---> CIDR block of VPC being created


#### 2. Setting required variables for setting up EC2

```````
variable "ami" {
  default = "ami-002068ed284fb165b"  
}

variable "type" {
  default = "t2.micro"
} 

```````

ami  ---> AMI where you launch your instance
type ---> Instance type

#### 3. Create a userdata script for ssh login

``````
#!/bin/bash
echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment
echo "password123" | passwd root --stdin
sed  -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart

``````

#### 4. Fetch Available Availability Zones in the working AWS region**
`````
data "aws_availability_zones" "az" {
    
  state = "available"

}
`````

This will fetch all available Availability Zones in working AWS region and store the details in variable az

#### 5. Generate and upload SSH key-pair to AWS

You can create SSH key using following commend:

```````
#ssh-keygen

```````


Upload key to AWS

````````
resource "aws_key_pair"  "key" {
 
  key_name   = "terraform"
  public_key = file("terraform.pub")
  tags     = {
    Name    = "${var.project}-key"
    project = var.project
  }
}

````````

### VPC Creation:

`````
resource "aws_vpc" "vpc" {
    
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true  
  tags = {
    Name = "${var.project}-vpc"
    project = var.project
  }
  lifecycle {
    create_before_destroy = true
  }
}

`````
instance_tenancy = default : (shared)- Multiple AWS accounts may share the same physical hardware.
enable_dns_hostnames = true : DNS hostnames in the VPC.
enable_dns_support = true : DNS support in the VPC.
lifecycle rule : Lifecycle arguments help control the flow of your Terraform operations by creating custom rules for resource creation and destruction.
Here the destruction happens only after the creation.

### Attaching Internet gateWay

Creating an Internet Gateway and attach it to the created VPC

``````
resource "aws_internet_gateway" "igw" {
    
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project}-igw"
    project = var.project
  }
    
}

``````

### Creating Public and Private subnets

````

# Creating Subnets Public1
# ======================= #

resource "aws_subnet" "public1" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr,3,0)                        
  map_public_ip_on_launch  = true
  availability_zone        = data.aws_availability_zones.az.names[0]
  tags = {
    Name = "${var.project}-public1"
    project = var.project
  }
}

# Creating Subnets Public2
# ======================= #

resource "aws_subnet" "public2" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr,3,1)
  map_public_ip_on_launch  = true
  availability_zone        = data.aws_availability_zones.az.names[1]
  tags = {
    Name = "${var.project}-public2"
    project = var.project
  }
}

# Creating Subnets Public3
# ======================== #

resource "aws_subnet" "public3" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr,3,2)
  map_public_ip_on_launch  = true
  availability_zone        = data.aws_availability_zones.az.names[2]
  tags = {
    Name = "${var.project}-public3"
    project = var.project
  }
}
``````````
> This will create subnets in the created VPC with below properties:

- A Public IP will be assigned by default to an EC2 launched in those Subnet
- The availability zone of these subnet will the created in an order 0,1,2 ie; First available Availability zone(0th position).
- CIDR block of this subnet will be created from the first block of the network(0th position) of VPC after subnetting it with 3 additional bits to the subnet of VPC CIDR
[cidrsubnet()](https://www.terraform.io/docs/language/functions/cidrsubnet.html) in the codes is a function in Terraform for subnetting the CIDR block of VPC and assign the networks among the subnets in that VPC.

### Creating Subnets Private1

```````
resource "aws_subnet" "private1" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr,3,3)
  map_public_ip_on_launch  = false
  availability_zone        = data.aws_availability_zones.az.names[0]
  tags = {
    Name = "${var.project}-private1"
    project = var.project
  }
}


# Creating Subnets Private2
# ======================== #

resource "aws_subnet" "private2" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr,3,4)
  map_public_ip_on_launch  = false
  availability_zone        = data.aws_availability_zones.az.names[1]
  tags = {
    Name = "${var.project}-private2"
    project = var.project
  }
}


# Creating Subnets Private3
# ======================== #

resource "aws_subnet" "private3" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr,3,5)
  map_public_ip_on_launch  = false
  availability_zone        = data.aws_availability_zones.az.names[2]
  tags = {
    Name = "${var.project}-private3"
    project = var.project
  }
}
```````````

### Elatic Ip Allocation

Purchase an Elastic IP from AWS to attach it to the NAT Gateway being created

````````````
resource "aws_eip" "eip" {
  vpc      = true
  tags     = {
    Name    = "${var.project}-nat-eip"
    project = var.project
  }
}

``````````````

### Creating Nat GateWay

``````````
resource "aws_nat_gateway" "nat" {
    
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public2.id

  tags     = {
    Name    = "${var.project}-nat"
    project = var.project
  }

}
``````````````````

Create a NAT Gateway in any of the public subnets in the VPC(here, it is created in second public subnet in the VPC) to enable Public communication to the instances launched in the private subnets


### RouteTable Creation public

Create a public Route table with Route to the outer world(0.0.0.0/0) through the Internet Gateway

````````````````
resource "aws_route_table" "public" {
    
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags     = {
    Name    = "${var.project}-route-public"
    project = var.project
  }
}

``````````````````

### RouteTable Creation Private

Create a private Route table with Route to the outer world(0.0.0.0/0) through the Internet Gateway
````````````
resource "aws_route_table" "private" {
    
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags     = {
    Name    = "${var.project}-route-private"
    project = var.project
  }
}

``````````````````````
## Create subnet associations for Route Tables

### Public Route Table Association
````````
# =====================================================
# RouteTable Association subnet Public1  rtb public
# =====================================================

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

# =====================================================
# RouteTable Association subnet Public2  rtb public
# =====================================================

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# =====================================================
# RouteTable Association subnet Public3  rtb public
# =====================================================

resource "aws_route_table_association" "public3" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.public.id
}
````````````

### Private Route Table Association`
`````````
# =====================================================
# RouteTable Association subnet Private1  rtb public
# =====================================================

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

# =====================================================
# RouteTable Association subnet private2  rtb public
# =====================================================

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

# =====================================================
# RouteTable Association subnet private3  rtb public
# =====================================================

resource "aws_route_table_association" "private3" {
  subnet_id      = aws_subnet.private3.id
  route_table_id = aws_route_table.private.id
}
````````````

Now I'm going to create security groups and instances:

### Creating Security Group for each instance.
`````````````

# =====================================================
# Creating Security Group - bastion
# =====================================================

resource "aws_security_group" "bastion" {
    
  name        = "${var.project}-bastion"
  description = "Allows 22 traffic"
  vpc_id      = aws_vpc.vpc.id
  ingress     = [
      
  {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    prefix_list_ids  = []
    security_groups  = []
    self             = false 
  }

  ]
      
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags     = {
    Name    = "${var.project}-bastion"
    project = var.project
  }
}

# =====================================================
# Creating Security Group - frontend
# =====================================================

resource "aws_security_group" "frontend" {   
  name        = "${var.project}-frontend"
  description = "Allows 80 from all,22 from bastion"
  vpc_id      = aws_vpc.vpc.id
  ingress     = [ 
      
  {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = [ aws_security_group.bastion.id ]
    prefix_list_ids  = []
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    self             = false 
  },
  {
    description      = ""
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    prefix_list_ids  = []
    security_groups  = []
    self             = false 
  },
  {
    description      = ""
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    prefix_list_ids  = []
    security_groups  = []
    self             = false 
  }

  ]
      
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags     = {
    Name    = "${var.project}-frontend"
    project = var.project
  }
}



# =====================================================
# Creating Security Group - backend
# =====================================================

resource "aws_security_group" "backend" {
    
  name        = "${var.project}-backend"
  description = "Allows 3306 from frontend,22 from bastion"
  vpc_id      = aws_vpc.vpc.id
  ingress     = [ 
      
  {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = [ aws_security_group.bastion.id ]
    prefix_list_ids  = []
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    self             = false 
  },
  {
    description      = ""
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [ aws_security_group.frontend.id ]
    prefix_list_ids  = []
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    self             = false 
  }
  ]
      
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags     = {
    Name    = "${var.project}-backend"
    project = var.project
  }
}
````````````````

## Creating Instances :
```````
# =====================================================
# Creating Ec2 Instance For Frontend
# =====================================================

resource "aws_instance"  "frontend" {
    
  ami                          =  var.ami
  instance_type                =  var.type
  subnet_id                    =  aws_subnet.public1.id
  key_name                     =  aws_key_pair.key.id
  vpc_security_group_ids       =  [  aws_security_group.frontend.id ]
  user_data                    =  file("setup.sh")
  tags     = {
    Name    = "${var.project}-frontend"
    project = var.project
  }
    
}


# =====================================================
# Creating Ec2 Instance For Backend
# =====================================================

resource "aws_instance"  "backend" {
    
  ami                          =  var.ami
  instance_type                =  var.type
  subnet_id                    =  aws_subnet.private1.id
  key_name                     =  aws_key_pair.key.id
  vpc_security_group_ids       =  [  aws_security_group.backend.id  ]
  user_data                    =  file("setup.sh")
  tags     = {
    Name    = "${var.project}-backend"
    project = var.project
  }
    
}


# =====================================================
# Creating Ec2 Instance For Bastion
# =====================================================

resource "aws_instance"  "bastion" {
    
  ami                          =  var.ami
  instance_type                =  var.type
  subnet_id                    =  aws_subnet.public2.id
  key_name                     =  aws_key_pair.key.id
  vpc_security_group_ids       =  [  aws_security_group.bastion.id  ]
  user_data                    =  file("setup.sh")
  tags     = {
    Name    = "${var.project}-bastion"
    project = var.project
  }
    
}
`````````

Here we have created 3 instances. One in public subnet-1 ,One in private subnet-1 and other in oublic subnet-2.

## Setting Output :
````````
output "frontend-public-ip" {
    
  value = aws_instance.frontend.public_ip
    
}


output "frontend-private-ip" {
    
  value = aws_instance.frontend.private_ip
    
}


output "bastion-public-ip" {
    
  value = aws_instance.bastion.public_ip
    
}



output "backend-public-ip" {
    
  value = aws_instance.backend.private_ip
    
}
-----
This will list the Public IP address of each instance.
===
 backend-public-ip = "172.17.112.27" 
 bastion-public-ip = "3.110.47.23" 
 frontend-private-ip = "172.17.20.209" 
 frontend-public-ip = "3.110.157.18" 
===

Lets validate the terraform files using
```
terraform validate
````
Lets plan the architecture and verify once again.
````
terraform plan
````
Lets apply the above architecture.
````
terraform apply
````
We can view the output using
````
terraform output
````
List the states created on terraform
---
terraform state list
----

You can view each state using the command **terraform state show** <state>
````
# terraform state show aws_instance.backend
# aws_instance.backend:
resource "aws_instance" "backend" {
    ami                                  = "ami-052cef05d01020f1d"
    arn                                  = "arn:aws:ec2:ap-south-1:591825527445:instance/i-0889744035aa3daed"
    associate_public_ip_address          = false
    availability_zone                    = "ap-south-1a"
    cpu_core_count                       = 1
    cpu_threads_per_core                 = 1
    disable_api_termination              = false
    ebs_optimized                        = false
    get_password_data                    = false
    hibernation                          = false
    id                                   = "i-0889744035aa3daed"
    instance_initiated_shutdown_behavior = "stop"
    instance_state                       = "running"
    instance_type                        = "t2.micro"
    ipv6_address_count                   = 0
    ipv6_addresses                       = []
    key_name                             = "terrraform"
    monitoring                           = false
    primary_network_interface_id         = "eni-074c67629a27917cb"
    private_dns                          = "ip-172-17-112-27.ap-south-1.compute.internal"
    private_ip                           = "172.17.112.27"
    secondary_private_ips                = []
    security_groups                      = []
    source_dest_check                    = true
    subnet_id                            = "subnet-04b4eacce758763cb"
    tags                                 = {
        "Name"    = "Ajio-backend"
        "project" = "Ajio"
    }
    tags_all                             = {
        "Name"    = "Ajio-backend"
        "project" = "Ajio"
    }
    tenancy                              = "default"
    user_data                            = "f221e715c9d4bcdcdbf676929e8bd42365e17310"
    vpc_security_group_ids               = [
        "sg-0d39df7c8e0f76f81",
    ]

    capacity_reservation_specification {
        capacity_reservation_preference = "open"
    }

    credit_specification {
        cpu_credits = "standard"
    }

    enclave_options {
        enabled = false
    }

    metadata_options {
        http_endpoint               = "enabled"
        http_put_response_hop_limit = 1
        http_tokens                 = "optional"
    }

    root_block_device {
        delete_on_termination = true
        device_name           = "/dev/xvda"
        encrypted             = false
        iops                  = 100
        tags                  = {}
        throughput            = 0
        volume_id             = "vol-00f50095d38180dab"
        volume_size           = 8
        volume_type           = "gp2"
    }
}
```````

