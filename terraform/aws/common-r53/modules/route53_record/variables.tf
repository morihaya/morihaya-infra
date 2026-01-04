variable "zone_id" {
  description = "Route 53 Zone ID"
  type        = string
}

variable "name" {
  description = "DNS record name (FQDN)"
  type        = string
}

variable "type" {
  description = "DNS record type (A, CNAME, etc.)"
  type        = string
  default     = "A"
}

variable "ttl" {
  description = "TTL in seconds"
  type        = number
  default     = 300
}

variable "records" {
  description = "List of record values"
  type        = list(string)
}
