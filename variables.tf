variable "aws_region" {
    default = "us-east-1"
    description = "AWS region where this IaC will be deployed"
}

variable "website_domain" {
    description = "DNS domain of the website being created"
}
