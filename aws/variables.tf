variable "account_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_dns" {
  type = string
}

variable "k3s_version" {
  type = string
  default = "v1.21.12"
}

variable "instance_type" {
  type = string
}
