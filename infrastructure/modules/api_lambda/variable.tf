variable "project_name" {
  type = string
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

variable "lambda_memory" {
  type    = number
  default = 128
}
