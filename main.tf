provider "aws" {
  region = var.region
}

# Security group allowing HTTP only.
resource "aws_security_group" "proxy_sg" {
  name        = "nginx-proxy-sg"
  description = "Security group for Nginx proxy instance"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2121
    to_port     = 2121
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

# EC2 instance with enforced user data replacement
resource "aws_instance" "proxy" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.proxy_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  # Critical for user data updates
  user_data_replace_on_change = true

user_data = <<-EOF
    #!/bin/bash

    set -e  # Exit on error

    # Update system and install Nginx
    dnf update -y
    dnf install -y nginx

    # Ensure Nginx starts on boot
    systemctl enable nginx
    systemctl start nginx

    # Create the Nginx configuration
    cat > /etc/nginx/conf.d/proxy.conf <<EOL
    server {
        listen 2121;
        server_name _;
        location / {
            proxy_pass ${var.proxy_url};
            proxy_set_header Host httpbin.org;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    EOL

    # Remove the default configuration
    rm -f /etc/nginx/conf.d/default.conf

    # Validate the Nginx configuration
    nginx -t || { echo "Nginx config test failed"; exit 1; }

    # Restart Nginx to apply changes
    systemctl restart nginx

    echo "Nginx setup complete!"
  EOF

}

# SSM IAM Resources
resource "aws_iam_role" "ssm_role" {
  name = "SSMnewRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSMProfile"
  role = aws_iam_role.ssm_role.name
}

# Outputs
output "public_dns" {
  value = aws_instance.proxy.public_dns
}

output "instance_id" {
  value = aws_instance.proxy.id
}
