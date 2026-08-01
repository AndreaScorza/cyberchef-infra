# cyberchef-infra

CyberChef, deployed as a REST API on AWS, provisioned with Terraform and configured with Ansible, deployed via GitHub Actions.

- **API**: [gchq/CyberChef-server](https://github.com/gchq/CyberChef-server) — a real REST API (`POST /bake`).
- **Infra**: single `t3.micro` EC2 instance behind an ALB, `eu-north-1`.
- **Access**: SSM only — no SSH, no key pairs, no port 22.
- **CI/CD**: GitHub Actions, authenticated to AWS via OIDC.

## Testing the API

```
terraform output alb_dns_name

curl -X POST -H "Content-Type: application/json" \
  -d '{"input":"SGVsbG8gV29ybGQ=", "recipe":{"op":"From Base64"}}' \
  http://<alb_dns_name>/bake
```

```json
{"value":[72,101,108,108,111,32,87,111,114,108,100],"type":"byteArray"}
```

Swagger docs at `http://<alb_dns_name>/`. The EC2 instance itself isn't reachable directly — only the ALB.

## Repo layout

```
terraform/
  providers.tf
  variables.tf
  main.tf
  alb.tf
  oidc.tf
  ssm-transfer-bucket.tf
  outputs.tf
ansible/
  playbook.yml
  inventory.aws_ec2.yml
.github/workflows/
  terraform-plan.yml
  deploy.yml
  terraform.yml
  ansible.yml
```

## CI/CD

- **PR** → `terraform-plan.yml`: Checkov + `terraform plan`, posted as a PR comment. Nothing applied.
- **Push to `main`** → `deploy.yml`: `terraform apply`, then the Ansible playbook.
- `terraform.yml` / `ansible.yml` are also independently `workflow_dispatch`-able for manual/one-off runs.
- Auth is GitHub OIDC → an IAM role trust-policy-pinned to this repo's immutable ID (survives a rename, unlike a name-only policy). Only secret in GitHub is `AWS_ROLE_ARN`. Secrets aren't exposed to fork-PR runs, so a malicious PR can't exfiltrate anything.
- The CI role's IAM permissions are hand-scoped (see `oidc.tf`) to close off a privilege-escalation path a broader policy would leave open.

## Key decisions

- **SSM over SSH** — no keys to manage, no open port 22, access is IAM-governed and logged.
- **Dynamic Ansible inventory** — looks up the instance by tag instead of a hardcoded ID, since Terraform can replace the instance (e.g. on encryption changes).
- **S3 native locking** instead of DynamoDB for the Terraform backend — one less resource to run.
- **Checkov in CI**, with accepted findings suppressed via inline `#checkov:skip` comments stating why.
- **ALB in front of a single instance** — closes direct access to the instance, and is where TLS gets added later with no other changes needed.

## Production improvements (not implemented here)

- **TLS via ACM** — blocked for now: the only domain available is a DuckDNS one, and ACM can't validate it (no arbitrary CNAME support, no control over email validation contacts). With a real domain this is just an `aws_acm_certificate` + a 443 listener added to `alb.tf`.
- **AWS WAF** in front of the ALB.
- **ALB access logging** to S3.
- **Detailed CloudWatch monitoring** — skipped, recurring cost not worth it for a demo instance.
- **Further-scoped IAM** — provisioning still uses AWS-managed full-access policies (EC2/SSM/S3); only the IAM-management permissions were hand-scoped so far.
- **Autoscaling** — the ALB/target group setup makes swapping in an ASG a small change.
