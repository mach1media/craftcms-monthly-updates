/**
 * Mailchimp API JavaScript wrapper for Craft CMS
 * Provides abstracted functionality for making AJAX requests to the Mailchimp module
 */
class MailchimpAPI {
    constructor(options = {}) {
        this.endpoint = options.endpoint || '/actions/mailchimp/api/request';
        this.csrfTokenName = options.csrfTokenName || 'CRAFT_CSRF_TOKEN';
        this.csrfTokenValue = options.csrfTokenValue || '';
        this.listId = options.listId || '';
        this.debug = options.debug || false;
        this.onError = options.onError || this.defaultErrorHandler;
        this.onSuccess = options.onSuccess || null;
    }

    /**
     * Make a request to the Mailchimp API
     */
    async request(method, endpoint, params = {}) {
        const requestData = {
            method: method,
            endpoint: endpoint,
            params: params,
            [this.csrfTokenName]: this.csrfTokenValue
        };

        if (this.debug) {
            console.log('Mailchimp API Request:', requestData);
        }

        try {
            const response = await fetch(this.endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest'
                },
                body: JSON.stringify(requestData)
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const result = await response.json();

            if (this.debug) {
                console.log('Mailchimp API Response:', result);
            }

            if (result.success && this.onSuccess) {
                this.onSuccess(result);
            } else if (!result.success && this.onError) {
                this.onError(result);
            }

            return result;

        } catch (error) {
            const errorResult = {
                success: false,
                error: error.message,
                code: 500
            };

            if (this.debug) {
                console.error('Mailchimp API Error:', error);
            }

            if (this.onError) {
                this.onError(errorResult);
            }

            return errorResult;
        }
    }

    /**
     * MD5 hash function for email addresses
     */
    md5(string) {
        if (typeof CryptoJS !== 'undefined' && CryptoJS.MD5) {
            return CryptoJS.MD5(string.toLowerCase()).toString();
        }
        
        // Fallback warning if CryptoJS is not available
        console.warn('CryptoJS not available. Email hashing may not work correctly.');
        return string.toLowerCase();
    }

    /**
     * Check if an email address is subscribed to the list
     */
    async checkSubscription(email) {
        if (!email) {
            throw new Error('Email address is required');
        }

        const subscriberHash = this.md5(email);
        const endpoint = `/lists/${this.listId}/members/${subscriberHash}`;
        
        return await this.request('GET', endpoint);
    }

    /**
     * Get all members of the list
     */
    async getMembers(params = {}) {
        const endpoint = `/lists/${this.listId}/members`;
        return await this.request('GET', endpoint, params);
    }

    /**
     * Get specific list information
     */
    async getList(listId = null) {
        const id = listId || this.listId;
        const endpoint = `/lists/${id}`;
        return await this.request('GET', endpoint);
    }

    /**
     * Get all lists
     */
    async getLists() {
        return await this.request('GET', '/lists');
    }

    /**
     * Add or update a member
     */
    async addOrUpdateMember(email, data = {}) {
        if (!email) {
            throw new Error('Email address is required');
        }

        const subscriberHash = this.md5(email);
        const endpoint = `/lists/${this.listId}/members/${subscriberHash}`;
        
        const memberData = {
            email_address: email,
            status: 'subscribed',
            ...data
        };

        return await this.request('PUT', endpoint, memberData);
    }

    /**
     * Unsubscribe a member
     */
    async unsubscribeMember(email) {
        return await this.addOrUpdateMember(email, { status: 'unsubscribed' });
    }

    /**
     * Subscribe a member
     */
    async subscribeMember(email, mergeFields = {}) {
        const data = { status: 'subscribed' };
        
        if (Object.keys(mergeFields).length > 0) {
            data.merge_fields = mergeFields;
        }

        return await this.addOrUpdateMember(email, data);
    }

    /**
     * Get subscription status in a user-friendly format
     */
    async getSubscriptionStatus(email) {
        try {
            const response = await this.checkSubscription(email);
            
            if (response.success) {
                return {
                    found: true,
                    status: response.data.status,
                    email: response.data.email_address,
                    subscribed: response.data.status === 'subscribed',
                    unsubscribed: response.data.status === 'unsubscribed',
                    pending: response.data.status === 'pending',
                    cleaned: response.data.status === 'cleaned',
                    data: response.data
                };
            } else if (response.code === 404) {
                return {
                    found: false,
                    status: 'not_found',
                    email: email,
                    subscribed: false,
                    unsubscribed: false,
                    pending: false,
                    cleaned: false,
                    data: null
                };
            } else {
                throw new Error(response.error?.detail || 'Unknown error');
            }
        } catch (error) {
            throw error;
        }
    }

    /**
     * Default error handler
     */
    defaultErrorHandler(error) {
        console.error('Mailchimp API Error:', error);
    }

    /**
     * Validate email format
     */
    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    /**
     * Check if email domain is blocked (international TLDs)
     */
    isDomainBlocked(email) {
        const blockedTlds = ['.cn', '.ru', '.tk', '.ml', '.ga', '.cf'];
        const domain = email.toLowerCase();
        return blockedTlds.some(tld => domain.endsWith(tld));
    }

    /**
     * Validate email for subscription
     */
    validateEmail(email) {
        if (!email) {
            return { valid: false, error: 'Email address is required' };
        }

        if (!this.isValidEmail(email)) {
            return { valid: false, error: 'Please enter a valid email address' };
        }

        if (this.isDomainBlocked(email)) {
            return { valid: false, error: 'Sorry, this domain is not part of our target audience.' };
        }

        return { valid: true };
    }
}

// Export for use in other files
if (typeof module !== 'undefined' && module.exports) {
    module.exports = MailchimpAPI;
}