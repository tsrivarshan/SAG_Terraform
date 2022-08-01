#!/bin/bash

sudo su
yum update
yum install -y httpd
systemctl status httpd service
service httpd start
chkconfig httpd on
echo "<html><body><h1> Hi Srivarshan using Terraform </h1></body></html>" > /var/www/html/index.html
yum install mysql -y
