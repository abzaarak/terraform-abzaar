# 🧰 terraform-abzaar

Multi-version, parallel-built, Dockerized **Terraform** CLI toolchain — containerized with useful utilities for DevOps engineers.

📦 Supports Terraform versions from `0.13.7` up to `1.11.3`, with the ability to add more versions by updating `versions.txt` and running the build script.

---

## 🛠 What's Included in Each Image

Each image contains:

- ✅ `terraform` CLI (specific version)
- 🧪 Testing and tooling utilities:
  - `aws` (AWS CLI v1 or v2, depending on Terraform compatibility)
  - `tflint`
  - `terraform-docs`

> ℹ️ **Note**: AWS CLI version varies by Terraform version — older versions use AWS CLI v1, newer ones use v2.

---

## ⚙️ Usage (with Prebuilt Docker Hub Images)

No local build is needed. Just set up the runner script and aliases.

### 1. Create the runner script at `~/bin/terraform-container`:

```bash
#!/usr/bin/env bash
set -e

if [[ -z "$1" ]]; then
  echo "Usage: $0 <terraform-version> [terraform args...]"
  exit 1
fi

TF_VERSION="$1"
shift

docker run --rm -it \
  -v "$PWD":/infra \
  -w /infra \
  --platform linux/amd64 \
  devopscloudycontainers/terraform:"$TF_VERSION" "$@"
```

### 2. Make it executable:

```bash
chmod +x ~/bin/terraform-container
```

### 3. Add aliases to your shell config (e.g. `~/.zshrc.aliases`):

```bash
alias tfabzaar="~/bin/terraform-container"  # Container runner
alias tf0-13='tfabzaar 0.13.7'
alias tf0-14='tfabzaar 0.14.11'
alias tf0-15='tfabzaar 0.15.5'
alias tf1-0='tfabzaar 1.0.11'
alias tf1-1='tfabzaar 1.1.9'
alias tf1-2='tfabzaar 1.2.9'
alias tf1-3='tfabzaar 1.3.10'
alias tf1-4='tfabzaar 1.4.7'
alias tf1-5='tfabzaar 1.5.7'
alias tf1-6='tfabzaar 1.6.6'
alias tf1-7='tfabzaar 1.7.5'
alias tf1-8='tfabzaar 1.8.5'
alias tf1-9='tfabzaar 1.9.8'
alias tf1-10='tfabzaar 1.10.5'
alias tf1-11='tfabzaar 1.11.3'
```

Then reload your shell:

```bash
exec zsh
```

---

## ✅ Example Commands

```bash
tf1-1 version
tf1-11 plan -out=tf.plan
tf0-13 apply
```

---

## 📁 Repo Structure

```
terraform-abzaar/
├── Dockerfile.template         # Dockerfile template used for all versions
├── versions.txt                # List of Terraform versions to build
├── bootstrap.sh                # Parallel build + push + test script
├── README.md                   # You're reading it :)
├── .gitignore                  # Ignore logs and metrics
~/bin/
└── terraform-container         # Runner script (outside the repo, in $PATH)
```

---

## 🧪 Recommended Local Tools (Optional)

Install these locally to enhance your workflow and testing experience:

- [`tflint`](https://github.com/terraform-linters/tflint) – Lint Terraform code
- [`tfsec`](https://github.com/aquasecurity/tfsec) – Static security scanner
- [`checkov`](https://github.com/bridgecrewio/checkov) – Infrastructure security analysis
- [`terraform-docs`](https://terraform-docs.io/) – Auto-generate module docs
- [`direnv`](https://direnv.net/) – Load environment variables per project
- [`pre-commit`](https://pre-commit.com/) – Git hook automation for Terraform
- [`infracost`](https://github.com/infracost/infracost) – Cloud cost estimation for Terraform

Example:

```bash
tflint
tfsec .
terraform-docs markdown table . > README.md
```

---

## 📝 License

MIT
