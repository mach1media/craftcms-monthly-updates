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
