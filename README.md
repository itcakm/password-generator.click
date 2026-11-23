# password-generator.click

A cryptographically secure, zero-dependency password generator — served as a static site via AWS S3 + CloudFront.

**Live:** https://password-generator.click

---

## Features

- All generation uses `window.crypto.getRandomValues()` (CSPRNG) — nothing is sent to a server
- Random passwords, passphrases, and PINs
- Configurable length (4–128), character sets, quantity, and "must include" rules
- Entropy display in bits with strength rating
- Keyboard shortcut: press `r` to regenerate
- Terminal-friendly — `curl` and `wget` receive a plain-text password directly

## Terminal usage

```bash
# Get a password instantly
curl https://password-generator.click

# Pipe to clipboard (macOS)
curl https://password-generator.click | pbcopy

# Force plain-text from a browser
curl "https://password-generator.click?plain"
```

The site detects `curl`, `wget`, `httpie`, `python-requests`, and similar User-Agents and responds with `text/plain` — one password per line, no markup, pipe-ready.

---

## Architecture

```
Route 53 → CloudFront → S3 (private, OAC)
               │
               ├─ CloudFront Function (viewer-request):  terminal routing
               └─ CloudFront Function (viewer-response): security headers
```

- **S3 bucket** — private, versioned, encrypted at rest, no public access
- **CloudFront OAC** — only CloudFront can read from the bucket
- **ACM certificate** — us-east-1 (CloudFront requirement), DNS-validated via Route 53
- **TLS** — TLSv1.2_2021 minimum, HTTPS-only
- **Security headers** — HSTS, CSP, X-Frame-Options, Referrer-Policy, Permissions-Policy

---

## Infrastructure

Managed entirely with Terraform (`terraform/`).

**State:** S3 backend (`password-generator-click-tfstate`) with native S3 locking (`use_lockfile = true`, Terraform ≥ 1.11 — no DynamoDB needed).

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

---

## CI/CD

| Trigger | Workflow | Action |
|---|---|---|
| Pull request → `main` | `terraform-plan.yml` | `terraform plan`, posts output to PR |
| Push → `main` | `deploy.yml` | `terraform apply`, sync to S3, invalidate CF |

GitHub Actions authenticates to AWS via **OIDC** — no long-lived credentials stored.

---

## Repository layout

```
.
├── src/
│   ├── index.html          # The entire app — no build step, no deps
│   ├── 404.html
│   ├── generate-plain.js   # Deploy-time script: generates plain.txt password pool
│   ├── plain.txt           # Generated at deploy time — served to terminal clients
│   └── plain.json          # Password pool for CloudFront Function indexing
├── terraform/
│   ├── versions.tf         # Backend + provider config
│   ├── variables.tf
│   ├── s3.tf               # App bucket + OAC policy
│   ├── acm.tf              # Certificate (us-east-1)
│   ├── cloudfront.tf       # Distribution + CF Functions
│   ├── route53.tf          # A/AAAA records for apex + www
│   └── outputs.tf
└── .github/workflows/
    ├── terraform-plan.yml  # PR check
    └── deploy.yml          # Production deploy
```
