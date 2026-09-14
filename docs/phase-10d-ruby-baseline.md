# Phase 10D — Ruby/Bundler baseline migration

Branch: `phase-10d-ruby-baseline-migration`. Starting commit: `9f6622d`.
No content edits, commit, push, live HAL refresh or deployment are part of this
validation. GitHub Actions remains the final gate after human review and push.

## Baseline inventory and decision

Before: Ubuntu 22.04 x86_64, Ruby 3.0.2p107, RubyGems 3.3.5, Bundler 2.3.5.
The original lockfile has 90 application gems, platform `x86_64-linux`, no
`RUBY VERSION`, and `BUNDLED WITH 2.3.5`. Its full version inventory is preserved
at `git show 9f6622d:Gemfile.lock`; the sorted name/version list is independently
pinned by the new runtime regression test.

Key versions (unchanged by migration): Jekyll 4.4.1; jekyll-scholar 7.3.0;
jekyll-imagemagick 1.4.0; jekyll-responsive-magick 1.3.1;
jekyll-sass-converter 3.0.0; sass-embedded 1.69.5; google-protobuf 3.25.8;
nokogiri 1.17.2; ffi 1.17.4; eventmachine 1.2.7; http_parser.rb 0.8.1;
bigdecimal 4.1.2; date 3.5.1; json 2.21.2; racc 1.8.1; stringio 3.2.0.
The theme is repository-local al-folio-derived templates/SCSS, not a separate
theme gem. There is no `github-pages` dependency; Pages receives a custom-built
artifact. Other plugins remain exactly as locked in the baseline.

Selected: **Ruby 3.4.10, RubyGems 3.6.9, Bundler 2.6.9**. Ruby 3.4.10 is the
latest stable 3.4 patch on the official release list checked 14 September 2026.
RubyGems and Bundler are the versions shipped with that Ruby source release.
No independent RubyGems upgrade/downgrade or Bundler-major migration is needed.
`.ruby-version` is read by both Gemfile (`ruby file:`) and CI.

Bundler 2.x supports this runtime; the selected distribution already supplies
2.6.9. Bundler 4 introduces CLI/configuration behavior changes and lockfile
checksum handling; it is not needed to resolve the native-package limitation.
No gem in the locked application graph imposes a need for Bundler 4. Ruby 4
was not tested or selected because Ruby 3.4 supports the stack.

## Isolated candidate findings, before repository edits

- Ruby 3.4.10 + Bundler 2.3.5 + unchanged lock: installation fails. Its
  `GemNotFound` wording is misleading: the Linux Nokogiri package is excluded
  by its Ruby requirement, not proven removed from RubyGems.
- Ruby 3.4.10 + bundled Bundler 2.6.9 + unchanged lock: installation also fails.
- The locked Nokogiri Linux binary requires Ruby `>= 3.0, < 3.4.dev`; the
  protobuf Linux binary requires `>= 2.7, < 3.4.dev`. Both package extensions
  stop at Ruby 3.3. Neither original candidate can proceed to builds/tests.
- Ruby 3.4.10 + Bundler 2.6.9 + the same versions' source packages: fresh
  installation succeeds, native libraries load and Jekyll builds successfully.

Ruby itself was compiled from the official checksum-verified source into an
isolated `/tmp` prefix on Ubuntu 22.04; the system Ruby was not replaced.
Native gems were installed into a new Ruby-3.4-only directory, not copied from
the Ruby 3.0 installation. Compiler builds include Nokogiri, protobuf, ffi,
eventmachine, http_parser.rb, bigdecimal, date, json, racc and stringio.
The Sass extension installer also succeeds and compiled CSS is compared below.

## Minimal dependency and lockfile changes

All **90 existing application-gem version numbers are unchanged**.

- Nokogiri 1.17.2: `x86_64-linux` binary → source (`ruby`) variant.
- google-protobuf 3.25.8: `x86_64-linux` binary → source (`ruby`) variant.
- Add mini_portile2 2.8.9, required by the Nokogiri source package to build its
  bundled libraries. This is a build dependency, not a site feature.
- Gemfile explicitly pins those two existing transitive versions and uses
  `force_ruby_platform: true` only for them, not globally for every gem.
- Add platform `ruby`, retaining `x86_64-linux`; record Ruby 3.4.10p104 and
  `BUNDLED WITH 2.6.9`.

Targeted operation used in the isolated candidate:

```sh
bundle _2.6.9_ lock --bundler 2.6.9 --add-platform ruby
```

No unrestricted `bundle update` was run. There is no new direct URI dependency.

Original lock SHA-256:
`137c5ef5fad8e70bc4f9494484503f07da3313cd5aa5416bbcd5a683f5e483c6`.
Candidate lock SHA-256:
`69f2dce6e90cdb8f327cc28a62e3a964097d59d0d7433c931c99c4c2542e62d1`.
Unchanged bibliography SHA-256:
`c5f03fdefae21026eda865f99cb10d167b672d90afc082f42938e9262a01c14a`.

## Ubuntu native setup

The following source-install procedure uses a versioned user prefix, without
replacing Ubuntu's Ruby or downgrading its managed RubyGems. Run the build in a
temporary directory; run the final bundle/site commands from this repository.

```sh
sudo apt-get update
sudo apt-get install -y build-essential curl ca-certificates patch pkg-config \
  libssl-dev libyaml-dev libffi-dev libreadline-dev zlib1g-dev liblzma-dev \
  imagemagick python3
mkdir -p /tmp/astra-ruby-3.4.10-build
cd /tmp/astra-ruby-3.4.10-build
curl --fail --location --output ruby-3.4.10.tar.gz \
  https://cache.ruby-lang.org/pub/ruby/3.4/ruby-3.4.10.tar.gz
printf '%s  %s\n' \
  ecee2d072a14f2d14347dd56dfd8fe5c3130abf5117bfaacbda0f4ef9cc429ec \
  ruby-3.4.10.tar.gz | sha256sum --check -
tar -xzf ruby-3.4.10.tar.gz
cd ruby-3.4.10
./configure --prefix="$HOME/.local/opt/ruby-3.4.10" --disable-install-doc --disable-yjit
make -j4
make install
export PATH="$HOME/.local/opt/ruby-3.4.10/bin:$PATH"
```

Use Node 22 for the existing minifier/browser tooling, as CI does. On the
maintainer's existing nvm installation:

```sh
. "$HOME/.nvm/nvm.sh"
nvm install 22
nvm use 22
```

These nvm commands assume nvm is already installed; see its official installation
instructions if not. No Node version change is part of this phase: CI already
selected 22 for browser checks and now selects it before minification too.

From the repository root, in the same shell:

```sh
ruby --version      # 3.4.10
gem --version       # 3.6.9
bundle --version    # 2.6.9, supplied with Ruby
bundle config set --local path vendor/bundle
BUNDLE_FROZEN=true bundle install
bundle check
bundle exec jekyll serve --host 0.0.0.0
```

Do not copy old `vendor/bundle/ruby/3.0.0` extensions into the new ABI directory.
The existing Dockerfile still uses an unpinned Jekyll image and the known `apk`
mismatch. It remains a legacy, unsupported alternative—not the Phase 10D
baseline. Repairing that Docker path is deferred; it was not silently tested.

## CI and cache behavior

- Checkout is pinned to v7.0.1; ruby/setup-ruby to v1.321.0. Both use Node 24
  for their action code, independently of the selected Ruby runtime.
- The existing setup-node action moves to a Node-24-capable v6 revision with
  Node 22 retained and automatic package-manager caching disabled, preserving
  the previous lack of an npm cache. It now precedes minification as well.
- Keep `bundler-cache: true` and frozen installation. The Ruby version and
  lockfile change the cache key, preventing Ruby 3.0 ABI cache reuse. Native
  compiler prerequisites are explicitly installed. Normal restore/save service
  failures remain warning/fallback behavior; dependency-install errors fail.
- Preserve the self-contained root/subpath Ruby test gate from the exit-127
  hotfix. No tests are skipped to accommodate Ruby 3.4.
- Pushes to the migration branch run validation. Live HAL refresh, Pages setup,
  final deployment-artifact build/upload and deployment are restricted to main.
  Their existing main-branch behavior is unchanged. This permits CI acceptance
  without deploying a migration-branch push or fetching a new bibliography.

## Regression and output-preservation checks

The new runtime test checks Ruby/RubyGems/Bundler, all 90 original gem versions,
the one added build dependency, source variants and native-library loading.
Only the Gemfile/lockfile hashes in Phase 9's preservation test change; the
configuration, scientific and media pins remain intact.

Pre/post artifacts are compared at root and project subpath across all files,
including routes, CSS, media, sitemap, robots, legal notices and bibliography
presentation. The only permitted nondeterministic differences are the stylesheet
build-time query, Leaflet's random map/marker identifiers (with reference
consistency), their consequent minified local-variable names, and the feed's
build-time `updated` value. Map scripts are compared after deterministic,
scope-aware identifier mangling with the locked Terser and compression disabled;
they are not discarded from the comparison. Any other difference fails comparison.

Measured clean indexed-tree validation:

- Frozen install/check with the freshly built Ruby 3.4 native-gem cache: passed.
- Exact workflow root/subpath production baseline command: passed.
- Ruby suite: 45 tests, 9,250 root assertions / 9,214 subpath assertions; no
  failures, errors or skips. Python/HAL suite: 13 tests passed.
- Source, bibliography (259 entries), route/link/asset/security validation and
  Jekyll doctor: passed. All 36 HTML routes passed at both base paths.
- Phase 10 browser checks: 12 routes at five viewport widths for each base path
  (120 combinations), including consent/storage checks: passed.
- Pre/post comparison: all 495 artifact files match under the narrow
  normalization above, separately at root and subpath. Each has 37 raw
  nondeterministic differences. CSS, media, robots and sitemap are byte-identical.
- Source-preservation and whitespace checks: passed; bibliography hash unchanged.

GitHub-hosted action execution/cache behavior cannot be fully verified until an
authorized push. These local checks do not claim a completed Actions run.

## Warnings and preserved scope

`jekyll-twitter-plugin` emits a Ruby warning that `ostruct` stops being a default
gem in Ruby 4. This does not affect Ruby 3.4; no unused-feature cleanup or new
dependency was added just to silence it. Compiler warnings, if present, are not
compiler errors. Ruby's default allocator/parser and native compilation do not
authorize content, route or image-pipeline changes.

HAL scripts and fallback/retry semantics, the 259-entry bibliography, author
mappings, media, all scientific/legal text and team/project/news/output/platform
records remain byte-for-byte unchanged.

## Human review, Actions gate and rollback

After review, stage the exact files in the handoff, commit once, and push only
`phase-10d-ruby-baseline-migration` to the working fork. The push triggers the
validation-only branch workflow. Do not merge until that Actions run passes;
no local result is a claim that Actions has already passed.

Rollback is one `git revert <migration-commit>` after a migration commit exists.
It restores the original Gemfile/lockfile, Ruby 3.0.2, RubyGems 3.3.5 CI setting,
Bundler 2.3.5, native binary variants, test pins and workflow. Locally reactivate
the prior Ruby installation and run its frozen bundle install; do not reuse the
new ABI directory. No content rollback or bibliography regeneration is needed.

## Official references

- https://www.ruby-lang.org/en/downloads/releases/
- https://www.ruby-lang.org/en/news/2026/06/30/ruby-3-4-10-released/
- https://github.com/ruby/ruby/tree/v3_4_10/lib/bundler
- https://bundler.io/man/gemfile.5.html (`ruby file:` and per-gem source variants)
- https://bundler.io/man/bundle-config.1.html (major-version configuration differences)
- https://github.com/actions/checkout/releases/tag/v7.0.1
- https://github.com/ruby/setup-ruby/releases/tag/v1.321.0
- https://github.com/actions/setup-node/tree/249970729cb0ef3589644e2896645e5dc5ba9c38
- https://github.com/nvm-sh/nvm#installing-and-updating

The tested Ruby distribution's own Gemfile manual and version files were also
inspected directly; they define the selected Bundler/RubyGems behavior.
