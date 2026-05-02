provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "jenkins_sg" {
  name_prefix = "jenkins-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "jenkins-server"

  security_groups = [aws_security_group.jenkins_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ubuntu
              docker run -d \
                --name jenkins \
                -p 8080:8080 \
                -p 50000:50000 \
                -v jenkins_home:/var/jenkins_home \
                jenkins/jenkins:lts
              EOF

  tags = {
    Name = "jenkins-server"
  }
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "ssh_command" {
  value = "ssh -i jenkins-server.pem ubuntu@${aws_instance.jenkins.public_ip}"
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_initial_password_command" {
  value = "ssh -i jenkins-server.pem ubuntu@${aws_instance.jenkins.public_ip} 'docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword'"
}