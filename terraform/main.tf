terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

//  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-1"
}

# Create the IAM instance profile
resource "aws_iam_instance_profile" "ml_instance_profile" {
  name = "ml_instance_profile"
  role = "${aws_iam_role.ml_instance_role.name}"
}

# Create the IAM role for the instance
resource "aws_iam_role" "ml_instance_role" {
  name = "ml_instance_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach an IAM policy that allows access to the S3 bucket
resource "aws_iam_policy" "s3_access_policy" {
  name = "s3_access_policy"
  description = "Policy that allows access to the ml-trainingdata S3 bucket"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::ml-trainingdata",
        "arn:aws:s3:::ml-trainingdata/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "s3_access_policy_attach" {
  name = "s3_access_policy_attach"
  policy_arn = aws_iam_policy.s3_access_policy.arn
  roles = [aws_iam_role.ml_instance_role.name]
}

resource "aws_instance" "ml_instance" {
  ami = "ami-0737fdcc3ab2db781"
  instance_type = "t2.medium"

  key_name = "aws_key"

  iam_instance_profile = "${aws_iam_instance_profile.ml_instance_profile.name}"

  user_data_replace_on_change = true

  # Set the user data to run the init script on instance launch
  # create a conda environment
  # verify /var/log/cloud-init-output.log

      # bypass of long processing triggers

//    sudo dpkg --purge --force-remove-reinstreq --force-remove-essential --force-depends libc-bin
//    sudo mv /var/lib/dpkg/info/libc6\:amd64.* /tmp/
//
//    export DEBIAN_FRONTEND=noninteractive
//    export LANGUAGE=en_US.UTF-8
//    export LANG=en_US.UTF-8
//    export LC_ALL=en_US.UTF-8
//    locale-gen en_US.UTF-8
//    dpkg-reconfigure locales
//
//    sudo apt-get -y install -f libc-bin
//    sudo mv /tmp/libc6\:amd64.* /var/lib/dpkg/info/

//  #    export DEBIAN_FRONTEND=noninteractive
//#    export DEBIAN_PRIORITY=critical
//#    sudo apt-get update --fix-missing
//#    sudo apt-get -y install awscli
//
//  #    aws s3 cp s3://ml-trainingdata/training-data/train.zip .
//#    unzip train.zip
//#

  user_data = <<-EOF
    #!/bin/bash

    cd home/ubuntu
    env "PATH=$PATH" conda update -n base -c conda-forge conda
    git clone https://github.com/cyj407/DiSS.git
    cd DiSS
    conda env create -f diss_env.yaml
    cd /DiSS/guided_diffusion
    conda run -n DiSS python setup.py install

    sudo mkdir -p /mnt/data
    sudo mount /dev/xvdf /mnt/data

  EOF

  # Specify the EBS volume size and type
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 100
    volume_type = "gp2"
  }

  tags = {
    Name = "ExampleMLInstance"
  }
}

resource "aws_volume_attachment" "ml_instance_volume_attachment" {
  device_name = "/dev/sdf"
  volume_id   = "vol-0c9a142284f2f8365"
  instance_id = "${aws_instance.ml_instance.id}"
}


# Attach the necessary policies to the role
resource "aws_security_group" "ml_instance_security_group" {
  name = "ml_instance_security_group"
  description = "Allow SSH and HTTP traffic"

  ingress {
    description = "SSH traffic"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  ingress {
    description = "HTTP traffic"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}


