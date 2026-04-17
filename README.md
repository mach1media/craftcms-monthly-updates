# The Methodist Foundation

This project uses:

1. Craft CMS 5.x (PHP 8.4, MariaDB 10.11)
2. DDEV + Docker for local hosting
3. Vite for frontend development
4. Bootstrap 5.3.3


# First Time Setup

Steps for first-time project setup.

1. **Install Docker Desktop**
    - Go to https://www.docker.com and click the Download Docker Desktop button
    - Follow the installation instructions for your OS

2. **Install DDEV**
    - Follow the instructions at https://ddev.com/get-started/
    - cd into the project root directory

3. **Start DDEV**
    - Run `ddev start` to start the local web server
    - The site will be available at https://tmf.ddev.site/

4. **Import the Database**
    - Run `npm run sync-db` to sync the database from production
    - Or run `ddev import-db --file=<path-to-sql-dump>` to import a database snapshot

5. **Install PHP Dependencies**
    - Run `ddev composer install`

6. **Install Frontend Dependencies**
    - Run `ddev exec -d /var/www/html/src npm install`

> **Note:** Node.js runs inside the DDEV container — there is no need to install Node or nvm on your host machine.


# Local Development

1. **Start DDEV**
    - Run `ddev start` from the project root

2. **Start Vite Dev Server**
    - Run `npm run dev` from the project root
    - This starts the Vite dev server inside DDEV with hot module replacement
    - The dev server runs on https://tmf.ddev.site:3000

3. **Build for Production**
    - Run `npm run build` from the project root
    - Compiled assets are output to `web/dist/`

4. **Preview Production Build**
    - Run `npm run preview` from the project root

# Composer and Craft CLI Commands

1. Run composer and Craft CLI commands within the ddev container
    - `ddev composer update` - Update composer packages
    - `ddev craft update all` - Update composer packages + run Craft's migrations

2. Craft CMS console commands
    - [Console Commands](https://craftcms.com/docs/5.x/reference/cli.html) documentation
    - `ddev craft db/backup` - Export a database backup to `/storage/backups/`
    - `ddev craft db/restore <path/to/file.sql[.gz]>` - Restore a database backup
    - `ddev craft clear-caches/all` - Purge all of craft's caches

3. DDEV commands
    - `ddev describe` or `ddev status` - Prints info on the active site
    - `ddev exec <command>` - Execute a command in the active site's environment
    - `ddev craft <command>` == `ddev exec php craft <command>`

# Project Info

1. See CLAUDE.md for project-specific info
