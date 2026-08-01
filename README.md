# cyberchef-infra

CyberChef, deployed as a REST API on AWS, provisioned with Terraform and configured with Ansible, deployed via GitHub Actions.

- **API**: [gchq/CyberChef-server](https://github.com/gchq/CyberChef-server), a real REST API (`POST /bake`).
- **Infra**: single `t3.micro` EC2 instance behind an ALB, `eu-north-1`.
- **Access**: SSM only. No SSH, no key pairs, no port 22.
- **CI/CD**: GitHub Actions, authenticated to AWS via OIDC.

## Testing the API

Current entry point: `cyberchef-alb-542378925.eu-north-1.elb.amazonaws.com` (run `terraform output alb_dns_name` to get the up-to-date value, it changes if the ALB is ever recreated).

```
curl -X POST -H "Content-Type: application/json" \
  -d '{"input":"SGVsbG8gV29ybGQ=", "recipe":{"op":"From Base64"}}' \
  http://cyberchef-alb-542378925.eu-north-1.elb.amazonaws.com/bake
```

```json
{"value":[72,101,108,108,111,32,87,111,114,108,100],"type":"byteArray"}
```

Swagger docs at `http://cyberchef-alb-542378925.eu-north-1.elb.amazonaws.com/`. The EC2 instance itself isn't reachable directly, only the ALB is.

> The Swagger page itself won't render in a browser over plain HTTP (the app's CSP tells the browser to upgrade its own assets to HTTPS, which times out with no TLS listener). The API endpoints are unaffected, `curl` doesn't hit this.

## Repo layout

```
.
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── alb.tf
│   ├── oidc.tf
│   ├── ssm-transfer-bucket.tf
│   └── outputs.tf
├── ansible/
│   ├── playbook.yml
│   └── inventory.aws_ec2.yml
└── .github/workflows/
    ├── terraform-plan.yml
    ├── deploy.yml
    ├── terraform.yml
    └── ansible.yml
```

## CI/CD

- **PR**: `terraform-plan.yml` runs Checkov + `terraform plan`, posted as a PR comment. Nothing applied.
- **Push to `main`**: `deploy.yml` runs `terraform apply`, then the Ansible playbook.
- `terraform.yml` and `ansible.yml` are also independently `workflow_dispatch`-able for manual/one-off runs.
- Auth is GitHub OIDC to an IAM role trust-policy-pinned to this repo's immutable ID (survives a rename, unlike a name-only policy). Only secret in GitHub is `AWS_ROLE_ARN`. Secrets aren't exposed to fork-PR runs, so a malicious PR can't exfiltrate anything.
- The CI role's IAM permissions are hand-scoped (see `oidc.tf`) to close off a privilege-escalation path a broader policy would leave open.

## Key decisions

- **SSM over SSH**. No keys to manage, no open port 22, access is IAM-governed and logged.
- **Dynamic Ansible inventory**. Looks up the instance by tag instead of a hardcoded ID, since Terraform can replace the instance (e.g. on encryption changes).
- **S3 native locking** instead of DynamoDB for the Terraform backend. One less resource to run.
- **Checkov in CI**, with accepted findings suppressed via inline `#checkov:skip` comments stating why.
- **ALB in front of a single instance**. Closes direct access to the instance, and is where TLS gets added later with no other changes needed.

## Production improvements (not implemented here)

- **TLS via ACM**. Blocked for now: the only domain available is a DuckDNS one, and ACM can't validate it (no arbitrary CNAME support, no control over email validation contacts). With a real domain this is just an `aws_acm_certificate` plus a 443 listener added to `alb.tf`.
- **AWS WAF** in front of the ALB.
- **ALB access logging** to S3.
- **Detailed CloudWatch monitoring**. Skipped, recurring cost not worth it for a demo instance.
- **Further-scoped IAM**. Provisioning still uses AWS-managed full-access policies (EC2/SSM/S3); only the IAM-management permissions were hand-scoped so far.
- **Autoscaling**. The ALB/target group setup makes swapping in an ASG a small change.
