# Project Context

> This file is read by all QA personas before reviewing code. Keep it concise and current.

## Project Overview

- **Project Name**: The Methodist Foundation (TMF)
- **Craft CMS Version**: 5.x
- **PHP Version**: 8.4
- **Environment**: DDEV local / Digital Ocean production
- **Hosting**: Digital Ocean (via Ploi.io)
- **Asset Storage**: Local filesystems

## Upgrade Status

See `UPGRADE-PLAN.md` for detailed phased upgrade plan.

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Core Craft 5 + CKEditor | ✓ Complete |
| 2A | Entry Type Templates (.render()) | ✓ Complete |
| 2B | Neo Block Templates (.render()) | Skipped |
| 3 | Link Field Migration | ✓ Complete |
| 4 | Vite + Bootstrap 5.3 | ✓ Complete |
| 5 | contentBuilder + NASAA + Globals | Pending |

## Content Model

### Sections & Entry Types

> Summary extracted from `config/project/sections/` and `config/project/entryTypes/`.

```
## Content Sections (with URLs)

Section: pages (Structure)
  URI: {parent.uri}/{slug}
  Template: _sections/router.twig
  Entry Types:
    - general: Page Header (Neo), Page Builder: General (Neo), Alert Bar, Popup, SEO
    - impactReport: Impact report specific fields

Section: news (Channel)
  Entry Types:
    - news: News article fields

Section: team (Structure)
  Entry Types:
    - person: Team member fields

Section: grantRecipients (Channel)
  Entry Types:
    - grantRecipient: Grant recipient fields

Section: tables (Structure)
  Entry Types:
    - dataTable: Table data fields
    - rateTable: Rate table fields

## Singles

Section: homepage (Single)
  Template: homepage.twig
  Entry Types:
    - homepage: Homepage-specific Neo blocks

Section: portalLogin (Single)
  Entry Types:
    - portalLogin: Portal login page fields

## Utility Sections

Section: navigationMenu (Structure)
  Entry Types:
    - megaMenu: Navigation menu structure
    - link: Simple navigation link
    - dropdown: Dropdown menu item
```

### Globals

| Handle | Name | Fields |
|--------|------|--------|
| `footer` | Footer | Heading, Quote (description), Text Links (buttons), Legal Links, Description (disclaimer) |

### Neo Page Builder Fields

TMF uses Neo fields for flexible page building. Primary fields:

```
Field: Page Header (Neo)
  Blocks: hero, general, pageHeader variants

Field: Page Builder: General (Neo)
  50+ block types for flexible content
```

## Template Architecture

### Entry Type Rendering

Entry types use Craft 5's `.render()` method which auto-resolves templates at `_partials/entry/{handle}.twig`:

```twig
{# _sections/router.twig #}
{% extends "_layout/default" %}

{% block content %}
    {{ entry.render() }}
{% endblock %}
```

### Neo Block Rendering

Neo blocks use `{% include %}` with fallback chains for context-specific templates:

```twig
{% include [
    "_neoBlockTypes/" ~ block.type,
    "_neoBlockTypes/impactReport/" ~ block.type
] with { 'block': block, 'sectionStyleClasses': sectionStyleClasses } %}
```

### Directory Structure

```
templates/
├── _layout/
│   └── default.twig          # Base HTML layout
├── _sections/
│   └── router.twig           # Universal section router using .render()
├── _partials/
│   └── entry/                # Entry type templates (called via .render())
├── _neoBlockTypes/           # Neo block templates (51 block types)
│   ├── pageHeader/           # Page header variants
│   └── impactReport/         # Impact report blocks
├── _pageBuilders/            # Page builder wrappers
├── _fields/                  # Field-specific templates
├── _components/              # Reusable UI components
└── _formie/                  # Custom Formie templates
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

- **Neo** (`spicyweb/craft-neo`) — Flexible content builder
- **SEOmatic** (`nystudio107/craft-seomatic`) — SEO management
- **Formie** (`verbb/formie`) — Form builder
- **CKEditor** (`craftcms/ckeditor`) — Rich text editor
- **Super Table** (`verbb/super-table`) — Complex field tables
- **Vite** (`nystudio107/craft-vite`) — Frontend build tooling
- **Feed Me** (`craftcms/feed-me`) — Content import/export
- **Embedded Assets** (`spicyweb/craft-embedded-assets`) — oEmbed support
- **Field Manager** (`verbb/field-manager`) — Field management
- **Tablemaker** (`verbb/tablemaker`) — Table fields
- **Wordsmith** (`topshelfcraft/wordsmith`) — Text manipulation

## Frontend Stack

- **Build Tool**: Vite 5.x with `nystudio107/craft-vite`
- **CSS Framework**: Bootstrap 5.3.3
- **JavaScript**: jQuery 3.7.1
- **Animations**: AOS 2.3.4

## Known Quirks or Constraints

- **Link field handle**: Use `hyperlink` for Link fields (not `link` — reserved by Craft CMS)
- **Neo blocks are extensive**: 51 block types, templates in `_neoBlockTypes/`
- **Page Header is Neo**: Not a Content Block field; uses Neo field
- **Local assets**: Currently using local filesystems
- **Super Table queries**: Must call `.one()` before accessing properties

## Development Commands

### Local Development
```bash
ddev start                    # Start DDEV environment
npm run dev                   # Vite dev server with HMR
npm run build                 # Production build
```

### Database
```bash
ddev craft db/backup          # Backup database (use often!)
npm run sync-db               # Sync from production
npm run sync-assets           # Sync assets from production
```

### Craft Commands
```bash
ddev craft migrate/all        # Run migrations
ddev craft project-config/apply # Apply project config
ddev craft clear-caches/all   # Clear all caches
```

### Update Scripts
```bash
npm run update                # Monthly Craft CMS updates
npm run update/deploy         # Deploy to production
```
