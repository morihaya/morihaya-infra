# Terraform AWS - Rott

My personal AWS Root account

Using:
- Managed by terraform
  - AWS Budget
  - Amazon SNS(Simple Notification Service)
- Not managed by terraform
  - AWS Control Tower (not managed by terraform)
  - AWS Chatbot (not managed by terraform)
  - Amazon S3
  - Route 53

Terraform state is in app.terraform.io.

Shoud set below variables for terraform:
- "aws_accountid" # Set AWS Account ID
- "mail_alert"    # Set E-mail address to notify from sns
