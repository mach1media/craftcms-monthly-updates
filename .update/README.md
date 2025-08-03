# Craft CMS Update Scripts

Automated update workflow for monthly Craft CMS maintenance with SSH-based database sync and FTP asset sync.

## Quick Start

**Using npm (recommended):**
```bash
# From project root - run complete update workflow
npm run update

# Or run individual steps:
npm run sync-db        # Sync database only
npm run sync-assets    # Sync assets only  
npm run update/deploy  # Deploy only
```

**Direct script execution:**
```bash
# From project root
.update/update.sh
```

## Initial Setup

**Using npm (recommended):**
```bash
# 1. Run interactive setup wizard
npm run update/setup

# The wizard will:
# - Ask about your hosting provider (ServerPilot, Ploi, Forge, fortrabbit, etc.)
# - Configure paths based on your provider
# - Set up SSH and deployment settings
# - Create config.yml with your settings

# 2. Test SSH connection
npm run update/test-ssh

# 3. You're ready to run updates!
npm run update
```

**Manual setup:**
```bash
# 1. Copy config template
cp .update/config.yml.example .update/config.yml

# 2. Edit config.yml with your project details

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
- Deployment: Automatic on git push

### Other/Custom
- Prompts for all paths and settings
- Supports GitHub Actions, manual, or custom deployment

## Configuration

The setup wizard creates `.update/config.yml` automatically. You can also edit it manually:

### Required Settings
```yaml
# Git and site settings
branch: main                           # Git branch (main/master)
production_url: https://example.com    # Production site URL
deployment_method: ploi                 # ploi, github-actions, or forge-envoyer

# SSH settings for automated database sync
ssh_host: example.com                   # SSH hostname
ssh_user: username                      # SSH username
ssh_port: 22                           # SSH port (usually 22)
remote_project_dir: /public_html       # Remote project root directory

# Shared directory paths (same relative paths on local and remote)
backup_dir: storage/backups            # Database backup directory
uploads_dir: web/uploads               # Asset uploads directory
```

### FTP Settings (for asset sync)
```yaml
ftp_host: ftp.example.com              # FTP hostname
ftp_user: username                     # FTP username
ftp_password:                          # FTP password (optional - will prompt if empty)
remote_uploads_dir: /public_html/web/uploads  # Full remote path to uploads
```

### Deployment Settings
```yaml
# Ploi settings (if using Ploi)
ploi_server_id: 12345                  # Your Ploi server ID
ploi_site_id: 67890                    # Your Ploi site ID
ploi_api_token:                        # Ploi API token (optional - will prompt)

# Envoyer settings (if using Forge/Envoyer)
envoyer_project_id: 12345              # Your Envoyer project ID
envoyer_api_token:                     # Envoyer API token (optional - will prompt)

# Build settings (optional)
run_npm_build: false                   # Set to true if you need npm build
npm_build_command: npm run build       # Custom build command
```

## Available npm Commands

All commands should be run from the project root directory:

### Main Commands
- `npm run update` - Run complete update workflow
- `npm run sync-db` - Sync database from production only
- `npm run sync-assets` - Sync assets from production only  
- `npm run update/deploy` - Deploy to production only

### Setup & Testing Commands
- `npm run update/setup` - Interactive setup wizard (auto-configures based on hosting provider)
- `npm run update/test-ssh` - Test SSH connection to production server
- `npm run update/logs` - View recent update logs

### Frontend Build Commands
- `npm run build/watch` - Watch and compile frontend assets
- `npm run build/css` - Compile CSS only
- `npm run build/js` - Compile JavaScript only

## Update Process

The main update script (`npm run update`) performs these steps:

1. **Pull** latest code from git
2. **Sync database** from production (automated via SSH or manual fallback)
3. **Sync** assets from production via FTP
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
   - Uses `ftp_password` from config.yml
   - Requires `sshpass` utility: `brew install sshpass`
   - Prompts for password if not in config
   - Password is reused for SCP download

3. **Manual Fallback**
   - Activates if all SSH methods fail
   - Provides step-by-step manual instructions

### Automated Process Flow
When SSH succeeds, the script:
1. Connects to remote server via SSH
2. Navigates to project directory (`remote_project_dir`)
3. Runs `php craft db/backup --interactive=0`
4. Extracts backup filename from output
5. Downloads backup via SCP to local `storage/backups/`
6. Imports backup using `ddev craft db/restore`

### Filename Detection
The script handles multiple backup filename formats:
- **Primary**: Extracts from "Backup file: /path/file.sql (size)" output
- **Secondary**: Pattern matching for timestamped files like `thgc--2025-08-01-220159--v4.16.2.sql`
- **Fallback**: Lists newest .sql file in remote backup directory

### SSH Requirements
- SSH access to production server
- PHP CLI available in remote project directory
- Craft console commands functional (`php craft db/backup`)
- Write permissions to remote `storage/backups/` directory

## Deployment Methods

### GitHub Actions
- Automatically triggered on push
- No additional configuration needed

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

### fortrabbit
- Automatic deployment on git push
- No additional configuration needed

## Troubleshooting

### Configuration Issues

**Config file not found**
```bash
cp .update/config.yml.example .update/config.yml
# Edit config.yml with your settings
```

**"get_config: command not found"**
- Make sure helpers.sh is sourced properly
- Check that CONFIG_FILE environment variable is set
- Verify all scripts have proper shebang (`#!/bin/bash`)

**"invalid refspec" git error**
- Check branch name in config.yml has no extra spaces
- Verify branch exists: `git branch -r`
- Default branch should be 'main' or 'master'

### SSH/Database Issues

**SSH connection failed**
- Verify SSH settings in config.yml
- Test manual SSH: `ssh username@hostname`
- Check SSH key permissions: `chmod 600 ~/.ssh/id_rsa`
- Ensure SSH key is added to server: `ssh-copy-id username@hostname`

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
- Check if `ftp_password` is set in config.yml
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
pwd  # Should show path ending in /thgaac

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
├── config.yml.example          # Configuration template
├── config.yml                  # Your configuration (gitignored)
├── update.sh                   # Main update script
├── README.md                   # This documentation
├── logs/                       # Operation logs (gitignored)
│   ├── .gitkeep                # Keeps directory in git
│   └── update-YYYYMMDD-HHMMSS.log
└── scripts/
    ├── helpers.sh              # Helper functions and config parsing
    ├── sync-db.sh              # Database sync via SSH
    ├── sync-assets.sh          # Asset sync via FTP
    └── deploy.sh               # Deployment to production
```

## Logs & Monitoring

- All operations logged to `.update/logs/update-YYYYMMDD-HHMMSS.log`
- Each script section logs start/completion status
- SSH output and errors captured for debugging
- Backup filenames and download status recorded
- Git operations and deployment results logged

## Security

- Never commit `config.yml` with passwords/tokens
- Use `chmod 600 .update/config.yml` for sensitive configs
- SSH keys preferred over password authentication
- API tokens can be stored in config or entered when prompted
- FTP password reused for SSH authentication (single credential)
- All sensitive values optional in config (will prompt if missing)