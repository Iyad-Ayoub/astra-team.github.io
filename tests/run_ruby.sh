#!/usr/bin/env bash
# Run every source/artifact regression against an already generated build.
set -euo pipefail
destination="${1:?Pass the absolute build destination}"
baseurl="${2-}"
for phase in 5 6 7 8 9 10; do
  export "PHASE${phase}_SITE=$destination" "PHASE${phase}_BASEURL=$baseurl"
done
export PRE10_SITE="$destination" PRE10_BASEURL="$baseurl"
for test in tests/*_test.rb; do bundle exec ruby "$test"; done
bundle exec ruby scripts/validate_site.rb "$destination" "$baseurl"
