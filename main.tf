provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {}
}

# We assume in place:
# AWS IAM account with relevant privileges to construct AWS resources.
# AWS Access and Secret Key configured (for Linux this would sit under ~/.aws)
# An AWS S3 bucket to hold terraform state

resource "aws_ecr_repository" "logactaesque-ecr-repo" {
  name                 = "logactaesque-ecr-repo"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "logactaesque-ecr-repo-policy" {
  repository = aws_ecr_repository.logactaesque-ecr-repo.name
  policy     = <<EOF
  {
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "Adds full ECR access to the Logactaesque repository",
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      }
    ]
  }
  EOF
}
