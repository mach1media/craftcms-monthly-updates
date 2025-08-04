# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a collection of helper scripts designed to automate monthly updates for Craft CMS projects hosted on various providers (ServerPilot, Ploi, Forge, fortrabbit, etc.).

## Key Commands

### Initial Setup
```bash
# Interactive setup wizard (recommended)
npm run update/setup

# Test SSH connection to production
npm run update/test-ssh
```

### Update Workflow
```bash
# Run complete update workflow
npm run update

# Individual operations
npm run sync-db        # Sync database from production
npm run sync-assets    # Sync assets from production  
npm run update/deploy  # Deploy to production
```

### Build Commands
```bash
npm run build/watch    # Watch and compile frontend assets
npm run build/css      # Compile CSS only
npm run build/js       # Compile JavaScript only
```

### Troubleshooting
```bash
npm run update/logs    # View recent update logs
```

## Project Architecture

### Update Script System
The project uses a modular shell script architecture:

- **Main orchestrator**: `.update/update.sh` - Controls the entire update workflow
- **Database sync**: `.update/scripts/sync-db.sh` - Handles automated SSH-based database backup and import with multiple authentication methods
- **Asset sync**: `.update/scripts/sync-assets.sh` - Manages FTP-based asset synchronization
- **Deployment**: `.update/scripts/deploy.sh` - Handles deployment via Ploi API, GitHub Actions, or manual methods
- **Helper functions**: `.update/scripts/helpers.sh` - Shared utilities for config parsing and logging
- **Interactive setup**: `.update/scripts/interactive-setup.sh` - Wizard for initial configuration

### Configuration Management
- Configuration stored in `.update/config.yml` (gitignored)
- Template available at `.update/config.yml.example`
- Supports multiple hosting providers with automated path detection
- Sensitive credentials can be stored or prompted at runtime

### SSH Authentication Flow
The database sync script attempts authentication in this order:
1. SSH key authentication (searches for multiple key types)
2. SSH password authentication (using sshpass if available)
3. Manual fallback with instructions

### Update Process Flow
1. Pull latest code from git
2. Sync database from production (automated or manual)
3. Sync assets via FTP
4. Create update branch (`update/YYYY-MM-DD`)
5. Update Composer dependencies
6. Run Craft migrations
7. Pause for local verification
8. Options: rollback, merge and deploy, merge only, or exit

## Important Notes

- All npm scripts should be run from the project root directory
- The scripts handle PHP deprecation errors when running Craft commands
- Logs are stored in `.update/logs/` with timestamps
- SSH operations include progress indicators and error handling
- FTP sync excludes directories starting with underscore (_) to avoid auto-generated thumbnails
- Deployment methods vary by hosting provider and are configured during setup

## Dependencies

Required for full functionality:
- `sshpass` - For SSH password authentication (optional)
- `lftp` - For FTP asset synchronization
- `ddev` - For local development environment
- PHP CLI on remote server for Craft console commands

## Security Considerations

- Never commit `config.yml` with passwords or API tokens
- SSH keys are preferred over password authentication
- All sensitive values are optional in config (will prompt if missing)
- Use `chmod 600 .update/config.yml` for sensitive configurations