# Infrastructure AWS
Provisioning the supporting infrastructure in AWS for Logactaesque using [Terraform](https://www.terraform.io/)

## Prerequisites
- An [AWS](https://aws.amazon.com/) account
- The AWS [CLI](https://aws.amazon.com/cli/) tool 
- An AWS IAM account with relevant privileges to construct AWS infrastructural components.
- AWS Access and Secret Key configured locally (e.g. for Linux, this would sit under `~/.aws`)
- Terraform (this work used version **v0.14.8**)
- An AWS S3 bucket to hold terraform state (presently *logactaesque-terraform-state*)

## How to build the infrastructure

Initialise Terraform and state management for the project:

    terraform init -backend-config="dev.config" 

See what will be applied by Terraform:

    terraform plan -var-file="dev.tfvars"

To apply the changes:

    terraform apply -var-file="dev.tfvars"

To teardowm the resources managed here:

    terraform destroy


## What is constructed

| Resource| Name | 
|--|--|
|ECR Repository for containers built via Github pipelines| |
| | |
