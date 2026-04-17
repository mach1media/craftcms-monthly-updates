# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Methodist Foundation (TMF) - Craft CMS 5.x website with Neo-based page builders and Bootstrap frontend.

## Commands

```bash
# Local development
ddev start                        # Start DDEV environment
npm run dev                       # Vite dev server with HMR (from project root)
npm run build                     # Production build

# Craft CMS
ddev craft migrate/all            # Run migrations
ddev craft project-config/apply   # Apply project config
ddev craft clear-caches/all       # Clear all caches

# Sync from production
npm run sync-db                   # Sync database
npm run sync-assets               # Sync assets

# Monthly updates
npm run update                    # Run Craft CMS updates
npm run update/deploy             # Deploy to production
```

Local site: https://tmf.ddev.site

## Tech Stack

- Craft CMS 5.x (PHP 8.4, MariaDB 10.11)
- Vite 5.x + Bootstrap 5.3.3 + jQuery 3.7.1
- DDEV for local development
- Neo plugin for flexible content builders

## Template Architecture

### Entry Type Rendering

Entry types use Craft 5's `.render()` method which auto-resolves templates at `_partials/entry/{handle}.twig`:

```twig
{{ entry.render() }}
```

Entry partials follow a standard structure:
```twig
{% include "_components/alertBar" with { 'entry': entry } %}
{% include "_fields/pageHeader" with { 'entry': entry } %}
{% include "_pageBuilders/pageBuilderGeneral" with { 'entry': entry } %}
```

### Neo Block Rendering

Neo blocks use `{% include %}` with fallback arrays for context-specific templates. The page builder templates handle section styling and delegate to block templates:

```twig
{% include [
    "_neoBlockTypes/" ~ block.type,
    "_neoBlockTypes/impactReport/" ~ block.type
] with { 'block': block, 'sectionStyleClasses': sectionStyleClasses } %}
```

### Template Directory Structure

```
templates/
├── _partials/entry/     # Entry type templates (used by .render())
├── _pageBuilders/       # Page builder Neo field templates
├── _neoBlockTypes/      # Neo block templates (51 block types)
│   └── impactReport/    # Impact report-specific variants
├── _fields/             # Field-specific templates (Super Table, etc.)
├── _components/         # Reusable UI components
└── _layout/             # Base layouts
```

### Super Table Fields

Super Table fields return element queries. Call `.one()` before accessing properties:

```twig
{% set headingEntry = heading.one() | default(null) %}
{% if headingEntry %}
    {{ headingEntry.heading }}
{% endif %}
```

## Key Plugins

- **Neo**: Matrix field alternative for page builders
- **Formie**: Form builder
- **SEOmatic**: SEO management
- **CKEditor**: Rich text editing
- **Super Table**: Complex field tables
- **Vite**: Asset loading

## Deployment

GitHub Actions deploys on push to `production` or `staging` branches. Workflow at `.github/workflows/deploy.yml`.
