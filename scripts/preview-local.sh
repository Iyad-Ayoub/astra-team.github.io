#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"

cd "$repository_root"
rm -rf _site .jekyll-cache .sass-cache

bundle exec jekyll build

echo "Local preview: http://127.0.0.1:4000/"
exec python3 -m http.server 4000 --directory "$repository_root/_site"
