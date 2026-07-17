variable "mail_alert" {
  description = "Email address that receives AWS Budgets notifications"
  type        = string
}

# These variables are defined at the HCP Terraform organization level
# but are not used in this workspace. Declaring them here
# silences the "undeclared variable" warnings.
# tflint-ignore: terraform_unused_declarations
variable "aws_accountid" {
  description = "Unused variable from TFC global settings (account ID is resolved via aws_caller_identity)"
  type        = string
  default     = ""
}

# tflint-ignore: terraform_unused_declarations
variable "AWS_ACCESS_KEY_ID" {
  description = "Unused variable from TFC global settings"
  type        = string
  default     = ""
  sensitive   = true
}
