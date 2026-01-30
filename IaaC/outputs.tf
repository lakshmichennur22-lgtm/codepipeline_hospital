output "frontend_website_url" {
  value = "http://${aws_s3_bucket.frontend.bucket}.s3-website-${var.location}.amazonaws.com"
}