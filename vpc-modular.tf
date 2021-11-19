terraform {
  
}

# Configure the AWS Provider
provider "aws" {
  region = "${var.region}"
  profile = "terra-user"
}

data "aws_availability_zones" "azes" {
    state = "available"
}

#create vpc
resource "aws_vpc" "vpc" {
  cidr_block              = "${var.vpc-cidr}"
  instance_tenancy        = "default"
  tags      = {
    Name = var.name
  }
}

# Create Internet Gateway and Attach it to VPC
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id    = aws_vpc.vpc.id
}

# Create Public Subnets
resource "aws_subnet" "public-subnets" {  
  count = length( var.public-subnets-cidr )
  vpc_id                  = aws_vpc.vpc.id
  #element(list,index)
  cidr_block              = element(var.public-subnets-cidr, count.index)
  availability_zone       = data.aws_availability_zones.azes.names[0]

  tags      = {
    Name = "public-subnet-${count.index +1}"
  }
}


# Create Route Table and Add Public Route
resource "aws_route_table" "route-public" {
  vpc_id       = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags       = {
    Name = var.name
  }
}


# Associate Public Subnets to "Public Route Table"
resource "aws_route_table_association" "public-subnets-route-table-association" {
  count = length( var.public-subnets-cidr )
  subnet_id = element( aws_subnet.public-subnets.*.id, count.index ) 
  route_table_id      = aws_route_table.route-public.id
}


# Create Private Subnets
resource "aws_subnet" "private-subnets" {  
  count = length( var.private-subnets-cidr )
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(var.private-subnets-cidr, count.index)
  availability_zone       = data.aws_availability_zones.azes.names[0]

  tags      = {
    Name = "private-subnet-${count.index +1}"
  }
}

#create elastic ip
resource "aws_eip" "eip-1" {
    vpc = true
}


#create nat-gateway
resource "aws_nat_gateway" "nat_gateway-1" {
    allocation_id = aws_eip.eip-1.id
    subnet_id = aws_subnet.public-subnets[0].id 
}


# Create Route Table
resource "aws_route_table" "route-private" {
    vpc_id = aws_vpc.vpc.id
    route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway-1.id
    }
    
}


# Associate Private Subnets to "private Route Table"
resource "aws_route_table_association" "priavte-subnets-route-table-association" {
  count = length( var.private-subnets-cidr )
  subnet_id = element(aws_subnet.private-subnets.*.id, count.index ) 
  route_table_id      = aws_route_table.route-private.id
}

