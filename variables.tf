variable "proxy_url" {
  description = "URL to proxy requests to (required)"
  type        = string
  default     = "http://httpbin.org"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.medium"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "ami" {
  description = "Amazon Linux 2 AMI ID"
  type        = string
  default     = "ami-08f9a9c699d2ab3f9"
}
