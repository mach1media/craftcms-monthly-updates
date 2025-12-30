# Mailchimp Subscription Status Module - Requirements Questionnaire

## Module Configuration

### 1. Mailchimp Setup
- [ ] What is the exact name/version of the Mailchimp PHP SDK you want to use? (e.g., mailchimp/marketing:^3.0)
- [ ] Should the API key and audience ID be stored in:
  - [ ] Craft's .env file
  - [ ] Module settings in control panel
  - [ ] Hard-coded in module config
- [ ] Do you need to support multiple Mailchimp audiences or just one?

### 2. Module Naming
- [ ] What should the module be named? (e.g., MailchimpSubscriptionChecker, McStatusModule)
- [ ] What namespace should be used? (e.g., modules\mailchimp)

## User Experience & Flow

### 3. Form Implementation
- [ ] Should the email check happen via:
  - [ ] AJAX (no page reload)
  - [ ] Form submission (page reload)
- [ ] What should happen while checking status? (loading indicator, disabled button, etc.)
- [ ] Should there be any rate limiting or spam protection?

### 4. UI Elements
- [ ] For the "unsubscribed" alert:
  - [ ] What exact message should be shown?
  - [ ] What should the resubscribe button text be?
  - [ ] Do you have the Mailchimp hosted form URL ready?
  
- [ ] For the "already subscribed" alert:
  - [ ] What exact message should be shown?
  - [ ] What should the dismiss button text be?
  
- [ ] For the "not found" scenario:
  - [ ] Should there be any transition animation between hiding the initial form and showing the Formstack form?
  - [ ] Is the Formstack form already embedded in the page (just hidden) or loaded dynamically?
  - [ ] What's the Formstack form ID or embed code?

### 5. Styling
- [ ] Should alerts use:
  - [ ] Bootstrap alert classes (given your Bootstrap 5.2.2 setup)
  - [ ] Custom CSS classes
  - [ ] Inline styles
- [ ] Any specific design requirements for the alerts/buttons?

## Technical Implementation

### 6. Error Handling
- [ ] What should happen if the Mailchimp API is down or returns an error?
- [ ] Should errors be:
  - [ ] Shown to the user
  - [ ] Logged only
  - [ ] Both
- [ ] What user-friendly message for API failures?

### 7. Response Caching
- [ ] Should subscription status checks be cached?
- [ ] If yes, for how long?

### 8. Security
- [ ] Should the module verify the request origin (CSRF protection)?
- [ ] Any IP-based rate limiting needed?
- [ ] Should email addresses be validated before API call?

## Integration Details

### 9. Existing Form Setup
- [ ] Is there an existing form in a template I should work with, or create new?
- [ ] If existing, what's the template path and form details?
- [ ] Are you using Formie for the initial email form or plain HTML?

### 10. Additional Mailchimp Data
- [ ] Besides subscription status, do you need any other member data? (tags, merge fields, etc.)
- [ ] Should the module handle any other Mailchimp operations in the future?

### 11. Logging & Monitoring
- [ ] Should the module log all status checks?
- [ ] Any specific logging requirements?

## Development Preferences

### 12. Code Style
- [ ] Any specific PHP coding standards to follow?
- [ ] Preference for:
  - [ ] Dependency injection vs direct instantiation
  - [ ] Async/promises vs synchronous API calls

### 13. Testing
- [ ] Do you want me to include:
  - [ ] Unit tests
  - [ ] Integration tests
  - [ ] Manual testing instructions

### 14. Documentation
- [ ] Should I create:
  - [ ] README for the module
  - [ ] Inline code documentation
  - [ ] Setup/installation guide

## Additional Context

### 15. Timeline & Dependencies
- [ ] Any deadline or urgency for this feature?
- [ ] Are there any other systems/features this needs to integrate with?
- [ ] Any accessibility requirements (ARIA labels, keyboard navigation)?

### 16. Business Logic
- [ ] Are there any other conditions that affect whether someone can subscribe? (geographic restrictions, user types, etc.)
- [ ] Should unsubscribed users see why they were unsubscribed? (if Mailchimp provides this)

Please review these questions and provide answers. Once I have your responses, I'll update this document with any additional clarifying questions if needed, then provide a detailed implementation plan.