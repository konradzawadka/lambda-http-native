variable "name" {
  type = string
}

variable "package_filename" {
  type = string
  default = "./target/function.zip"
}

variable "env_variables"{
  type = map(any)
}

variable "policy_arn" {
  type = string
}

variable "ram" {
  type = string
  default = "256"
}