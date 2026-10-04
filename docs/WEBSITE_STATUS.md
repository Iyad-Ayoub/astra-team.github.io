# ASTRA Website Status

**Baseline:** 4 October 2026
**Repository:** `Iyad-Ayoub/astra-team.github.io`
**Deployment:** Jekyll on GitHub Pages
**CI:** main validation and deployment workflow is green for the accepted baseline.

## Completed public site

- Home, Research, Projects, Platforms, Team/People, Publications/Outputs, and News.
- Four canonical Research Axes with final metadata, 2×2 overview cards, responsive individual figures, and regression protection.
- Five current real projects: Shift2SDV, TIRREX, GAT, SIGHT, and SAMBA.
- Seven validated platform records with declared media and capabilities.
- Current/alumni People separation with validated profile media.
- HAL-backed Publications with scheduled refresh; the validated artifact contains 259 publication records.

## CMS

News CMS is implemented and protected by its regression suite.

Project CMS lifecycle is verified end to end:

`create/save → publish → update → cover image → deployment → unpublish → retained draft`

`TEST-HDMap` was an intentional temporary validation project and is not public.

Current CMS authentication is:

`GitHub OAuth → authenticated GitHub user token → repository access verification → repository mutation`

CMS editors therefore currently need GitHub repository write access. This is acceptable for the small trusted editor group, but it is not the desired final ASTRA role model.

## Validation coverage

The accepted state is covered by source validation, root/subpath CI builds, generated-artifact checks, Research/News/Project regression suites, deployment checks, and forbidden-file/security validation.
