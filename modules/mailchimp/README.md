# Mailchimp Module for Craft CMS

A thin wrapper module for the Mailchimp Marketing API v3 that provides transparent access to all Mailchimp endpoints.

## Installation

1. The module files should be placed in `modules/mailchimp/`

2. Add your Mailchimp credentials to `.env`:
   ```
   MAILCHIMP_API_KEY="your-api-key-here"
   MAILCHIMP_SERVER_PREFIX="us19"  # Optional - extracted from API key if not set
   MAILCHIMP_LIST_ID="your-list-id"
   MAILCHIMP_SIGNUP_URL="https://mailchi.mp/yourdomain/signup"
   ```

3. The module is already registered in `config/app.php`

## Usage

### From JavaScript/AJAX

The module provides a single endpoint that accepts any Mailchimp API request:

```javascript
// Check member subscription status
$.ajax({
    url: '/actions/mailchimp/api/request',
    method: 'POST',
    data: {
        method: 'GET',
        endpoint: '/lists/abc123/members/' + md5(email),
        [csrfTokenName]: csrfTokenValue
    }
});

// Add or update member
$.ajax({
    url: '/actions/mailchimp/api/request',
    method: 'POST',
    data: {
        method: 'PUT',
        endpoint: '/lists/abc123/members/' + md5(email),
        params: {
            email_address: email,
            status: 'subscribed'
        },
        [csrfTokenName]: csrfTokenValue
    }
});
```

### From PHP/Twig

```php
// Get the module
$module = \modules\mailchimp\MailchimpModule::getInstance();

// Make API calls
$response = $module->api->get('/lists');
$response = $module->api->post('/lists/{list_id}/members', [
    'email_address' => 'user@example.com',
    'status' => 'subscribed'
]);
```

## API Reference

The module supports all Mailchimp Marketing API v3 endpoints. Refer to the official documentation:
https://mailchimp.com/developer/marketing/api/

### Response Format

All responses follow this structure:
```json
{
    "success": true,
    "data": { ... },  // Mailchimp API response
    "status": 200
}
```

Error responses:
```json
{
    "success": false,
    "error": { ... },  // Mailchimp error details
    "code": 404
}
```

## Testing

Visit `/mailchimp` to access the test interface where you can:
- Select HTTP methods
- Choose or enter custom endpoints
- Test member lookups with automatic MD5 hashing
- Send custom parameters

## Security

- CSRF protection enabled on all endpoints
- Rate limiting: 30 requests per minute per IP
- Email validation available for frontend forms

## Uninstallation

1. Remove module registration from `config/app.php`
2. Delete the `modules/mailchimp` directory
3. Remove Mailchimp environment variables from `.env`