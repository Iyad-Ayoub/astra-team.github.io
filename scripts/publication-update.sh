#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if python3 "$script_dir/hal-export-to-bib.py"; then
  exit 0
else
  status=$?
fi

# Exit 75 is reserved by the fetcher for exhausted remote/network failures.
# Do not permit deployment with a missing or invalid fallback bibliography.
if [[ "$status" -eq 75 ]]; then
  if bundle exec ruby "$script_dir/validate_bibliography.rb" \
      "$script_dir/../_bibliography/rits-astra.bib"; then
    echo 'WARNING: HAL remote/network update unavailable; reusing the existing validated bibliography unchanged.' >&2
    exit 0
  fi
  echo 'ERROR: HAL unavailable and existing bibliography failed validation; update aborted.' >&2
  exit 1
fi

echo 'ERROR: HAL publication pipeline failed; existing bibliography was not replaced.' >&2
exit "$status"
