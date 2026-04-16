# Project Context

> This file is read by all QA personas before reviewing code. Keep it concise and current.

## Project Overview

- **Project Name**: The Methodist Foundation (TMF)
- **Craft CMS Version**: 4.17.12 (upgrading to 5.x)
- **PHP Version**: 8.2
- **Environment**: DDEV local / Digital Ocean production
- **Hosting**: Digital Ocean (via Ploi.io)
- **Asset Storage**: Local filesystems (migrating to DO Spaces bucket `tmf`)

## Upgrade Status

See `UPGRADE-PLAN.md` for detailed phased upgrade plan.

**Current Phase**: Pre-upgrade
**Target State**: Craft 5.x with Vite, contentBuilder Matrix field, NASAA integration

### Section Migration Plan
- Rename `pages` → `pagesNeo`
- Rename entry type `general` → `pagesNeoGeneral`
- Rename entry type `impactReport` → `pagesNeoImpactReport`
- Create new `pages` section with `pagesGeneral` entry type using `contentBuilder` field

## Content Model

### Sections & Entry Types

> Summary extracted from `config/project/sections/` and `config/project/entryTypes/`.
> Last updated: 2026-04-16

```
## Content Sections (with URLs)

Section: pages (Structure)
  URI: {parent.uri}/{slug}
  Template: _sections/pages.twig
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

### Neo Block Types (50+)

Templates located in `templates/_neoBlockTypes/`:

**Content Blocks:**
- `accordion` - Expandable FAQ/accordion sections
- `basic` - Basic text content
- `blockquote` - Pull quotes
- `buttonBlock` - CTA buttons
- `columns` - Multi-column layouts
- `embedCode` - Third-party embed codes
- `faqs` - FAQ sections
- `form` - Form embeds
- `leadBlock` - Lead/intro text blocks
- `listBlock` - Bulleted/numbered lists
- `textFiguresInGutter` - Text with sidebar figures

**Media Blocks:**
- `hero` - Hero sections
- `media` - Generic media block
- `mosaic` - Image mosaic/gallery
- `videoEmbeds` - Video embeds
- `videoTextBlock` - Video with text
- `imgTextBlock` - Image with text
- `imgTextBox` - Image text box variant
- `split` - Split layout

**CTA Blocks:**
- `ctaBlock` - Call to action
- `ctaGeneral` - General CTA
- `ctaPanels` - CTA panels
- `ctaTiles` - CTA tile grid (Large, Medium, Small variants)
- `headingButtonBar` - Heading with buttons

**Card/Grid Blocks:**
- `iconCards` - Icon card grid
- `iconList` - Icon list
- `imageCards` - Image card grid
- `menuCards` - Menu/navigation cards
- `pressCards` - Press/news cards
- `resourceCards` - Resource card grid
- `grantRecipientCards` - Grant recipient cards

**Data Blocks:**
- `dataTable` - Data tables
- `dataTableBlock` - Data table wrapper
- `dataTableFullWidth` - Full-width data table

**People/Team Blocks:**
- `teamMembers` - Team member grid
- `headshotListings` - Headshot listings
- `sliderBoardMembers` - Board member carousel

**Interactive Blocks:**
- `contactFormBlock` - Contact forms
- `newsletterSubscribe` - Newsletter signup
- `mailchimpOptinValidator` - Mailchimp opt-in
- `optInForm` - Generic opt-in form

**Specialty Blocks:**
- `events` - Event listings
- `mediaNewsStory` - News story media
- `podcastEpisode` - Podcast episodes

**Page Headers (in `_neoBlockTypes/pageHeader/`):**
- Various page header variants

**Impact Reports (in `_neoBlockTypes/impactReport/`):**
- Impact report specific blocks

## Template Architecture

### Directory Structure

```
templates/
├── _layout/
│   └── default.twig          # Base HTML layout
├── _sections/
│   └── pages.twig            # Pages section router
├── _neoBlockTypes/           # Neo block templates (50+)
│   ├── accordion.twig
│   ├── hero.twig
│   ├── pageHeader/           # Page header variants
│   ├── impactReport/         # Impact report blocks
│   └── {blockHandle}.twig
├── _entryTypes/              # Entry type templates
├── _fields/                  # Field-specific templates
├── _components/              # Reusable UI components
├── _pageBuilders/            # Page builder wrappers
├── _formie/                  # Custom Formie templates
├── news/                     # News section templates
├── dev/                      # Development/testing templates
├── homepage.twig             # Homepage template
└── index.twig                # Default index
```

### Current Rendering Pattern

Neo blocks are rendered via includes:

```twig
{# Current pattern in page builders #}
{% for block in entry.pageBuilder.all() %}
    {% include '_neoBlockTypes/' ~ block.type.handle ~ '.twig' %}
{% endfor %}
```

### Target Rendering Pattern (Post-Upgrade)

Matrix blocks will use `.render()` method:

```twig
{# Target pattern for contentBuilder #}
{% for block in entry.contentBuilder.all() %}
    {{ block.render({
        sectionSettings: block.sectionSettings
    }) }}
{% endfor %}
```

This delegates to `_partials/entry/{entryTypeHandle}.twig`.

## Key Plugins

### Current (Craft 4)
- **Redactor** (`craftcms/redactor`) — Rich text editor (migrating to CKEditor)
- **Neo** (`spicyweb/craft-neo`) — Flexible content builder
- **SEOmatic** (`nystudio107/craft-seomatic`) — SEO management
- **Formie** (`verbb/formie`) — Form builder
- **Super Table** (`verbb/super-table`) — Complex field tables
- **Link Field** (`sebastianlenz/linkfield`) — Link field (migrating to first-party)
- **Feed Me** (`craftcms/feed-me`) — Content import/export
- **Embedded Assets** (`spicyweb/craft-embedded-assets`) — oEmbed support
- **Field Manager** (`verbb/field-manager`) — Field management
- **Tablemaker** (`verbb/tablemaker`) — Table fields
- **Wordsmith** (`topshelfcraft/wordsmith`) — Text manipulation
- **CP Field Inspect** (`mmikkel/cp-field-inspect`) — Development helper
- **Obfuscator** (`miranj/craft-obfuscator`) — Email obfuscation
- **Config Values** (`statikbe/craft-config-values`) — Config value fields
- **Mailgun** (`craftcms/mailgun`) — Email transport

### Post-Upgrade (Craft 5)
- **CKEditor** (`craftcms/ckeditor`) — Replaces Redactor
- **Vite** (`nystudio107/craft-vite`) — Frontend build tooling
- First-party **Link** field — Replaces sebastianlenz/linkfield

### Removed in Upgrade
- `dolphiq/redirect` — No longer needed
- `hybridinteractive/craft-position-fieldtype` — Replaced with Dropdown
- `verbb/redactor-tweaks` — Not needed with CKEditor

## Asset Handling

### Current (Local Filesystems)
```yaml
images:
  type: craft\fs\Local
  path: '@webroot/uploads/images'
  url: /uploads/images/

documents:
  type: craft\fs\Local
  path: '@webroot/uploads/docs'
  url: /uploads/docs/

transforms:
  type: craft\fs\Local
  path: '@webroot/uploads/transforms'
  url: /uploads/transforms/

videos:
  type: craft\fs\Local
  path: '@webroot/uploads/videos'
```

### Target (DO Spaces)
Bucket: `tmf`
Folders: `database`, `documents`, `images`, `transforms`, `nasaa`, `videos`

```yaml
images:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: images
  url: $DO_SPACES_CDN

documents:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: documents
  url: $DO_SPACES_CDN

nasaa:
  type: vaersaagod\dospaces\Fs
  settings:
    bucket: tmf
    subfolder: nasaa
  url: $DO_SPACES_CDN
```

## Frontend Stack

### Current
- **Build Tool**: Laravel Mix 6.x (Webpack)
- **CSS Framework**: Bootstrap 5.2.2
- **JavaScript**: jQuery 3.6.1
- **Animations**: AOS 2.3.4
- **Navigation**: hc-offcanvas-nav 6.1.5

### Target (Post-Upgrade)
- **Build Tool**: Vite 7.x
- **CSS Framework**: Bootstrap 5.3.3
- **JavaScript**: jQuery 3.6.1 (retained)
- **Additional Libraries**:
  - `@accessible360/accessible-slick` — Accessible carousel
  - `@lottiefiles/dotlottie-web` — Lottie animations
  - `@vimeo/player` — Vimeo API
  - `youtube-player` — YouTube API
  - `bootstrap-icons` — Icon library

## Known Quirks or Constraints

- **Link field handle**: Use `hyperlink` for Link fields (not `link` — reserved by Craft CMS)
- **Neo blocks are extensive**: 50+ block types, templates in `_neoBlockTypes/`
- **Page Header is Neo**: Not a Content Block field; uses Neo field
- **Local assets**: Currently using local filesystems, migrating to DO Spaces
- **Redactor content**: Will be migrated to CKEditor during Craft 5 upgrade
- **Link field data**: `sebastianlenz/linkfield` data requires careful migration to first-party Link field

## NASAA Integration (Phase 5)

NASAA (North American Securities Administrators Association) functionality will be imported from wesleyanimpactpartners project:

- **NASAA Volume**: DO Spaces filesystem for NASAA documents
- **NASAA Fields**: Download releases, Rate table releases
- **NASAA Global**: Settings for NASAA content management

## Development Commands

### Local Development
```bash
ddev start                    # Start DDEV environment
cd src && npx mix watch       # Watch for frontend changes
cd src && npx mix --production # Build for production
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
npm run update/test           # Test update scripts
```
