# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
The Methodist Foundation (TMF) - Craft CMS 5.9.20 website with custom update automation and Bootstrap-based frontend.

## Key Commands

### Local Development
```bash
# Start DDEV environment
ddev start

# Frontend development (run from src/ directory)
cd src
npm run dev          # Vite dev server with HMR
npm run build        # Production build

# Access local site
# URL: https://tmf.ddev.site
```

### Update & Maintenance
```bash
# Monthly Craft CMS updates
npm run update

# Sync from production
npm run sync-db      # Sync database
npm run sync-assets  # Sync assets

# Deploy to production
npm run update/deploy

# Test update scripts
npm run update/test
```

### Craft CMS Commands
```bash
# Run via DDEV
ddev craft migrate/all        # Run migrations
ddev craft project-config/apply  # Apply project config
ddev craft clear-caches/all   # Clear all caches
```

## Architecture Overview

### Tech Stack
- **CMS**: Craft CMS 5.9.20 (PHP 8.4)
- **Frontend Build**: Vite 5.x
- **CSS**: Bootstrap 5.3.3 + custom SCSS
- **JS**: jQuery 3.7.1, AOS animations
- **Local Dev**: DDEV (MariaDB 10.11)

### Directory Structure
```
├── config/           # Craft CMS configuration
├── modules/          # Custom PHP modules
├── templates/        # Twig templates (component-based)
│   ├── _components/  # Reusable components
│   ├── _fields/      # Field-specific templates
│   └── _neoBlockTypes/ # Neo block templates
├── src/             # Frontend source
│   ├── css/         # SCSS files
│   └── js/          # JavaScript
└── web/dist/        # Compiled assets
```

### Template Architecture
- Base layout: `_layout/default.twig`
- Component pattern: `_components/` for reusables
- Neo blocks for flexible content
- Entry types: General pages, Impact reports, News, Portal pages
- Uses craft-vite plugin for asset loading

### Frontend Build Process
1. Source files in `src/` directory
2. Vite processes SCSS and JS with HMR in dev
3. Production builds output to `web/dist/assets/`
4. Static assets (fonts, images) in `web/dist/`
5. Bootstrap variables customized in `src/css/config/`

### Deployment
- GitHub Actions workflow (`.github/workflows/deploy.yml`)
- Triggers on push to `production` or `staging`
- Deploys to DigitalOcean via SSH
- Runs composer install, migrations, and config apply

### Key Craft Plugins
- **Neo**: Matrix field alternative
- **Formie**: Form builder
- **SEOmatic**: SEO management
- **CKEditor**: Rich text editor
- **Super Table**: Complex field tables
- **Vite**: Asset loading for Vite builds

### Update Automation
Custom Node.js scripts in `.update/` directory handle:
- Monthly Craft CMS updates
- Production database/asset syncing
- Git branch management
- Composer dependency updates
- Automated testing of update process

### Environment Configuration
- `.env` files for environment settings
- Timezone: America/Chicago
- Multi-environment support (local/staging/production)

### Development Notes
- No formal application testing framework
- No linting configuration at project level
- jQuery-based frontend (legacy approach)
- Bootstrap components used throughout
- Custom update automation tested separately
