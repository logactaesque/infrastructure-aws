# Infrastructure AWS
Provisioning the supporting infrastructure in AWS for Logactaesque using [Terraform](https://www.terraform.io/)

## Prerequisites
- An [AWS](https://aws.amazon.com/) account
- The AWS [CLI](https://aws.amazon.com/cli/) tool 
- An AWS IAM account with relevant privileges to construct AWS infrastructural components.
- AWS Access and Secret Key configured locally (e.g. for Linux, this would sit under `~/.aws`)
- Terraform (this work used version **v1.2.8**)
- An AWS S3 bucket to hold terraform state (presently *logactaesque-terraform-state*)

## How to build the infrastructure

Initialise Terraform and state management for the project:

    terraform init -backend-config="dev.config" 

This ensures we have an S3 bucket referenced in the config file that is ready to hold state 

To seeee what will be applied by Terraform after changes, then use

    terraform plan -var-file="dev.tfvars"

...where _dev.tfvars_ represents the variables to pass in.

To apply the changes:

    terraform apply -var-file="dev.tfvars"

To teardown the resources managed here:

    terraform destroy -var-file="dev.tfvars"

## What is constructed in AWS

| Name | Resource | Notes |
|------|----------|-------|
| TBC  | TBC      | TBC   |

The terraform script prints out a URL to reference the deployed service in Fargate.