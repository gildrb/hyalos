#!/usr/bin/env bash
# This command is intentionally user-run: it uses your local GitHub CLI session.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
repo='gildrb/exo-v2-visuals'
for tool in gh git node npm; do command -v "$tool" >/dev/null || { printf 'Required tool missing: %s\n' "$tool" >&2; exit 1; }; done
gh auth status >/dev/null
login=$(gh api user --jq .login)
[[ "$login" == 'gildrb' ]] || { printf 'Expected GitHub account gildrb; found %s. No changes made.\n' "$login" >&2; exit 1; }
if gh repo view "$repo" --json name >/dev/null 2>&1; then
  printf '%s already exists. Refusing to replace or publish into an existing repository.\n' "$repo" >&2
  exit 1
fi
[[ ! -d .git ]] || { printf 'This folder already has Git history. Review and publish it manually.\n' >&2; exit 1; }
# Resolve dependencies once, then retain the generated lockfile in the initial commit.
# npm is the bootstrap package manager; all app development/build commands use Vite+.
if [[ -f package-lock.json ]]; then npm ci; else npm install; fi
npm test
npm run build
# Browser verification needs a real WebGPU backend. Run npm run test:browser before release.
git init -b main
if ! git var GIT_AUTHOR_IDENT >/dev/null 2>&1; then
  user_id=$(gh api user --jq .id)
  git config user.name "$login"
  git config user.email "${user_id}+${login}@users.noreply.github.com"
fi
git add -- .
git commit -m 'Build local vGPU visual editor with seeded scenes and reproducible exports'
gh repo create "$repo" --private --description 'Local, deterministic WebGPU visual laboratory for abstract distributed intelligence.' --source . --remote origin
[[ "$(gh repo view "$repo" --json isPrivate --jq .isPrivate)" == 'true' ]] || { printf 'Private visibility could not be verified. Nothing pushed.\n' >&2; exit 1; }
git push --set-upstream origin main
[[ "$(gh repo view "$repo" --json isPrivate --jq .isPrivate)" == 'true' ]] || { printf 'WARNING: verify repository visibility immediately.\n' >&2; exit 1; }
printf 'Created private repository: https://github.com/%s\n' "$repo"
