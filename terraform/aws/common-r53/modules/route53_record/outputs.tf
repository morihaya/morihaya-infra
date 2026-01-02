output "fqdn" {
  description = "FQDN of the record"
  value       = aws_route53_record.this.fqdn
}

output "name" {
  description = "Name of the record"
  value       = aws_route53_record.this.name
}
