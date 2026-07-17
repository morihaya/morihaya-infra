# These variables are defined at the TFC organization level
# but are not used in this workspace. Declaring them here
# silences the "undeclared variable" warnings.
#
# Note: It's recommended to use TF_VAR_... environment variables
# for sensitive credentials like AWS_ACCESS_KEY_ID instead of
# terraform.tfvars.

# tflint-ignore: terraform_unused_declarations
variable "aws_accountid" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
}

# tflint-ignore: terraform_unused_declarations
variable "private_key" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "AWS_ACCESS_KEY_ID" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
  sensitive   = true
}

# tflint-ignore: terraform_unused_declarations
variable "AWS_SECRET_ACCESS_KEY" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
  sensitive   = true
}
