# Boostlook CSS Workflow Documentation

This document describes the GitHub Actions workflow that synchronizes `boostlook.css` across the Boost documentation ecosystem. It covers how styling changes flow from this repository to the production websites.

## Table of Contents

- [Overview](#overview)
- [Repository Relationships](#repository-relationships)
- [Workflow Diagram](#workflow-diagram)
- [Detailed Workflow Steps](#detailed-workflow-steps)
- [Branch Strategy](#branch-strategy)
- [Manual Triggers](#manual-triggers)
- [Technical Reference](#technical-reference)
- [Troubleshooting](#troubleshooting)

---

## Overview

The boostlook repository is the **single source of truth** for Boost's documentation styling. When `boostlook.css` is modified, automated workflows propagate those changes to two downstream repositories:

1. **website-v2** - The main Boost website (Django-based)
2. **website-v2-docs** - The Antora-based documentation site

This ensures visual consistency across all Boost web properties.

---

## Repository Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BOOSTLOOK                                      │
│                    (boostorg/boostlook)                                     │
│                                                                             │
│  Source of truth for boostlook.css                                          │
│  Branch: develop                                                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ On push to develop (boostlook.css changed)
                                    │ OR manual workflow_dispatch
                                    ▼
        ┌───────────────────────────┴───────────────────────────┐
        │                                                       │
        ▼                                                       ▼
┌───────────────────────────────┐       ┌───────────────────────────────────┐
│         WEBSITE-V2            │       │         WEBSITE-V2-DOCS           │
│    (boostorg/website-v2)      │       │    (boostorg/website-v2-docs)     │
│                               │       │                                   │
│  Receives: direct file copy   │       │  Receives: workflow trigger       │
│  Location: static/css/        │       │  Process: fetches from boostlook  │
│            boostlook.css      │       │           during antora-ui build  │
│  Branch: develop              │       │  Branch: develop                  │
│                               │       │                                   │
│  Django website               │       │  Antora documentation site        │
└───────────────────────────────┘       └───────────────────────────────────┘
        │                                       │
        │ actions-gcp.yaml                      │ publish.yml
        ▼                                       ▼
┌───────────────────────────────┐       ┌───────────────────────────────────┐
│     GKE DEPLOYMENT            │       │     AWS S3 + FASTLY CDN           │
│                               │       │                                   │
│  develop → stage namespace    │       │  Documentation hosting            │
│  master → production          │       │  with CDN caching                 │
└───────────────────────────────┘       └───────────────────────────────────┘
```

---

## Workflow Diagram

### Sync Process Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. Developer pushes changes to boostlook.css on develop branch             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. sync-boostlook-css.yml workflow triggers                                │
│     - Checks out boostlook repo                                             │
│     - Checks out website-v2 repo (develop branch)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. Copy boostlook.css to website-v2/static/css/boostlook.css               │
│     - Run pre-commit hooks for validation                                   │
│     - Commit and push to website-v2 develop branch                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  4. Trigger website-v2-docs workflows:                                      │
│     - ui-release.yml: Builds new Antora UI bundle                           │
│     - publish.yml: Rebuilds and publishes documentation                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
┌───────────────────────────────┐   ┌───────────────────────────────────────┐
│  5a. website-v2 deploys       │   │  5b. website-v2-docs deploys          │
│      via actions-gcp.yaml     │   │      to AWS S3 + Fastly               │
│      to GKE stage namespace   │   │                                       │
└───────────────────────────────┘   └───────────────────────────────────────┘
```

---

## Detailed Workflow Steps

### Step 1: Trigger Conditions

The `sync-boostlook-css.yml` workflow in this repository triggers when:

| Trigger | Condition | Branch |
|---------|-----------|--------|
| Push | `boostlook.css` file is modified | `develop` |
| Manual | `workflow_dispatch` from GitHub UI | Any (runs on develop) |

**Important**: The workflow only runs when executed from the official `boostorg/boostlook` repository (fork protection).

### Step 2: CSS Synchronization to website-v2

The workflow performs these actions:

1. **Checkout repositories**
   - Checks out boostlook (current repo)
   - Checks out `boostorg/website-v2` (develop branch) into `website-v2/` subdirectory

2. **Copy CSS file**
   ```
   boostlook.css → website-v2/static/css/boostlook.css
   ```

3. **Validation**
   - Installs pre-commit
   - Runs pre-commit hooks on the copied CSS file

4. **Commit and push**
   - Commits with message: `chore: Update boostlook.css from boostlook repository`
   - Pushes to website-v2's develop branch
   - Skips if no changes detected

### Step 3: Trigger website-v2-docs Workflows

After successfully updating website-v2, the workflow triggers two workflows in `boostorg/website-v2-docs`:

#### ui-release.yml

Builds the Antora UI bundle:

1. Sets up Node.js 18.x
2. Runs `npm ci` and `gulp bundle` in the `antora-ui` directory
3. The gulp build process **fetches boostlook.css** from this repository:
   ```
   https://raw.githubusercontent.com/boostorg/boostlook/${BOOSTLOOK_BRANCH}/boostlook.css
   ```
4. Creates a GitHub release tagged `ui-{branch-name}` with `ui-bundle.zip`

**Note**: The `BOOSTLOOK_BRANCH` environment variable determines which branch to fetch from. In CI, this defaults to `develop` unless the current branch is `master`.

#### publish.yml

Builds and deploys the documentation:

1. Runs `build.sh` to generate documentation
2. Syncs to AWS S3 (multiple environments)
3. Purges Fastly CDN cache

### Step 4: Downstream Deployments

#### website-v2 Deployment

The `actions-gcp.yaml` workflow in website-v2 handles deployment:

| Branch | Deployment Target |
|--------|-------------------|
| `develop` | GKE `stage` namespace |
| `master` | GKE `production` namespace |

#### website-v2-docs Deployment

The `publish.yml` workflow deploys to:
- AWS S3 buckets (multiple environments)
- Fastly CDN with cache purging

---

## Branch Strategy

### Current Configuration

| Repository | Development Branch | Production Branch |
|------------|-------------------|-------------------|
| boostlook | `develop` | `master` |
| website-v2 | `develop` | `master` |
| website-v2-docs | `develop` | `master` |

### How Changes Flow

```
boostlook (develop) ──► website-v2 (develop) ──► Stage deployment
                   └──► website-v2-docs (develop) ──► Stage documentation

boostlook (master) ──► Manual process or separate workflow for production
```

**Current Behavior**: The automated sync workflow only operates on the `develop` branch. Production deployments follow a separate process (typically merging develop to master).

### Recommended Workflow

1. Make CSS changes in boostlook on `develop` branch
2. Changes automatically sync to staging environments
3. Test changes on staging
4. Merge `develop` to `master` in all three repos for production

---

## Manual Triggers

### Triggering the Sync Workflow Manually

1. Go to **Actions** tab in the boostlook repository
2. Select **"Sync boostlook.css to website-v2 & website-v2-docs"**
3. Click **"Run workflow"**
4. Select the branch (typically `develop`)
5. Click **"Run workflow"**

### When to Use Manual Triggers

- After fixing a failed automatic sync
- To force a refresh without changing the CSS
- Testing workflow changes
- Recovering from sync issues

---

## Technical Reference

### Files Involved

| Repository | File | Purpose |
|------------|------|---------|
| boostlook | `.github/workflows/sync-boostlook-css.yml` | Main sync workflow |
| boostlook | `boostlook.css` | Source stylesheet |
| website-v2 | `static/css/boostlook.css` | Destination (Django static) |
| website-v2 | `.github/workflows/actions-gcp.yaml` | GKE deployment |
| website-v2-docs | `.github/workflows/ui-release.yml` | Antora UI bundle build |
| website-v2-docs | `.github/workflows/publish.yml` | Documentation publish |
| website-v2-docs | `antora-ui/gulp.d/tasks/build.js` | Fetches boostlook.css |

### Required Secrets

The sync workflow requires these GitHub secrets:

| Secret | Purpose |
|--------|---------|
| `WEBSITE_V2_PAT` | Personal Access Token with write access to website-v2 and website-v2-docs repositories |

### Environment Variables

| Variable | Used In | Default | Purpose |
|----------|---------|---------|---------|
| `BOOSTLOOK_BRANCH` | website-v2-docs | `master` (CI: `develop`) | Branch to fetch boostlook.css from |

### API Endpoints

The antora-ui build fetches boostlook.css from:
```
https://raw.githubusercontent.com/boostorg/boostlook/${BOOSTLOOK_BRANCH}/boostlook.css
```

---

## Troubleshooting

### Common Issues

#### Sync workflow failed at "Commit and push"

**Cause**: The `WEBSITE_V2_PAT` token may have expired or lack permissions.

**Solution**:
1. Generate a new PAT with `repo` scope
2. Update the `WEBSITE_V2_PAT` secret in boostlook repository settings

#### Changes not appearing on staging

**Possible causes**:
1. Workflow failed silently
2. CDN cache not purged
3. Downstream workflow failed

**Solution**:
1. Check Actions tab in all three repositories
2. Manually trigger CDN purge
3. Re-run failed workflows

#### website-v2-docs showing old styles

**Cause**: The antora-ui build may be using cached boostlook.css.

**Solution**:
1. Check the `BOOSTLOOK_BRANCH` variable
2. Manually trigger ui-release.yml with `--skip-boostlook` disabled
3. Verify the CSS URL is accessible

#### Pre-commit hooks failing

**Cause**: CSS formatting issues.

**Solution**:
1. Run pre-commit locally: `pre-commit run --files boostlook.css`
2. Fix any reported issues
3. Push the corrected file

### Verification Steps

After making changes, verify the sync worked:

1. **Check workflow status**: Actions tab in boostlook repo
2. **Verify website-v2 commit**: Check recent commits on develop branch
3. **Check ui-release.yml**: Actions tab in website-v2-docs
4. **Check publish.yml**: Actions tab in website-v2-docs
5. **Test staging sites**: Verify CSS changes are visible

### Logs and Debugging

Each workflow step outputs logs accessible from the Actions tab. Key logs to check:

- `Copy boostlook.css to website-v2` - Confirms file was copied
- `Commit and push changes` - Shows if changes were detected
- `Trigger website-v2-docs ui-release workflow` - Confirms downstream trigger

---

## Additional Resources

- [website-v2-operations Deployments](https://github.com/cppalliance/website-v2-operations/tree/master/deployments) - Infrastructure documentation
- [Antora UI README](https://github.com/boostorg/website-v2-docs/tree/develop/antora-ui) - UI bundle documentation
- [Boost.Build Documentation](https://boostorg.github.io/build/) - For local preview setup

---

*Last updated: January 2025*
