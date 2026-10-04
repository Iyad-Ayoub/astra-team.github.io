# ASTRA Deployment Handoff

This checklist prepares the next-week move or redeployment to the official ASTRA GitHub destination. Do not perform the migration as part of this document.

## Before migration

- Confirm the official destination organization and repository, owner/admin, Pages source, and any custom domain.
- Capture the current `main` SHA and release baseline; preserve the current repository and history.
- Inventory repository variables/secrets, Cloudflare Worker configuration, OAuth callback URLs, HAL schedule/workflow, and branch protection.

## Safe migration strategy

- Add the official destination as a separate remote.
- Compare its history and content with the validated repository.
- Prefer repository transfer or a controlled history-preserving mirror; avoid destructive replacement until both sides are verified.
- Update repository identifiers, URLs, `url`/`baseurl`, Pages settings, and OAuth callbacks only after the destination is confirmed.
- Run CI before switching public traffic and validate root, project-subpath, and any confirmed custom-domain behavior.
- Keep the current repository and deployment available as rollback during the transition.

## Post-migration validation

Check Home, Research, Projects, Platforms, Team, Publications, News, News CMS, Project CMS, OAuth login, publish/update/unpublish, HAL refresh, GitHub Pages deployment, and mobile smoke views.

## Rollback

Do not delete or disable the known-good deployment until the official repository deployment has passed the full validation checklist. If it fails, restore the known-good repository/deployment and investigate the destination separately.
