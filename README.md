# Craft CMS Monthly Update Helper Scripts

Automates the tedious monthly maintenance routine for Craft CMS projects. Eliminates manual database downloads, asset syncing, and deployment coordination that solo developers typically struggle with when maintaining multiple client sites.

## What Problems This Solves

**For Solo Developers Managing Multiple Craft CMS Sites:**
- **Manual Database Sync Pain**: No more manually downloading production databases, importing locally, and managing backup files
- **Asset Sync Complexity**: Automatically handles FTP/SFTP asset synchronization or skips it entirely for cloud storage (S3, Spaces)
- **Update Workflow Chaos**: Replaces error-prone manual processes with a consistent, tested workflow
- **Deployment Coordination**: Streamlines the update → test → deploy cycle with built-in rollback options
- **Environment Inconsistency**: Ensures your local development environment perfectly mirrors production data

## What the Main Script Does

When you run `npm run update`, the orchestrator script:

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


## Integration into Existing Craft CMS Projects

### Method 1: Clone Integration Branch (Recommended)

The `integration` branch contains only the `.update/` directory, preventing conflicts with existing project files:

```bash
# From your Craft CMS project root
git remote add craftcms-updates git@github.com:mach1media/craftcms-monthly-updates.git
git fetch craftcms-updates integration
git checkout craftcms-updates/integration -- .update/

# Run setup wizard (prompts for project settings, adds npm scripts to package.json)
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


## Setup Commands

```bash
# Interactive setup wizard
# Runs .update/scripts/interactive-setup.sh if not already done
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
npm run sync-db          # Sync database from production
npm run sync-assets      # Sync assets from production
npm run sync-directories # Sync other specific directories from production
npm run update/deploy    # Deploy to production
```

## Testing & Validation

**🧪 Comprehensive Test Suite:**
```bash
# Run all unit and integration tests
npm run update/test

# Test actual connections to your production server
npm run update/test-connections

# Advanced test options
.update/tests/run-tests.sh --unit-only
.update/tests/run-tests.sh --with-connections
.update/tests/run-tests.sh --verbose
```

### What Gets Tested

**Unit Tests:**
- ✅ Config file parsing and YAML handling
- ✅ SSH key discovery and authentication methods
- ✅ Asset storage type decisions (local vs cloud)
- ✅ Database backup filename generation
- ✅ Directory sync parsing and validation
- ✅ Error handling for missing files/keys

**Integration Tests:**
- ✅ Complete workflow validation
- ✅ NPM scripts generation
- ✅ Config file structure validation
- ✅ Directory structure verification

**Connection Tests:**
- 🔐 SSH connectivity to production server
- 📁 Remote project directory access
- ⚙️ Craft CMS installation detection
- 🗄️ Database connectivity via Craft CLI
- 💾 Backup directory permissions
- 🖼️ Asset storage validation
- 📂 Additional sync directories

**Recommended Testing Workflow:**
1. After setup: `npm run update/test` (validate all functions)
2. Before first update: `npm run update/test-connections` (verify production connectivity)
3. After script updates: `npm run update/test` (ensure no regressions)


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
npm run update/test
npm run update/test-connections
npm run update/logs
npm run update/deploy
```

### Updating Scripts in Your Project

```bash
# Fetch latest updates from integration branch
git fetch craftcms-updates integration

# View changes before updating
git diff HEAD craftcms-updates/integration -- .update/

# Update all scripts
git checkout craftcms-updates/integration -- .update/
git commit -m "Update Craft CMS utility scripts"

# Update specific files only
git checkout craftcms-updates/integration -- .update/scripts/sync-db.sh
git commit -m "Update database sync script"
```

### Example: Pushing Updates to Your Project

```bash
# After making changes to your Craft CMS project
git add .
git commit -m "Monthly updates and improvements"
git push origin main  # This pushes to YOUR project repo, not the update scripts repo
```

**Note**: The `git push origin main` command pushes to your Craft CMS project repository (origin), not to the craftcms-updates repository. Your project maintains its own git history while incorporating the utility scripts.

### Key Benefits

- **No conflicts**: Integration branch excludes package.json and other project files
- **Automatic npm setup**: Handles existing package.json files gracefully  
- **Clean updates**: Only update the scripts you need
- **Isolated**: Scripts don't interfere with your project structure
- **Easy maintenance**: Simple commands to pull script updates without affecting your project
- **Fully tested**: Comprehensive test suite ensures reliability and catches issues early
- **Production ready**: Connection tests validate setup before first update