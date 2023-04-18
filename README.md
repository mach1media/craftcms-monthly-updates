# TMF Craft CMS Website

This project uses:

1. Craft CMS
2. DDEV + Docker for local hosting
3. Laravel Mix for frontend development
4. Twitter Bootstrap
5. [HC Offcanvas Nav](https://github.com/somewebmedia/hc-offcanvas-nav) for mobile nav menu


# First Time Setup

Steps for first-time project setup.

1. Install Docker Desktop
    - Go to https://www.docker.com and click the [Download Docker Desktop] button.
    - cd into parent project directory and follow installation instructions

2. Install DDEV
    - https://ddev.com/get-started/
    - cd into parent project directory and follow installation instructions
    - run `ddev start` to start the local web server
    - Import database (TODO: Insert database import instructions)

3. Install Source Packages
    - https://laravel-mix.com/docs/6.0/installation
    - cd into `src` directory
    - run `npm install --save-dev`



# Local Development

1. Start DDEV
    - cd into parent project directory
    - run `ddev start` to start the local web server

2. Start Laravel Mix
    - cd into `src` directory
    - run `npx mix watch` to watch for file changes

3. Compile for Production
    - cd into `src` directory
    - run `npx mix --production` to compile minified CSS and JS for production