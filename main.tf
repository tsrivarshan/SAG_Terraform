#AWS provider enrollment
provider "aws" {
  region     = "us-east-1"
} 

#VPC creation
resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "Basevpc"
  }
}

#Subnets creation for the VPC

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1d"

  tags = {
    Name = "Subnet1"
  }
   depends_on = [
    aws_vpc.myvpc
  ]
}
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1f"
  
  tags = {
    Name = "Subnet2"
  }
  depends_on = [
    aws_vpc.myvpc
  ]
}
 #Internet Gateway creation
 resource "aws_internet_gateway" "mygw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "myIGW"
  }
  depends_on = [
    aws_vpc.myvpc
    ,aws_subnet.subnet1
    ,aws_subnet.subnet2
  ]
}

#Routing Table creation and attach IG
resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mygw.id
  }
     depends_on = [
    aws_vpc.myvpc
    ,aws_subnet.subnet1
    ,aws_subnet.subnet2
    ,aws_internet_gateway.mygw
  ]
}

#Assosiate subnets to an route Table
resource "aws_route_table_association" "association1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.routetable.id
  depends_on = [
    aws_vpc.myvpc
    ,aws_subnet.subnet1
    ,aws_subnet.subnet2
    ,aws_internet_gateway.mygw
    ,aws_route_table.routetable
  ]
}
resource "aws_route_table_association" "association2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.routetable.id
   depends_on = [
    aws_vpc.myvpc
    ,aws_subnet.subnet1
    ,aws_subnet.subnet2
    ,aws_internet_gateway.mygw
    ,aws_route_table.routetable
  ]
}

locals {
  inbound_ports = [80,443,22,3306]
}


#Creation of Security group for the instance
resource "aws_security_group" "mysg" {
  name="mysecuritygroup"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id
  dynamic "ingress" {
    for_each = local.inbound_ports
    content {
    from_port = ingress.value
    to_port = ingress.value
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
     }
}

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
     depends_on = [
    aws_vpc.myvpc
  ]
  
}
#Network Interface
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.subnet1.id
  security_groups = [aws_security_group.mysg.id]
 depends_on = [
   aws_subnet.subnet1
   ,aws_security_group.mysg
  ]
}
#Instance Creation
resource "aws_instance" "ec2_example" {
    ami = "ami-0cff7528ff583bf9a"  
    instance_type = "t2.micro" 
    subnet_id =  aws_subnet.subnet1.id
    security_groups=[aws_security_group.mysg.id]
    
    tags = {
        Name = "new Terraform EC2"
    } 
    associate_public_ip_address = true
    user_data = "${file("apache.sh")}"
    
   depends_on = [
    aws_security_group.mysg,
    # aws_subnet.subnet1,
    aws_vpc.myvpc
  ]
}
#Subnet Group creation for RDS creation
resource "aws_db_subnet_group" "sg" {
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "MySubnetGroup"
  }
   depends_on = [
    aws_vpc.myvpc
    ,aws_subnet.subnet1
    ,aws_subnet.subnet2
    ,aws_internet_gateway.mygw
    ,aws_route_table.routetable
  ]
}
#RDS creation
resource "aws_db_instance" "mydb" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "mydatabase"
  username             = "srivarshan"
  password             = "srivarshan123"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  db_subnet_group_name=aws_db_subnet_group.sg.id
  depends_on = [
    aws_vpc.myvpc
    ,aws_subnet.subnet1
    ,aws_subnet.subnet2
    ,aws_db_subnet_group.sg
    ,aws_internet_gateway.mygw
    ,aws_route_table.routetable
  ]
  
}

#SNS topic creation
resource "aws_sns_topic" "usersns" {
  name = "usersns"
}


#Topic subscription
resource "aws_sns_topic_subscription" "target" {
  topic_arn = aws_sns_topic.usersns.arn
  protocol  = "email"
  endpoint  = "srivarshant2002@gmail.com"
  depends_on = [
    aws_sns_topic.usersns
  ]
}


#Cloud Metric creation
resource "aws_cloudwatch_metric_alarm" "mymetric" {
  alarm_name          = "samplealarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SampleCheck"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "25"
  alarm_description   = "If the request for an instance is less than 25% then trigger an alarm"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.usersns.arn]
  ok_actions          = [aws_sns_topic.usersns.arn]
  dimensions = {
        InstanceName = "Basemachine"
  }
  depends_on=[

    aws_sns_topic.usersns,
    aws_sns_topic_subscription.target
  ]
}


