#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/preview-local.sh [--clean]

Default: fast normal preview build.
--clean: remove generated output and caches before a full rebuild when stale output is suspected.
EOF
}

clean=false
case "${1-}" in
  '') ;;
  --clean) clean=true ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    printf 'Unknown argument: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"

cd "$repository_root"
if "$clean"; then
  rm -rf _site .jekyll-cache .sass-cache
fi

bundle exec jekyll build

echo "Local preview: http://127.0.0.1:4000/"
exec python3 -m http.server 4000 --directory "$repository_root/_site"
