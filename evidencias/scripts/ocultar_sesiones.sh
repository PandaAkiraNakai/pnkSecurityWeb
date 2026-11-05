#!/usr/bin/env bash
# ES3: oculta en las evidencias guardadas las cookies de sesión y los tokens CSRF
# (la pauta pide ocultar cookies y tokens). Uso: ocultar_sesiones.sh <dir>...
set -euo pipefail
for d in "$@"; do
  grep -rl -E 'PHPSESSID=[A-Za-z0-9,-]{8,}|name="csrf"[^>]*value="[0-9a-f]{64}"|name="csrf-token" content="[0-9a-f]{64}"|X-CSRF-Token: [0-9a-f]{64}' "$d" 2>/dev/null \
  | while read -r f; do
      sed -i -E 's/PHPSESSID=[A-Za-z0-9,-]{8,}/PHPSESSID=[oculta]/g; s/(name="csrf"[^>]*value=")[0-9a-f]{64}/\1[token oculto]/g; s/(name="csrf-token" content=")[0-9a-f]{64}/\1[token oculto]/g; s/(X-CSRF-Token: )[0-9a-f]{64}/\1[token oculto]/g' "$f"
      echo "ocultado: $f"
    done
done
