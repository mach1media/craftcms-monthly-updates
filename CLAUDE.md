# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
The Methodist Foundation (TMF) - Craft CMS 4.16.16 website with custom update automation and Bootstrap-based frontend.

## Key Commands

### Local Development
```bash
# Start DDEV environment
ddev start

# Frontend development (run from src/ directory)
cd src
npx mix watch         # Watch for changes
npx mix --production  # Build for production

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
- **CMS**: Craft CMS 4.16.16 (PHP 8.2)
- **Frontend Build**: Laravel Mix 6.x with Webpack
- **CSS**: Bootstrap 5.2.2 + custom SCSS
- **JS**: jQuery 3.6.1, AOS animations
- **Local Dev**: DDEV (MySQL 8.0)

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
└── public/dist/     # Compiled assets
```

### Template Architecture
- Base layout: `_layout/default.twig`
- Component pattern: `_components/` for reusables
- Neo blocks for flexible content
- Entry types: General pages, Impact reports, News, Portal pages

### Frontend Build Process
1. Source files in `src/` directory
2. Laravel Mix processes SCSS and JS
3. Outputs to `public/dist/`
4. Bootstrap variables customized in `src/css/config/`

### Deployment
- GitHub Actions workflow (`.github/workflows/deploy.yml`)
- Triggers on push to `production` or `staging`
- Deploys to DigitalOcean via SSH
- Runs composer install, migrations, and config apply

### Key Craft Plugins
- **Neo**: Matrix field alternative
- **Formie**: Form builder
- **SEOmatic**: SEO management
- **Redactor**: Rich text editor
- **Super Table**: Complex field tables

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