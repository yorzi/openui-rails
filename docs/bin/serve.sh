#!/usr/bin/env bash
# Build the complete static site and preview it at http://127.0.0.1:4000. Ctrl-C stops it.
#   docs/bin/serve.sh        PORT=4002 docs/bin/serve.sh
set -euo pipefail

unset RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLE_BIN BUNDLE_APP_CONFIG

docs="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="" "$docs/bin/build.sh"
exec python3 -m http.server "${PORT:-4000}" \
  --bind 127.0.0.1 --directory "$docs/_site"
