# Craft CMS Monthly Update Helper Scripts - Claude Reference

This repository contains automated scripts for managing monthly updates to Craft CMS projects. It's designed to help solo developers manage multiple client sites efficiently.

## Repository Structure

### Branch Strategy
- **`main`**: Complete repository with README, LICENSE, package.json, and all scripts
- **`integration`**: Contains only `.update/` directory for integration into existing projects

### Key Directories
- `.update/scripts/`: Core automation scripts
- `.update/tests/`: Comprehensive test suite
- `.update/tests/unit/`: Unit tests for individual functions
- `.update/tests/integration/`: Integration tests for workflows
- `.update/config.yml.example`: Example configuration file

## Core Scripts

### Main Orchestrator
- `.update/update.sh`: Main update workflow script

### Individual Operations
- `.update/scripts/sync-db.sh`: Database synchronization
- `.update/scripts/sync-assets.sh`: Asset file synchronization  
- `.update/scripts/sync-directories.sh`: Additional directory synchronization
- `.update/scripts/deploy.sh`: Deployment automation

### Setup & Configuration
- `.update/scripts/interactive-setup.sh`: Guided configuration wizard
- `.update/scripts/setup-npm-scripts.sh`: NPM scripts integration
- `.update/scripts/test-ssh.sh`: SSH connection testing

### Core Libraries
- `.update/scripts/helpers.sh`: Shared utility functions (config parsing, output)
- `.update/scripts/remote-exec.sh`: SSH/remote execution abstraction

## Test Suite

### Framework
- `.update/tests/test-framework.sh`: Custom bash testing framework
- `.update/tests/run-tests.sh`: Test runner with multiple modes
- `.update/tests/test-connections.sh`: Production connection validation

### Test Categories
- **Unit Tests**: Individual function validation
- **Integration Tests**: End-to-end workflow testing
- **Connection Tests**: Production server connectivity validation

## Key Concepts

### Configuration Management
- YAML-based configuration in `.update/config.yml`
- Support for multiple hosting providers (ServerPilot, Ploi, Forge, fortrabbit)
- Asset storage type detection (Local, S3, Spaces, Other)
- Conditional feature activation based on configuration

### Asset Storage Handling
- **Local Storage**: Downloads assets via FTP/SFTP
- **Cloud Storage** (S3, Spaces): Skips asset sync (assumes shared storage)
- Storage type determined during setup, affects sync behavior

### Authentication Methods
- SSH key authentication (preferred)
- Password authentication (fallback)
- Automatic method detection and fallback

### Error Handling
- Comprehensive error checking and user feedback
- Graceful degradation when optional features unavailable
- Clear troubleshooting guidance in error messages

## NPM Scripts Integration

The setup process adds these scripts to projects:
- `npm run update`: Main update workflow
- `npm run sync-db`: Database sync only
- `npm run sync-assets`: Asset sync only  
- `npm run sync-directories`: Additional directories sync
- `npm run update/test`: Run test suite
- `npm run update/test-connections`: Test production connections
- `npm run update/setup`: Re-run setup wizard
- `npm run update/test-ssh`: Test SSH connection
- `npm run update/deploy`: Deploy to production
- `npm run update/logs`: View recent logs

## Development Guidelines

### Adding New Features
1. Implement function in appropriate script
2. Add unit tests in `.update/tests/unit/`
3. Add integration tests if needed
4. Update setup script if new config required
5. Update README documentation

### Testing Requirements
- All new functions must have unit tests
- Integration tests for workflow changes
- Connection tests for production-facing features
- Tests should use the custom framework in `test-framework.sh`

### Configuration Changes
- Update `.update/config.yml.example`
- Update `interactive-setup.sh` prompts
- Add config validation in `helpers.sh` if needed
- Update test fixtures

### Branch Management
- All changes go to `main` branch first
- Merge `main` to `integration` after testing
- Integration branch must never have root files (README, LICENSE, package.json)
- Keep integration branch clean for conflict-free integration

## Common Maintenance Tasks

### Adding New Hosting Provider
1. Add case in `interactive-setup.sh` server selection
2. Add provider-specific configuration prompts
3. Add provider-specific deployment method
4. Update tests to cover new provider
5. Update documentation

### Adding New Sync Feature
1. Create new script in `.update/scripts/`
2. Add configuration options to setup wizard
3. Add NPM script to `setup-npm-scripts.sh`
4. Add comprehensive tests
5. Update main orchestrator if needed

### Updating Test Suite
1. Add new test files following naming convention `test-*.sh`
2. Use existing test framework functions
3. Include both positive and negative test cases
4. Test error conditions and edge cases
5. Update test runner if new test categories added

## Integration Process

Users integrate these scripts into existing Craft CMS projects via:
1. Clone integration branch to get only `.update/` directory
2. Run interactive setup wizard
3. NPM scripts automatically added to existing package.json
4. Run tests to validate setup
5. Perform first update

This approach prevents conflicts with existing project files while providing full functionality.