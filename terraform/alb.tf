data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:Attached to the aws_lb.cyberchef load balancer below.
  #checkov:skip=CKV_AWS_260:HTTP-only for now (see file header) - a public ALB accepting HTTP has to allow 0.0.0.0/0 on port 80.
  name        = "cyberchef-alb"
  description = "CyberChef ALB security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Pulled out as standalone rules (rather than inline on the aws_security_group
# blocks) because these two rules reference each other's security group -
# inline blocks would make Terraform see aws_security_group.alb and
# aws_security_group.cyberchef as depending on each other, a real cycle.
# Standalone rules break that: the SG shells no longer depend on each other,
# only these rule resources do.
resource "aws_vpc_security_group_ingress_rule" "cyberchef_from_alb" {
  security_group_id            = aws_security_group.cyberchef.id
  description                  = "CyberChef API, from the ALB only"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_cyberchef" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To CyberChef instance"
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cyberchef.id
}

resource "aws_lb" "cyberchef" {
  #checkov:skip=CKV_AWS_150:Deletion protection isn't needed for this demo project; ease of teardown matters more here.
  #checkov:skip=CKV_AWS_91:Access logging isn't set up yet - would need its own S3 bucket; not worth the added scope for a demo ALB.
  #checkov:skip=CKV_AWS_131:HTTP-only for now (see file header) - nothing to drop for HTTPS since there's no HTTPS listener yet.
  #checkov:skip=CKV2_AWS_20:Can't redirect to HTTPS without an ACM cert; see file header for why one isn't available yet.
  #checkov:skip=CKV2_AWS_28:AWS WAF is a separate, billed service - out of scope for this demo project.
  name               = "cyberchef-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "cyberchef" {
  #checkov:skip=CKV_AWS_378:HTTP-only for now (see file header) - target group protocol matches the listener until an ACM cert is available.
  name        = "cyberchef-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "cyberchef" {
  target_group_arn = aws_lb_target_group.cyberchef.arn
  target_id        = aws_instance.cyberchef.id
  port             = 3000
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:No ACM cert available yet (see file header) - plain HTTP listener is the documented interim state.
  #checkov:skip=CKV_AWS_103:Same as above - TLS 1.2 policy doesn't apply without an HTTPS listener.
  load_balancer_arn = aws_lb.cyberchef.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cyberchef.arn
  }
}
