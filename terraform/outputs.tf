output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.cyberchef.id
}

output "instance_ip" {
  description = "Public IP of the CyberChef instance"
  value       = aws_instance.cyberchef.public_ip
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB fronting CyberChef - this is the way to reach the API now (port 3000 on the instance itself is no longer directly reachable)"
  value       = aws_lb.cyberchef.dns_name
}

output "ssm_transfer_bucket" {
  description = "S3 bucket used by the aws_ssm Ansible connection plugin for file transfer"
  value       = aws_s3_bucket.ssm_transfer.id
}

output "ssm_command" {
  description = "SSM command to connect to the instance"
  value       = "aws ssm start-session --target ${aws_instance.cyberchef.id} --region ${var.region} --profile cyberchef"
}

output "testing" {
  description = "Testing output to verify that the module is working"
  value       = "Hello, world!"
}