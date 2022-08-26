variable "region" {
  default     = "eu-west-1"
  description = "AWS region"
}

variable "availability-zone" {
  # Just use one availability zone for now
  default     = "eu-west-1a"
  description = "AWS availability zone"
}
