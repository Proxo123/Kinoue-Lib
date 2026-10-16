#!/usr/bin/env bash
set -euo pipefail
mkdir -p .cache/gitleaks
curl --fail --location --silent --show-error https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz -o .cache/gitleaks.tar.gz
printf '%s  %s\n' '551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb' '.cache/gitleaks.tar.gz' | sha256sum --check --status
tar -xzf .cache/gitleaks.tar.gz -C .cache/gitleaks
.cache/gitleaks/gitleaks git --log-opts='--all' --redact=100 --no-banner
