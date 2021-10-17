variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "cluster"
}

variable "vpc_id" {
  type    = string
  default = "vpc-01472c44ec8cf0342"
}

variable "public_subnet_ids" {
  type    = list(string)
  default = ["subnet-05dca684236b95620", "subnet-02a78b0f99fdc85d0"]
}

variable "private_subnet_ids" {
  type    = list(string)
  default = [
    "subnet-0e4d0e706e9a79866",
    "subnet-0d43e4b759d51b49f"
  ]
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1c"]
}
