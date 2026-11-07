#!/usr/bin/env bash
set -euo pipefail
if git ls-files | grep -E '(^|/)Secrets\.xcconfig$' ; then
  echo "ERROR: secret file is tracked" >&2; exit 1
fi
echo "ok: no secrets tracked"
