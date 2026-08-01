output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.cyberchef.id
}

output "instance_ip" {
  description = "Public IP of the CyberChef instance"
  value       = aws_instance.cyberchef.public_ip
}

output "ssm_command" {
  description = "SSM command to connect to the instance"
  value       = "aws ssm start-session --target ${aws_instance.cyberchef.id} --region ${var.region} --profile cyberchef"
}