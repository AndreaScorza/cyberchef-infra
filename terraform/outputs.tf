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

output "ssm_command" {
  description = "SSM command to connect to the instance"
  value       = "aws ssm start-session --target ${aws_instance.cyberchef.id} --region ${var.region} --profile cyberchef"
}