# P0/P1 technical foundation

## P0: publication boundary and credential response

The legacy polyfill dependency is removed; MathJax is unchanged. Jekyll excludes
development scripts, Docker/deployment utilities, docs/tests, runtime/dependency
manifests and credential-bearing server files. The artifact gate rejects these
paths, symlinks, common credential patterns and the removed script host.
Pattern scanning is a guardrail, not proof that arbitrary secrets are absent.

The avatar utility now requires `GCS_DEVELOPER_KEY` and `GCS_CX` in its process
environment. Do not put these values in tracked files or command-line arguments.
The previously embedded Google-shaped key has not been tested against Google.
It remains in Git history and may exist in prior published artifacts. Its owner
must identify the Google Cloud project, review usage/restrictions and revoke or
rotate it as appropriate, then arrange a separately authorized safe deployment.
No history rewrite, upstream write, credential rotation or deployment is part of
this patch. Existing server password material is excluded, not deleted.

## P1: preserve and validate the baseline

The Phase 10D baseline is Ruby 3.4.10, its bundled RubyGems 3.6.9 and Bundler
2.6.9. See [migration and Ubuntu setup](phase-10d-ruby-baseline.md).
`.ruby-version` is the runtime source of truth, also read by the Gemfile and CI.
The lockfile records the matching Ruby and Bundler versions. Frozen installs
retain all 90 existing application-gem versions, including Jekyll 4.4.1.
Nokogiri and google-protobuf use source variants at their existing versions;
Nokogiri's source build adds mini_portile2 2.8.9.

CI retains read-only build permissions, separate deployment permissions and
Bundler caching. No independent RubyGems downgrade is applied. The earlier
Ruby 3.0.2 / RubyGems 3.3.5 / Bundler 2.3.5 workaround for default `uri`
activation is historical, not the current setup procedure. URI remains an
unchanged transitive dependency; no direct URI dependency was added.

The legacy Docker image/package-manager mismatch is still unresolved. Docker
is not a validated Phase 10D development path; use the native setup below and
the migration guide. Existing Docker wrappers still preserve the lockfile.

Confirm `ruby --version`, `gem --version` and `bundle --version` report the
baseline above, then run from the repository root:

```sh
BUNDLE_FROZEN=true bundle install
bundle exec ruby scripts/validate_site.rb --source-only
bundle exec ruby tests/validation_test.rb
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py'
JEKYLL_ENV=production BUNDLE_FROZEN=true bundle exec jekyll build
bundle exec ruby scripts/validate_site.rb _site
```

## Local preview and CI

Use the official local preview command from any directory:

```sh
scripts/preview-local.sh
```

It resolves the repository root, performs a normal `bundle exec jekyll build`,
then serves the generated `_site` at `http://127.0.0.1:4000/`. This is the
normal development workflow: it rebuilds changed Markdown, Liquid and SCSS
without discarding generated output or caches. It does not use `jekyll serve`
and does not alter production canonical-URL behavior.

Use a full rebuild only when stale generated output is suspected:

```sh
scripts/preview-local.sh --clean
```

`--clean` removes `_site`, `.jekyll-cache` and `.sass-cache` before building.
Use `scripts/preview-local.sh --help` for the concise command summary.

GitHub Actions runs validation and root/subpath baseline builds for every push
to every branch. The HAL refresh, Pages setup, Pages artifact build and upload,
and GitHub Pages deployment remain guarded for `main` only. Manual dispatch and
the scheduled workflow remain available; feature-branch runs cannot deploy.

For a project-path build, use `jekyll build --baseurl /astra-team.github.io`
and validate with `scripts/validate_site.rb _site /astra-team.github.io`.
The existing responsive-image plugin can regenerate source-side `_responsive`
files: build in an isolated copy when checking without changing tracked media.

HAL still runs in the deployment build and keeps the existing structure query
and keyword/PDF normalization. The update now has finite retries, a timeout,
a size limit, strict BibTeX/required-field/duplicate checks, a truncation guard
at the query limit and a guard against drops exceeding 20% of current records.
Only a validated temporary file is atomically installed. Failure stops the build
and preserves the existing bibliography. Large legitimate removals need review;
do not bypass validation silently. Offline tests never update the real corpus.

Internal-link validation checks rendered href/src/srcset targets, normal HTML
fragments, root/subpath containment and the nine current HTML routes. Publication
fragments remain search terms and are intentionally exempt from element-ID checks.
External services and JavaScript-generated URLs are not checked. The existing
news-year archive links are now plain labels; no archive or route is introduced.

## Exact change inventory

P0 security/publication-boundary changes:

- `_config.yml`
- `_includes/scripts/mathjax.html`
- `scripts/avatarwrap.py`

P1 baseline, failure-handling, link and CI changes:

- `.github/workflows/jekyll.yml`
- `.gitignore`
- `.ruby-version` (new)
- `Gemfile.lock` (existing local file, newly eligible for version control; unchanged bytes)
- `_data/team.yml`
- `_includes/team/member.html`
- `_layouts/bib.html`
- `_layouts/post.html`
- `_news/2022-07-01-astra-creation.md`
- `bin/docker_build_image.sh`
- `bin/docker_run.sh`
- `bin/dockerhub_run.sh`
- `scripts/hal-export-to-bib.py`
- `scripts/publication-update.sh`
- `scripts/validate_bibliography.rb` (new)
- `tests/test_hal_update.py` (new)

P0/P1 validation and documentation:

- `scripts/validate_site.rb` (new)
- `tests/validation_test.rb` (new)
- `docs/technical-foundation.md` (new)

The CI runtime follows the pinned action's documented
[runtime and lockfile discovery](https://raw.githubusercontent.com/ruby/setup-ruby/4a9ddd6f338a97768b8006bf671dfbad383215f4/README.md).
The selected Ruby/Ubuntu combination has an existing
[Ruby builder artifact](https://github.com/ruby/ruby-builder/releases/tag/toolcache).
Hosted Actions have not been executed as part of this local patch.
