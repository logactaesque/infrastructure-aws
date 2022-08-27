variable "region" {
  default     = "eu-west-1"
  description = "AWS region"
}

variable "availability-zone_1" {
  # Just use one availability zone for now
  default     = "eu-west-1a"
  description = "First availability zone"
}

variable "availability-zone_2" {
  # Just use one availability zone for now
  default     = "eu-west-1b"
  description = "Second availability zone"
}