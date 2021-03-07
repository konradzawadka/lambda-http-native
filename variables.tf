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

variable "handler" {
  type = string
  default = "native.handler"
}

variable "runtime" {
  type = string 
  default = "provided"
}


variable "cors_allow_methods" {
  type = array(string)
}

variable "cors_allow_headers" {
  type = array(string)
}

variable "cors_allow_origins" {
  type = array(string)
}

variable "domain_name" {
  type = string
}