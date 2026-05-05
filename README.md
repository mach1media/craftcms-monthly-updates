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

## How It Works

Running `npm run update`:

1. **Pulls** the latest code from your production branch
2. **Syncs** production database automatically via SSH (handles authentication, backup, download, import)
3. **Syncs** assets from production (FTP/SFTP) or skips for cloud storage
4. **Creates** a dated update branch (`update/2025-01-15`)
5. **Updates** Composer dependencies and runs Craft migrations
6. **Pauses** for you to test locally, then offers options:
   - Rollback and start over
   - Merge to production and deploy automatically
   - Merge without deploying
   - Stay on update branch for manual control

**Result**: What used to take 30+ minutes of manual work becomes a mostly-automated 5-minute process.

## Installation

### Method 1: Git Subtree (Recommended)

Git subtree allows you to include these scripts while pulling future updates easily.

```bash
# From your Craft CMS project root
cd /path/to/your-craft-project

# Add the remote (one-time setup)
git remote add craftcms-updates git@github.com:mach1media/craftcms-monthly-updates.git

# Add the subtree (scripts will be placed in .update/)
git subtree add --prefix=.update craftcms-updates main --squash

# Run interactive setup
.update/scripts/interactive-setup.sh
```

**Pulling future updates** (see [Distributing Updates](#distributing-updates-to-existing-projects) below for the full workflow):
```bash
git subtree pull --prefix=.update craftcms-updates main --squash
```

### Method 2: Direct Copy

If you don't need to pull updates:

```bash
# Clone temporarily
git clone git@github.com:mach1media/craftcms-monthly-updates.git /tmp/craftcms-updates

# Create .update directory and copy scripts
mkdir -p /path/to/your-craft-project/.update
cp -r /tmp/craftcms-updates/{scripts,tests,logs,update.sh,config*.example,DOCUMENTATION.md,.gitignore} /path/to/your-craft-project/.update/

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
| **Ploi** | `ploi` | CLI deployment, API deployment, push-to-deploy |
| **Laravel Forge** | `forge` | Envoyer, webhook, manual |
| **ServerPilot** | `serverpilot` | Manual, push-to-deploy |
| **fortrabbit** | app name | Push-to-deploy |
| **Custom** | configurable | Any method |

## Ploi Integration

Enhanced support for [Ploi](https://ploi.io) server management with both CLI and API deployment options.

### Ploi CLI Setup (Recommended)

The Ploi CLI provides the best experience with real-time log streaming during deployment.

```bash
# Install Ploi CLI
brew tap ploi/ploi
brew install ploi

# Configure API token (get from https://ploi.io/panel/settings/api)
ploi token

# Link your project to Ploi (run in project root)
ploi init
```

After linking, deployments automatically use the CLI with log streaming:

```bash
npm run update/deploy
# Output streams deployment logs in real-time
```

### Ploi API Setup (No CLI Required)

If you prefer not to install the CLI, you can use direct API calls:

```yaml
# config.yml
deployment_method: ploi
ploi_server_id: 12345
ploi_site_id: 67890
ploi_api_token: your-token-here  # Or set PLOI_API_TOKEN env var
```

**Finding your Server and Site IDs:**
1. Log in to https://ploi.io
2. Navigate to your server, then your site
3. Check the URL: `ploi.io/panel/servers/[SERVER_ID]/sites/[SITE_ID]`

Or use CLI: `ploi servers` and `ploi sites`

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

## Distributing Updates to Existing Projects

When this repo is updated (new features, bug fixes), each project that installed it as a subtree needs to pull the changes down. Configs (`config.*.yml`) live alongside the scripts but are gitignored, so they're untouched by the pull.

### One-time check per project

Confirm the remote is registered (only needs to be done once after initial install):

```bash
cd /path/to/your-craft-project
git remote -v | grep craftcms-updates
```

If missing, add it:

```bash
git remote add craftcms-updates git@github.com:mach1media/craftcms-monthly-updates.git
```

### Pulling the latest scripts

From the project root:

```bash
git subtree pull --prefix=.update craftcms-updates main --squash
```

This creates a merge commit on your project's current branch. Push when you're ready:

```bash
git push origin main   # or whichever branch you're on
```

### Distributing across all monthly-update projects

For solo developers maintaining multiple Craft sites that all use these scripts, run the pull in each project. A simple loop:

```bash
for project in ~/Sites/client-a ~/Sites/client-b ~/Sites/client-c; do
    echo "=== Updating $project ==="
    cd "$project" || continue
    git subtree pull --prefix=.update craftcms-updates main --squash
done
```

After pulling, verify nothing broke by running a no-op command:

```bash
.update/scripts/test-ssh.sh   # or any individual script
```

### Conflict resolution

If `git subtree pull` reports conflicts, they'll be in `.update/` files. Since `.update/` is upstream-managed code, prefer the incoming changes:

```bash
git checkout --theirs .update/
git add .update/
git commit
```

Only resolve manually if you've intentionally modified a script locally (which is generally discouraged — open an issue or PR upstream instead).

## Repository Structure

This repo is designed to be added as a subtree with `--prefix=.update`. After installation, your project will have:

```
your-craft-project/
└── .update/
    ├── config.staging.yml      # Your staging config (gitignored)
    ├── config.production.yml   # Your production config (gitignored)
    ├── update.sh               # Main update script
    ├── DOCUMENTATION.md        # Full documentation
    └── scripts/
        ├── interactive-setup.sh
        ├── env-detect.sh
        ├── helpers.sh
        ├── sync-db.sh
        ├── sync-assets.sh
        ├── deploy.sh
        ├── deploy-cloudways.sh
        ├── provider-detect.sh
        ├── providers/
        │   └── ploi.sh
        └── test-ssh.sh
```

## Documentation

For complete documentation including detailed configuration, troubleshooting, and security best practices, see [DOCUMENTATION.md](DOCUMENTATION.md).

## License

MIT
