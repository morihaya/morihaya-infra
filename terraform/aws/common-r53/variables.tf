# These variables are defined at the TFC organization level
# but are not used in this workspace. Declaring them here
# silences the "undeclared variable" warnings.
#
# Note: It's recommended to use TF_VAR_... environment variables
# for sensitive credentials like AWS_ACCESS_KEY_ID instead of
# terraform.tfvars.
variable "aws_accountid" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
}

variable "private_key" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
  sensitive   = true
}

variable "AWS_ACCESS_KEY_ID" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
  sensitive   = true
}
