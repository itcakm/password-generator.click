output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidation)"
  value       = aws_cloudfront_distribution.app.id
}

output "cloudfront_domain" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.app.domain_name
}

output "s3_bucket" {
  description = "App S3 bucket name"
  value       = aws_s3_bucket.app.id
}

output "site_url" {
  description = "Live site URL"
  value       = "https://${var.domain_name}"
}
