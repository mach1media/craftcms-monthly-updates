# Craft CMS Monthly Update Helper Scripts

A collection of helper script to assist in performing monthly updates for Craft CMS projects hosted on servers provisioned by various providers.

## Setup Commands

```bash
# Interactive setup wizard (recommended)
npm run update/setup

# Test SSH connection to production
npm run update/test-ssh

# View recent update logs
npm run update/logs
```

## Update & Maintenance Commands

**Automated Monthly Updates:**
```bash
# Run complete update workflow (recommended)
npm run update

# Individual sync operations:
npm run sync-db      # Sync database from production
npm run sync-assets  # Sync assets from production
npm run update/deploy  # Deploy to production
```

## Integration into Existing Craft CMS Projects

### Method 1: Clone Integration Branch (Recommended)

The `integration` branch is designed specifically for use in existing Craft CMS projects:

```bash
# From your Craft CMS project root
git remote add craftcms-updates https://github.com/mach1media/craftcms-monthly-updates.git
git fetch craftcms-updates integration
git checkout craftcms-updates/integration -- .update/

# Run setup wizard
.update/scripts/interactive-setup.sh

# Commit to your project
git add .update/
git commit -m "Add Craft CMS monthly update utility scripts"
```

### Method 2: Manual Integration

```bash
# Download and extract the integration branch
curl -L https://github.com/mach1media/craftcms-monthly-updates/archive/integration.tar.gz | tar -xz
mv craftcms-monthly-updates-integration/.update ./
rm -rf craftcms-monthly-updates-integration/

# Run setup
.update/scripts/interactive-setup.sh
```

### NPM Scripts Integration

The setup wizard automatically handles npm scripts:

- **If no package.json exists**: Creates one with the update scripts
- **If package.json exists**: Adds update scripts to existing scripts section
- **Conflict detection**: Warns if scripts will be overwritten

You can also run npm setup separately:
```bash
.update/scripts/setup-npm-scripts.sh
```

### Available Commands After Setup

```bash
# Core update workflow
npm run update

# Individual operations  
npm run sync-db
npm run sync-assets
npm run sync-directories

# Setup and testing
npm run update/setup
npm run update/test-ssh
npm run update/logs
npm run update/deploy
```

### Updating Scripts in Your Project

```bash
# Fetch latest updates
git fetch craftcms-updates integration

# View changes
git diff HEAD craftcms-updates/integration -- .update/

# Update all scripts
git checkout craftcms-updates/integration -- .update/
git commit -m "Update Craft CMS utility scripts"

# Update specific files only
git checkout craftcms-updates/integration -- .update/scripts/sync-db.sh
git commit -m "Update database sync script"
```

### Key Benefits

- **No conflicts**: Integration branch excludes package.json and other project files
- **Automatic npm setup**: Handles existing package.json files gracefully  
- **Clean updates**: Only update the scripts you need
- **Isolated**: Scripts don't interfere with your project structure