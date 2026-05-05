# Craft CMS Update Scripts

Automated update workflow for monthly Craft CMS maintenance with SSH-based database sync and asset sync. Supports multiple environments (staging, production) with intelligent branch detection.

## Installation

### Method 1: Git Subtree (Recommended)

Git subtree allows you to include this repository as a subdirectory while keeping the ability to pull future updates.

**Initial setup for a new project:**
```bash
# From your project root directory
cd /path/to/your-craft-project

# Add the remote (one-time setup)
git remote add craftcms-updates git@github.com:mach1media/craftcms-monthly-updates.git

# Add the subtree
git subtree add --prefix=.update craftcms-updates main --squash

# Run interactive setup
.update/scripts/interactive-setup.sh
```

**Pulling updates from the upstream repository:**
```bash
# From your project root
git subtree pull --prefix=.update craftcms-updates main --squash
```

### Method 2: Direct Copy (Simple)

If you don't need to pull updates, you can copy the files directly:

```bash
# Clone the repo temporarily
git clone git@github.com:mach1media/craftcms-monthly-updates.git /tmp/craftcms-updates

# Copy to your project
cp -r /tmp/craftcms-updates/.update /path/to/your-craft-project/

# Clean up
rm -rf /tmp/craftcms-updates

# Run setup
cd /path/to/your-craft-project
.update/scripts/interactive-setup.sh
```

## Migrating Existing Installations

### Migrating to Git Subtree

If you previously installed these scripts using Method 2 (direct copy) and want to migrate to git subtree for easier updates:

```bash
cd /path/to/your-craft-project

# 1. Backup your current config(s)
cp .update/config.yml /tmp/config.yml.backup 2>/dev/null
cp .update/config.staging.yml /tmp/config.staging.yml.backup 2>/dev/null
cp .update/config.production.yml /tmp/config.production.yml.backup 2>/dev/null

# 2. Remove the existing .update directory from git tracking
git rm -r --cached .update
rm -rf .update

# 3. Commit the removal
git commit -m "Remove .update directory for subtree migration"

# 4. Add the remote
git remote add craftcms-updates git@github.com:mach1media/craftcms-monthly-updates.git

# 5. Add as subtree
git subtree add --prefix=.update craftcms-updates main --squash

# 6. Restore your config(s)
cp /tmp/config.staging.yml.backup .update/config.staging.yml 2>/dev/null
cp /tmp/config.production.yml.backup .update/config.production.yml 2>/dev/null

# 7. Commit the restored configs
git add .update/config.*.yml
git commit -m "Restore config files after subtree migration"
```

### Migrating to Multi-Environment Config

If you have an existing `config.yml` and want to migrate to environment-specific config files:

```bash
# Option 1: Re-run interactive setup (recommended)
npm run update/setup

# Option 2: Manually copy and rename
cp .update/config.yml .update/config.production.yml
# Edit config.production.yml and add: environment: production

# For staging, copy the production config and modify:
cp .update/config.production.yml .update/config.staging.yml
# Edit config.staging.yml with staging-specific values

# Remove the legacy config
rm .update/config.yml
```

## Quick Start

**Using npm (recommended):**
```bash
# From project root - run complete update workflow
npm run update

# Sync database (auto-detects environment from current branch)
npm run sync-db

# Or specify environment explicitly:
npm run sync-db -- --staging
npm run sync-db -- --production
npm run sync-db -- --env=staging

# Sync assets
npm run sync-assets -- --production

# Deploy to an environment
npm run update/deploy -- --staging
```

**Direct script execution:**
```bash
# From project root
.update/update.sh
```

## Multi-Environment Support

These scripts support multiple environments (staging, production) with separate configurations for each. The system intelligently detects which environment to target based on your current git branch.

### Environment Detection

Scripts automatically detect the target environment:

| Current Branch | Target Environment |
|---------------|-------------------|
| `staging` | Staging |
| `production` | Production |
| `main` or `master` (no production branch exists) | Production |
| `main` or `master` (production branch exists) | Prompts for selection |
| Feature branches (e.g., `feature/new-login`) | Prompts for selection |

### Explicit Environment Selection

You can always override automatic detection:

```bash
# Long form
npm run sync-db -- --env=staging
npm run sync-db -- --env=production

# Short form
npm run sync-db -- --staging
npm run sync-db -- --production
```

### Configuration Files

Each environment has its own configuration file:

- `.update/config.staging.yml` - Staging environment settings
- `.update/config.production.yml` - Production environment settings

The interactive setup wizard (`npm run update/setup`) allows you to configure one or both environments.

### Database Sync Direction

**Important**: Database sync is always **downstream only** (remote → local). This means:
- You can sync from staging to your local DDEV environment
- You can sync from production to your local DDEV environment
- You **cannot** push your local database to staging or production

This prevents accidental data loss on remote environments.

## Initial Setup

**Using npm (recommended):**
```bash
# 1. Run interactive setup wizard
npm run update/setup

# The wizard will:
# - Ask which environment(s) to configure (staging, production, or both)
# - Ask about your hosting provider (Cloudways, Ploi, Forge, etc.)
# - Configure paths based on your provider
# - Set up SSH and deployment settings
# - Create config.staging.yml and/or config.production.yml

# 2. Test SSH connection
npm run update/test-ssh -- --staging
npm run update/test-ssh -- --production

# 3. You're ready to run updates!
npm run update
```

**Manual setup:**
```bash
# 1. Copy config templates
cp .update/config.production.yml.example .update/config.production.yml
cp .update/config.staging.yml.example .update/config.staging.yml

# 2. Edit config files with your project details

# 3. Make scripts executable
chmod +x .update/update.sh .update/scripts/*.sh

# 4. Install optional dependencies
brew install sshpass  # For SSH password auth
brew install lftp     # For FTP asset sync

# 5. Verify SSH access
ssh username@your-server.com
```

## Supported Hosting Providers

The interactive setup wizard (`npm run update/setup`) automatically configures paths for:

### ServerPilot
- Remote path: `/srv/users/serverpilot/apps/APP_NAME`
- Public directory: `public` or `web` (configurable)
- SSH user: `serverpilot`
- Deployment: Manual

### Ploi
- Remote path: `/home/ploi/DOMAIN`
- Public directory: `public` or `web` (configurable)
- SSH user: `ploi`
- Deployment: Ploi API (requires server ID, site ID, and API token)

### Laravel Forge
- Remote path: `/home/forge/DOMAIN`
- Public directory: `web`
- SSH user: `forge`
- Deployment options:
  - Envoyer (webhook URL)
  - Forge deployment (webhook URL)
  - Manual

### fortrabbit
- Remote path: `/srv/app/APP_NAME`
- Public directory: `web`
- SSH user: `APP_NAME`
- Deployment: Push to deploy (auto-deploys on git push)

### Cloudways
- Remote path: `applications/APP_NAME/public_html`
- Public directory: `web` (configurable)
- SSH user: `master_xxxxxxxx` (from Application Settings > Access Details)
- Deployment options:
  - Cloudways SSH deployment (git pull, composer, craft commands via SSH)
  - Push to deploy via Git (configure in Cloudways dashboard)

### Other/Custom
- Prompts for all paths and settings
- Supports push to deploy, manual, or custom deployment

## Configuration

The setup wizard creates environment-specific config files automatically. You can also edit them manually:

### Environment-Specific Config Files

**config.production.yml:**
```yaml
# Environment identifier (do not change)
environment: production

# Git settings
branch: main                           # or 'production' if you use that branch

# Site URL
site_url: https://example.com

# SSH settings
ssh_host: example.com
ssh_user: username
ssh_port: 22
remote_project_dir: /var/www/html

# Shared directory paths
backup_dir: storage/backups
uploads_dir: web/uploads

# Asset storage: local, s3, spaces, other
asset_storage_type: local

# Remote uploads path (for local storage)
remote_uploads_dir: /var/www/html/web/uploads

# FTP/SSH settings for file operations
ftp_host: example.com
ftp_user: username
ftp_password:                          # Leave empty if using SSH keys

# Deployment method: push-to-deploy, cloudways, ploi, envoyer, forge, manual
deployment_method: push-to-deploy

# Build settings
run_npm_build: false
npm_build_command: npm run build
```

**config.staging.yml:**
```yaml
# Environment identifier (do not change)
environment: staging

# Git settings
branch: staging

# Site URL
site_url: https://staging.example.com

# SSH settings (may be same or different server)
ssh_host: staging.example.com
ssh_user: username
ssh_port: 22
remote_project_dir: /var/www/staging

# ... rest of settings follow same structure
```

### Deployment-Specific Settings

```yaml
# Ploi settings (if using Ploi)
ploi_server_id: 12345
ploi_site_id: 67890
ploi_api_token:                        # Optional - will prompt if empty

# Envoyer settings (if using Forge/Envoyer)
envoyer_url: https://envoyer.io/deploy/PROJECT/HASH

# Forge settings (if using Forge)
forge_url: https://forge.laravel.com/servers/.../deploy/http?token=HASH
```

## Available npm Commands

All commands should be run from the project root directory:

### Main Commands
- `npm run update` - Run complete update workflow
- `npm run sync-db` - Sync database from remote (auto-detects environment)
- `npm run sync-assets` - Sync assets from remote (auto-detects environment)
- `npm run update/deploy` - Deploy to remote (auto-detects environment)

### Environment-Specific Usage
```bash
# All commands accept environment flags:
npm run sync-db -- --staging
npm run sync-db -- --production
npm run sync-db -- --env=staging

npm run sync-assets -- --staging
npm run update/deploy -- --production
npm run update/test-ssh -- --staging
```

### Setup & Testing Commands
- `npm run update/setup` - Interactive setup wizard (configure one or both environments)
- `npm run update/test-ssh` - Test SSH connection (use with environment flag)
- `npm run update/logs` - View recent update logs

## Update Process

The main update script (`npm run update`) performs these steps:

1. **Pull** latest code from git
2. **Sync database** from selected environment (automated via SSH or manual fallback)
3. **Sync** assets from selected environment via FTP
4. **Create** update branch (`update/YYYY-MM-DD`)
5. **Update** Composer dependencies
6. **Run** Craft migrations
7. **Pause** for local site verification

Then you choose:
- **Option 1**: Start over (rollback)
- **Option 2**: Merge and deploy
- **Option 3**: Merge without deploying
- **Option 4**: Exit (stay on update branch)

## Database Sync Methods

### Automated SSH Sync (Preferred)
The script automatically tries SSH authentication in this order:

1. **SSH Key Authentication**
   - Automatically searches for SSH keys in `~/.ssh/`:
     - `serverpilot` (ServerPilot hosting)
     - `id_rsa` (RSA key)
     - `id_ed25519` (Ed25519 key)
   - Tests connection before attempting backup
   - Most secure and reliable method

2. **SSH Password Authentication**
   - Uses `ftp_password` from config.{env}.yml
   - Requires `sshpass` utility: `brew install sshpass`
   - Prompts for password if not in config
   - Password is reused for SCP download

3. **Manual Fallback**
   - Activates if all SSH methods fail
   - Provides step-by-step manual instructions

### Automated Process Flow
When SSH succeeds, the script:
1. Tests SSH connection with progress indicator
2. Connects to remote server via SSH
3. Navigates to project directory (`remote_project_dir`)
4. Runs `php craft db/backup --interactive=0` with progress indicator
5. Extracts backup filename from output
6. Downloads backup via SCP to local `storage/backups/` with progress indicator
7. Imports backup using `ddev craft db/restore` with progress indicator

### Asset Sync Features
The asset sync script (`sync-assets`) includes:
- **FTP Connection Testing**: Tests connection with 30-second timeout before syncing
- **Progress Indicators**: Visual feedback during connection and sync operations
- **Selective Sync**: Excludes directories starting with underscore (_) which contain auto-generated thumbnails
- **Error Handling**: Graceful failure handling with clear error messages

### Filename Detection
The script handles multiple backup filename formats:
- **Primary**: Extracts from "Backup file: /path/file.sql (size)" output
- **Secondary**: Pattern matching for timestamped files like `thgc--2025-08-01-220159--v4.16.2.sql`
- **Fallback**: Lists newest .sql file in remote backup directory

### SSH Requirements
- SSH access to remote server
- PHP CLI available in remote project directory
- Craft console commands functional (`php craft db/backup`)
- Write permissions to remote `storage/backups/` directory

## Deployment Methods

### Cloudways SSH Deployment
Runs deployment commands directly on your Cloudways server via SSH:
1. `git fetch origin && git reset --hard origin/BRANCH` - Pull latest code
2. `composer install --no-interaction --prefer-dist --optimize-autoloader` - Install dependencies
3. `php craft project-config/apply --force` - Apply project config
4. `php craft migrate/all --no-interaction` - Run migrations
5. `php craft clear-caches/all` - Clear all caches

All output is streamed to your local terminal in real-time.

### Push to Deploy
- Server automatically deploys when code is pushed to git
- Works with Cloudways, fortrabbit, and other hosts with git deployment
- No additional configuration needed beyond git setup

### Ploi
- Get API token: Settings → API → Create Token
- Server ID and Site ID from Ploi dashboard URLs
- Add to config or enter when prompted

### Laravel Forge
**Option 1: Envoyer**
- Get deployment URL from Envoyer project settings
- Format: `https://envoyer.io/deploy/PROJECT/HASH`

**Option 2: Forge Deployment**
- Enable "Quick Deploy" in Forge site settings
- Copy deployment trigger URL
- Format: `https://forge.laravel.com/servers/12345/sites/67890/deploy/http?token=HASH`

**Option 3: Manual**
- Deploy manually via Forge dashboard or SSH

## Troubleshooting

### Configuration Issues

**Config file not found**
```bash
# Use interactive setup to create config files
npm run update/setup

# Or copy templates manually
cp .update/config.production.yml.example .update/config.production.yml
cp .update/config.staging.yml.example .update/config.staging.yml
```

**"get_config: command not found"**
- Make sure helpers.sh is sourced properly
- Check that CONFIG_FILE environment variable is set
- Verify all scripts have proper shebang (`#!/bin/bash`)

**"invalid refspec" git error**
- Check branch name in config.{env}.yml has no extra spaces
- Verify branch exists: `git branch -r`
- Default branch should be 'main' or 'master'

### SSH/Database Issues

**SSH connection failed**
- Verify SSH settings in config.{env}.yml
- Test manual SSH: `ssh username@hostname`
- Check SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
- Ensure SSH key is added to server: `ssh-copy-id username@hostname`

**FTP connection timeout (30s)**
- Check FTP credentials in config.{env}.yml
- Verify FTP hostname and port (usually 21)
- Test manual FTP: `ftp hostname` or `lftp -u username hostname`
- Check firewall settings (FTP uses ports 20-21)
- Some hosts require SFTP instead of FTP

**Database backup command fails**
- Verify PHP CLI is available on remote server
- Check Craft CMS installation path (`remote_project_dir`)
- Ensure Craft console commands work: `ssh user@host "cd /path && php craft"`
- Verify database credentials on remote server

**Backup file not found**
- Check write permissions on remote `storage/backups/` directory
- Verify backup directory path in config matches remote structure
- Look for backup files manually: `ssh user@host "ls -la /path/storage/backups/"`

**SCP download fails**
- Verify file exists on remote server
- Check local directory permissions
- Ensure backup_dir exists locally: `mkdir -p storage/backups`

### Dependencies

**sshpass not installed** (for SSH password auth)
```bash
brew install sshpass
```

**lftp not installed** (for asset sync)
```bash
brew install lftp
```

**Permission denied**
```bash
chmod +x .update/update.sh .update/scripts/*.sh
```

### General Issues

**Script pauses with error**
- Read error message carefully
- Fix the underlying issue (SSH, permissions, paths)
- Press Enter to continue script execution
- Check log file in `.update/logs/` for details

**Wrong branch after exit**
```bash
git checkout main  # or your default branch
```

**DDEV not running**
```bash
ddev start
ddev describe  # Check status
```

**Multiple password prompts**
- Password should be cached for the session
- Check if `ftp_password` is set in config.{env}.yml
- Verify `sshpass` is installed for automated password entry

**npm command not found**
```bash
# Check if npm is installed
npm --version

# Install Node.js and npm if needed
brew install node
```

**npm run command fails**
```bash
# Make sure you're in the project root directory
pwd

# Check if package.json exists
ls -la package.json

# Run setup to fix permissions
npm run update/setup
```

### Testing SSH Setup

**Test SSH key authentication:**
```bash
ssh -i ~/.ssh/id_rsa username@hostname "echo 'SSH key works'"
```

**Test SSH password authentication:**
```bash
ssh username@hostname "echo 'SSH password works'"
```

**Test remote Craft commands:**
```bash
ssh username@hostname "cd /path/to/project && php craft --version"
```

## File Structure

```
.update/
├── config.production.yml.example   # Production config template
├── config.staging.yml.example      # Staging config template
├── config.production.yml           # Your production config (gitignored)
├── config.staging.yml              # Your staging config (gitignored)
├── update.sh                       # Main update script
├── README.md                       # This documentation
├── logs/                           # Operation logs (gitignored)
│   ├── .gitkeep                    # Keeps directory in git
│   └── update-YYYYMMDD-HHMMSS.log
└── scripts/
    ├── helpers.sh                  # Helper functions and config parsing
    ├── env-detect.sh               # Environment detection logic
    ├── remote-exec.sh              # SSH connection and remote execution
    ├── sync-db.sh                  # Database sync via SSH
    ├── sync-assets.sh              # Asset sync via FTP
    ├── deploy.sh                   # Deployment to remote
    ├── deploy-cloudways.sh         # Cloudways-specific SSH deployment
    ├── interactive-setup.sh        # Interactive configuration wizard
    ├── setup-npm-scripts.sh        # Add npm scripts to package.json
    └── test-ssh.sh                 # Test SSH connectivity
```

## Logs & Monitoring

- All operations logged to `.update/logs/update-YYYYMMDD-HHMMSS.log`
- Each script section logs start/completion status
- SSH output and errors captured for debugging
- Backup filenames and download status recorded
- Git operations and deployment results logged

## Security

- Never commit `config.*.yml` files with passwords/tokens
- Use `chmod 600 .update/config.*.yml` for sensitive configs
- SSH keys preferred over password authentication
- API tokens can be stored in config or entered when prompted
- FTP password reused for SSH authentication (single credential)
- All sensitive values optional in config (will prompt if missing)

## Updating These Scripts

If installed via git subtree:
```bash
# Pull latest updates from the upstream repository
git subtree pull --prefix=.update craftcms-updates main --squash

# Commit the update
git add .update
git commit -m "Update: craftcms-monthly-updates scripts"
```

If installed via direct copy, re-download and replace the `.update` directory, preserving your `config.*.yml` files.
