# Craft CMS Monthly Update Scripts

Automates the tedious monthly maintenance routine for Craft CMS projects. Eliminates manual database downloads, asset syncing, and deployment coordination that solo developers typically struggle with when maintaining multiple client sites.

## Features

- **Multi-environment support** - Separate configs for staging and production
- **Intelligent branch detection** - Auto-detects target environment from git branch
- **Automated database sync** - SSH-based backup and download from remote servers
- **Asset sync** - SFTP/FTP file synchronization with progress indicators
- **Multiple hosting providers** - Pre-configured for Cloudways, Ploi, Forge, ServerPilot, fortrabbit
- **Flexible deployment** - Push-to-deploy, API-based, SSH, or manual options
- **Rollback support** - Built-in options to abort and start over

## What Problems This Solves

**For Solo Developers Managing Multiple Craft CMS Sites:**
- **Manual Database Sync Pain**: No more manually downloading production databases, importing locally, and managing backup files
- **Asset Sync Complexity**: Automatically handles FTP/SFTP asset synchronization or skips it entirely for cloud storage (S3, Spaces)
- **Update Workflow Chaos**: Replaces error-prone manual processes with a consistent, tested workflow
- **Deployment Coordination**: Streamlines the update → test → deploy cycle with built-in rollback options
- **Environment Inconsistency**: Ensures your local development environment perfectly mirrors production data

## Installation

### Method 1: Git Subtree (Recommended)

Git subtree allows you to include these scripts while pulling future updates easily.

```bash
# From your Craft CMS project root
cd /path/to/your-craft-project

# Add the remote (one-time setup)
git remote add craftcms-updates git@github.com:mach1media/craftcms-monthly-updates.git

# Add the subtree
git subtree add --prefix=.update craftcms-updates main --squash

# Run interactive setup
.update/scripts/interactive-setup.sh

# Commit to your project
git add .
git commit -m "Add Craft CMS monthly update scripts"
```

**Pulling future updates:**
```bash
git subtree pull --prefix=.update craftcms-updates main --squash
```

### Method 2: Direct Copy

If you don't need to pull updates:

```bash
# Clone temporarily
git clone git@github.com:mach1media/craftcms-monthly-updates.git /tmp/craftcms-updates

# Copy to your project
cp -r /tmp/craftcms-updates/.update /path/to/your-craft-project/

# Clean up and run setup
rm -rf /tmp/craftcms-updates
cd /path/to/your-craft-project
.update/scripts/interactive-setup.sh
```

## Quick Start

After installation, run the interactive setup:

```bash
# Using npm (after setup adds scripts to package.json)
npm run update/setup

# Or directly
.update/scripts/interactive-setup.sh
```

The wizard will:
1. Ask which environment(s) to configure (staging, production, or both)
2. Configure paths based on your hosting provider
3. Set up SSH and deployment settings
4. Create `config.staging.yml` and/or `config.production.yml`
5. Add npm scripts to your package.json

## Usage

### Complete Update Workflow

```bash
npm run update
```

This runs the full workflow:
1. **Pulls** latest code from git
2. **Syncs** database from selected environment via SSH
3. **Syncs** assets via SFTP/FTP (or skips for cloud storage)
4. **Creates** update branch (`update/YYYY-MM-DD`)
5. **Updates** Composer dependencies and runs migrations
6. **Pauses** for local testing, then offers:
   - Rollback and start over
   - Merge and deploy
   - Merge without deploying
   - Stay on update branch

### Individual Commands

```bash
# Sync database (auto-detects environment from branch)
npm run sync-db

# Specify environment explicitly
npm run sync-db -- --staging
npm run sync-db -- --production

# Sync assets
npm run sync-assets -- --production

# Deploy
npm run update/deploy -- --staging

# Test SSH connection
npm run update/test-ssh -- --production
```

## Multi-Environment Support

Scripts automatically detect the target environment based on your current git branch:

| Branch | Environment |
|--------|-------------|
| `staging` | Staging |
| `production` | Production |
| `main` / `master` | Production (or prompts if `production` branch exists) |
| Feature branches | Prompts for selection |

Override with flags: `--staging`, `--production`, or `--env=<name>`

### Configuration Files

Each environment has its own config file:
- `.update/config.staging.yml` - Staging settings
- `.update/config.production.yml` - Production settings

## Supported Hosting Providers

The setup wizard auto-configures paths for:

| Provider | SSH User | Deployment Options |
|----------|----------|-------------------|
| **Cloudways** | `master_xxxxx` | SSH deployment, push-to-deploy |
| **Ploi** | `ploi` | API deployment, push-to-deploy |
| **Laravel Forge** | `forge` | Envoyer, webhook, manual |
| **ServerPilot** | `serverpilot` | Manual, push-to-deploy |
| **fortrabbit** | app name | Push-to-deploy |
| **Custom** | configurable | Any method |

## Requirements

- Bash shell (macOS/Linux)
- Git
- SSH access to remote server(s)
- DDEV (for local Craft CMS development)

**Optional dependencies:**
```bash
# macOS
brew install sshpass  # For SSH password authentication
brew install lftp     # For asset sync via FTP/SFTP
```

## Migrating Existing Installations

### To Git Subtree

If you previously copied the scripts directly:

```bash
cd /path/to/your-craft-project

# Backup configs
cp .update/config.*.yml /tmp/

# Remove and re-add as subtree
git rm -r --cached .update
rm -rf .update
git commit -m "Remove .update for subtree migration"

git remote add craftcms-updates git@github.com:mach1media/craftcms-monthly-updates.git
git subtree add --prefix=.update craftcms-updates main --squash

# Restore configs
cp /tmp/config.*.yml .update/
git add .update/config.*.yml
git commit -m "Restore configs after subtree migration"
```

### To Multi-Environment Config

If you have a legacy `config.yml`:

```bash
# Option 1: Re-run setup (recommended)
npm run update/setup

# Option 2: Manual migration
cp .update/config.yml .update/config.production.yml
# Edit and add: environment: production
rm .update/config.yml
```

## File Structure

```
your-craft-project/
└── .update/
    ├── config.staging.yml      # Your staging config (gitignored)
    ├── config.production.yml   # Your production config (gitignored)
    ├── update.sh               # Main update script
    ├── README.md               # Full documentation
    └── scripts/
        ├── interactive-setup.sh
        ├── env-detect.sh
        ├── helpers.sh
        ├── sync-db.sh
        ├── sync-assets.sh
        ├── deploy.sh
        ├── deploy-cloudways.sh
        └── test-ssh.sh
```

## Documentation

For complete documentation including detailed configuration, troubleshooting, and security best practices, see [.update/README.md](.update/README.md).

## License

MIT
