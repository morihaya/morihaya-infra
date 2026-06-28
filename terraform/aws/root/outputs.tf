output "enforce_mfa_policy_arn" {
  description = "ARN of the EnforceMFA IAM policy"
  value       = aws_iam_policy.enforce_mfa.arn
}

output "require_mfa_group_name" {
  description = "Name of the RequireMFA IAM group"
  value       = aws_iam_group.require_mfa.name
}

output "require_mfa_group_arn" {
  description = "ARN of the RequireMFA IAM group"
  value       = aws_iam_group.require_mfa.arn
}
