# vpc Creation
# =========== #

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

# Attaching Internet Gateway
# ========================== #

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project}-igw"
    project = var.project
  }

}

#===================#
#Creating Subnets
#===================#

# Creating Subnets Public1
# ====================== #

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
# ======================= #

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

# Creating Subnets Private1
# ======================= #

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
# ======================= #

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
# ======================= #

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

# Elatic Ip Allocation
# ================== #
resource "aws_eip" "eip" {
  vpc      = true
  tags     = {
    Name    = "${var.project}-nat-eip"
    project = var.project
  }
}

# Creating Nat GateWay
# ================== #


resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public2.id

  tags     = {
    Name    = "${var.project}-nat"
    project = var.project
  }

}

# RouteTable Creation public
# ========================= #
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

# RouteTable Creation Private
# ======================== #
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

# RouteTable Association subnet Public-1  rtb public
# =====================================================

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

# RouteTable Association subnet Public-2  rtb public
# =====================================================

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# RouteTable Association subnet Public-3  rtb public
# =====================================================

resource "aws_route_table_association" "public3" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.public.id
}



# RouteTable Association subnet Private-1  rtb public
# =====================================================

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

# RouteTable Association subnet private-2  rtb public
# =====================================================

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

# RouteTable Association subnet private-3  rtb public
# =====================================================

resource "aws_route_table_association" "private3" {
  subnet_id      = aws_subnet.private3.id
  route_table_id = aws_route_table.private.id
}


