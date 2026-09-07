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

`.ruby-version` records the tested Ruby 3.0.2 runtime. The existing Gemfile.lock
is preserved byte-for-byte (Bundler 2.3.5, Jekyll 4.4.1). CI reads that runtime,
uses frozen dependency installation and separates read-only build permissions
from Pages deployment permissions. This preserves a legacy baseline; it is not
a claim that the old Ruby runtime is supported. A runtime upgrade is separate work.
The known Docker image/package-manager mismatch remains; Docker wrappers no
longer delete the lockfile. Use the tested native Ruby path for this baseline.

Run from the repository root:

```sh
BUNDLE_FROZEN=true bundle install
bundle exec ruby scripts/validate_site.rb --source-only
bundle exec ruby tests/validation_test.rb
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py'
JEKYLL_ENV=production BUNDLE_FROZEN=true bundle exec jekyll build
bundle exec ruby scripts/validate_site.rb _site
```

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
