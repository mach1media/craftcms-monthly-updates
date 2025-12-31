# Mailchimp Subscription Status Module - Requirements Questionnaire

## Module Configuration

### 1. Mailchimp Setup
- [ ] What is the exact name/version of the Mailchimp PHP SDK you want to use? (e.g., mailchimp/marketing:^3.0)
  - Use git@github.com:mailchimp/mailchimp-marketing-php.git
- [ ] Should the API key and audience ID be stored in:
  - [x] Craft's .env file
  - [ ] Module settings in control panel
  - [ ] Hard-coded in module config
- [ ] Do you need to support multiple Mailchimp audiences or just one?
  - Just one audience

### 2. Module Naming
- [ ] What should the module be named? (e.g., MailchimpSubscriptionChecker, McStatusModule)
  - MailchimpModule
- [ ] What namespace should be used? (e.g., modules\mailchimp)
  - modules\mailchimp

## User Experience & Flow

### 3. Form Implementation
- [ ] Should the email check happen via:
  - [x] AJAX (no page reload)
  - [ ] Form submission (page reload)
- [ ] What should happen while checking status? (loading indicator, disabled button, etc.)
  - simple text loading indicator
  - disable the button 
- [ ] Should there be any rate limiting or spam protection?
  - Yes, use reasonable defaults and leverage available security features from craft cms

### 4. UI Elements
- [ ] For the "unsubscribed" alert:
  - [ ] What exact message should be shown?
    - "This email address was previously unsubscribed."
  - [ ] What should the resubscribe button text be?
    - "Resubscribe"
    - Also show a "Cancel" button or text link which reverts form to default state.
  - [ ] Do you have the Mailchimp hosted form URL ready?
    - Yes, but I'd prefer fetch this via API if possible
    - https://mailchi.mp/texasmethodistfoundation.org/tmf-subscribe
  
- [ ] For the "already subscribed" alert:
  - [ ] What exact message should be shown?
    - "This email address is already subscribed."
  - [ ] What should the dismiss button text be?
    - Also show a "Cancel" button or text link which reverts form to default state.
  
- [ ] For the "not found" scenario:
  - [ ] Should there be any transition animation between hiding the initial form and showing the Formstack form?
    - No animated transition necessary
  - [ ] Is the Formstack form already embedded in the page (just hidden) or loaded dynamically?
    - Formstack embed code comes from a page builder field on a Craft entry
    - We will update the template partial corresponding with this Neo block type
  - [ ] What's the Formstack form ID or embed code?
    - Formstack embed code comes from a page builder field on a Craft entry

### 5. Styling
- [ ] Should alerts use:
  - [x] Bootstrap alert classes (given your Bootstrap 5.2.2 setup)
  - [ ] Custom CSS classes
  - [ ] Inline styles
- [ ] Any specific design requirements for the alerts/buttons?
  - Default bootstrap classes

## Technical Implementation

### 6. Error Handling
- [ ] What should happen if the Mailchimp API is down or returns an error?
  - Show alert message with API response including error code and human readable message
- [ ] Should errors be:
  - [ ] Shown to the user
  - [ ] Logged only
  - [x] Both
- [ ] What user-friendly message for API failures?
  - Show alert message with API response including error code and human readable message
  - We will adjust later if necessary but initially I want to see raw API responses on error

### 7. Response Caching
- [ ] Should subscription status checks be cached?
  - No caching necessary
- [ ] If yes, for how long?

### 8. Security
- [ ] Should the module verify the request origin (CSRF protection)?
  - Yes
- [ ] Any IP-based rate limiting needed?
  - Please implement reasonable rate limiting without over-complicating our code
- [ ] Should email addresses be validated before API call?
  - Yes, but only using simple regex pattern matching
  - Do not accept non-US domain names

## Integration Details

### 9. Existing Form Setup
- [ ] Is there an existing form in a template I should work with, or create new?
  - Create a new form using bootstrap form classes and markup
- [ ] If existing, what's the template path and form details?
- [ ] Are you using Formie for the initial email form or plain HTML?
  - Plain HTML

### 10. Additional Mailchimp Data
- [ ] Besides subscription status, do you need any other member data? (tags, merge fields, etc.)
  - Please show all data from API response
  - I may target specific fields/nodes later
- [ ] Should the module handle any other Mailchimp operations in the future?
  - Yes, at its core the module should accommodate all mailchimp API methods

### 11. Logging & Monitoring
- [ ] Should the module log all status checks?
  - No
- [ ] Any specific logging requirements?
  -  No logging required

## Development Preferences

### 12. Code Style
- [ ] Any specific PHP coding standards to follow?
  - Use context7 for craftcms module coding style guide reference
  - https://github.com/craftcms/docs/blob/main/docs/3.x/extend/module-guide.md
- [ ] Preference for:
  - [ ] Dependency injection vs direct instantiation
  - [x] Async/promises vs synchronous API calls
  - Or whatever is suggested in craftcms docs in context7

### 13. Testing
- [ ] Do you want me to include:
  - [ ] Unit tests
  - [ ] Integration tests
  - [x] Manual testing instructions

### 14. Documentation
- [ ] Should I create:
  - [x] README for the module
  - [x] Inline code documentation using low verbosity
  - [x] Setup/installation guide including uninstall

## Additional Context

### 15. Timeline & Dependencies
- [ ] Any deadline or urgency for this feature?
  - Need this integrated and ready for client testing within two days
- [ ] Are there any other systems/features this needs to integrate with?
  - No
- [x] Any accessibility requirements (ARIA labels, keyboard navigation)?
  - Use ARIA labels, keyboard navigation is not critical

### 16. Business Logic
- [ ] Are there any other conditions that affect whether someone can subscribe? (geographic restrictions, user types, etc.)
  - Email only, no other conditions
- [ ] Should unsubscribed users see why they were unsubscribed? (if Mailchimp provides this)
  - Yes, if the API provides a reason in response please show it

Please review these questions and provide answers. Once I have your responses, I'll update this document with any additional clarifying questions if needed, then provide a detailed implementation plan.

## Additional Clarifying Questions

### API Integration
1. For the Mailchimp hosted form URL:
  - You mentioned preferring to fetch this via API - do you want the module to dynamically fetch the signup form URL from Mailchimp, or should we use the provided URL as a fallback?
    - Check API response for existence of this hosted form URL
    - Fall back to hard-coded URL above if not found
  - Should this URL be stored in the .env file as well for flexibility?
    - Yes

### Form Integration
2. You mentioned the Formstack embed code comes from a page builder field on a Craft entry:
  - What is the specific Neo block type name that contains this Formstack embed?
    - `Embed Code` block type within the `pageBuilderGeneral` Neo field
  - What is the field handle for the Formstack embed code within that block?
    - `embedCode` block type within the `Embed Code` block type
  - Should the module be integrated into this existing Neo block template, or create a new block type?
    - Create a new block type specifically for this scenario called `Mailchimp Opt-In Validator`

### Email Validation
3. Regarding "Do not accept non-US domain names":
  - Do you mean:
    [ ] Only accept .com, .org, .edu, .gov, .net, .mil domains?
    [x] Block specific international TLDs like .cn, .ru, etc.?
    [ ] Use a whitelist/blacklist approach?
  - Should this validation message be user-friendly or technical?
    - "Sorry, this domain is not part of our target audience."

### UI Flow
4. For the "already subscribed" scenario:
  - You mentioned a "Cancel" button but no dismiss button text. Should it just say "Cancel" or did you want both "Dismiss" and "Cancel"?
    - The button/text label should be "OK"

### Module Architecture
5. Since you want the module to "accommodate all mailchimp API methods":
  - Should I create a generic service class with methods for common operations?
    - YES
  - Do you have immediate plans for other API methods, or is this for future flexibility?
    - For future flexibility
    - Other clients also use Mailchimp and I may want to package this module for use in other projects

### Installation
6. For the Mailchimp PHP SDK:
  - Should I add it to the project's composer.json, or would you prefer to handle that separately?
  - The GitHub repo you referenced - should I use composer require or clone the repo?
    - Follow conventions used by the Formie plugin
    - Formie includes integrations for many third party APIs and I respect their work

### Version control
7. `mailchimp` branch
  - Please commit frequently to the `mailchimp` branch

Please provide these additional details so I can create a comprehensive implementation plan.