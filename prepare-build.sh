#!/usr/bin/env bash
# Prepare the upstream checkout so it can be compiled on this machine.
#
# Everything here was learned the hard way; each step corresponds to a failure the
# build produces without it. Run it after get_repo.sh and apply-branding.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSC="$ROOT/vscode"
REGISTRY="https://registry.npmmirror.com"

[[ -d "$VSC" ]] || { echo "no vscode checkout at $VSC" >&2; exit 1; }

# build_from_source turns node-pty into a node-gyp job that needs MSVC, and the
# default disturl points at GitHub, which is slow here. Neither is needed: node-pty
# ships a prebuilt binary for the pinned Electron.
python - "$VSC/.npmrc" <<'PYTHON'
import io, sys
path = sys.argv[1]
lines = []
for line in io.open(path, encoding='utf-8').read().splitlines():
    if line.strip().startswith('build_from_source'):
        continue          # prebuilt binaries are the supported path
    lines.append(line)
if not any('registry=' in line for line in lines):
    lines.append('registry=https://registry.npmmirror.com')
io.open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
PYTHON

# --ignore-scripts skips the postinstall steps that fetch binaries from GitHub
# (ripgrep, playwright) and would otherwise hang.
cd "$VSC"
npm install --ignore-scripts --no-audit --no-fund --registry "$REGISTRY"

# build/ and every extension are separate npm projects; the root install does not
# cover them, and each has its own lockfile so `npm ci` keeps the versions the
# TypeScript in this tree expects.
for dir in build extensions/* .vscode/extensions/* extensions/*/client extensions/*/server; do
  [[ -f "$dir/package.json" ]] || continue
  if [[ -f "$dir/package-lock.json" ]]; then
    ( cd "$dir" && npm ci --ignore-scripts --no-audit --no-fund --registry "$REGISTRY" ) || true
  else
    ( cd "$dir" && npm install --ignore-scripts --no-audit --no-fund --registry "$REGISTRY" ) || true
  fi
done

# esbuild is resolved from extensions/, not from the root, because the extension
# build scripts live there.
( cd extensions && npm install --no-save --no-audit --no-fund --registry "$REGISTRY" esbuild ) || true

echo "prepared $VSC — next: npm run compile-client"
