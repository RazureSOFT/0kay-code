#!/usr/bin/env bash
# Apply the 0KAY IDE identity to the upstream checkout.
#
# VSCodium's build pulls microsoft/vscode into ./vscode and then patches it. The
# product identity lives in vscode/product.json, so this runs after get_repo.sh and
# before build.sh: it merges our overlay rather than hand-editing a file that moves
# with every upstream tag.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$ROOT/vscode/product.json}"

if [[ ! -f "$TARGET" ]]; then
  echo "no product.json at $TARGET — run get_repo.sh first" >&2
  exit 1
fi

python - "$TARGET" "$ROOT/branding/product-overlay.json" <<'PYTHON'
import json
import sys

target, overlay = sys.argv[1], sys.argv[2]
with open(target, encoding="utf-8") as handle:
    product = json.load(handle)
with open(overlay, encoding="utf-8") as handle:
    identity = json.load(handle)

product.update(identity)
# Updates come from our own feed. Leaving Microsoft's would offer to turn this
# build back into VS Code.
product["updateUrl"] = product.get("updateUrl", "")
product.setdefault("extensionsGallery", product.get("extensionsGallery", {}))

with open(target, "w", encoding="utf-8") as handle:
    json.dump(product, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
PYTHON

echo "branded $TARGET as 0KAY IDE"
