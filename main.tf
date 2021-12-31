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

resource "aws_ecr_repository" "logactaesque-dice-roller-repo" {
  name                 = "logactaesque-dice-roller"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "logactaesque-dice-roller-repo-policy" {
  repository = aws_ecr_repository.logactaesque-dice-roller-repo.name
  policy     = <<EOF
  {
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "Adds full ECR access to dice-roller image repository",
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
