#!/usr/bin/env bash
# Copie le build Flutter web dans .vercel/output (Build Output API v3),
# avec les routes et en-têtes de deploy/vercel/config.json.
# À lancer depuis la racine du dépôt, après `flutter build web`.
set -euo pipefail

if [ ! -f build/web/index.html ]; then
  echo "build/web/index.html introuvable : lancer flutter build web d'abord." >&2
  exit 1
fi

rm -rf .vercel/output
mkdir -p .vercel/output/static
cp -r build/web/. .vercel/output/static/
cp deploy/vercel/config.json .vercel/output/config.json
