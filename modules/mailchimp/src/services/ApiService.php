<?php
namespace modules\mailchimp\services;

use Craft;
use yii\base\Component;
use craft\helpers\App;
use craft\helpers\Json;

/**
 * Mailchimp API wrapper service
 */
class ApiService extends Component
{
    /**
     * @var string|null The API key
     */
    private ?string $_apiKey = null;

    /**
     * @var string|null The server prefix (data center)
     */
    private ?string $_serverPrefix = null;

    /**
     * @var \GuzzleHttp\Client|null The HTTP client
     */
    private ?\GuzzleHttp\Client $_client = null;

    /**
     * @inheritdoc
     */
    public function init()
    {
        parent::init();

        $this->_apiKey = App::env('MAILCHIMP_API_KEY');
        $this->_serverPrefix = $this->_getServerPrefix();
    }

    /**
     * Make a request to the Mailchimp API
     */
    public function request(string $method, string $endpoint, array $params = []): array
    {
        if (!$this->_apiKey) {
            return [
                'success' => false,
                'error' => 'Mailchimp API key not configured',
                'code' => 500
            ];
        }

        try {
            $client = $this->_getClient();
            
            $options = [
                'auth' => ['anystring', $this->_apiKey],
                'headers' => [
                    'Accept' => 'application/json',
                    'Content-Type' => 'application/json',
                ],
            ];

            // Add query params for GET requests, body for others
            if ($method === 'GET' && !empty($params)) {
                $options['query'] = $params;
            } elseif (!empty($params)) {
                $options['body'] = Json::encode($params);
            }

            $response = $client->request($method, ltrim($endpoint, '/'), $options);
            
            $body = (string)$response->getBody();
            $data = Json::decode($body);

            return [
                'success' => true,
                'data' => $data,
                'status' => $response->getStatusCode()
            ];

        } catch (\GuzzleHttp\Exception\ClientException $e) {
            $response = $e->getResponse();
            $body = (string)$response->getBody();
            
            try {
                $error = Json::decode($body);
            } catch (\Exception $jsonException) {
                $error = ['detail' => $body];
            }

            return [
                'success' => false,
                'error' => $error,
                'code' => $response->getStatusCode()
            ];

        } catch (\Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage(),
                'code' => 500
            ];
        }
    }

    /**
     * GET request
     */
    public function get(string $endpoint, array $params = []): array
    {
        return $this->request('GET', $endpoint, $params);
    }

    /**
     * POST request
     */
    public function post(string $endpoint, array $data = []): array
    {
        return $this->request('POST', $endpoint, $data);
    }

    /**
     * PATCH request
     */
    public function patch(string $endpoint, array $data = []): array
    {
        return $this->request('PATCH', $endpoint, $data);
    }

    /**
     * PUT request
     */
    public function put(string $endpoint, array $data = []): array
    {
        return $this->request('PUT', $endpoint, $data);
    }

    /**
     * DELETE request
     */
    public function delete(string $endpoint): array
    {
        return $this->request('DELETE', $endpoint);
    }

    /**
     * Get the Guzzle client
     */
    private function _getClient(): \GuzzleHttp\Client
    {
        if ($this->_client === null) {
            $this->_client = Craft::createGuzzleClient([
                'base_uri' => "https://{$this->_serverPrefix}.api.mailchimp.com/3.0/",
                'timeout' => 120,
            ]);
        }

        return $this->_client;
    }

    /**
     * Extract server prefix from API key or use configured value
     */
    private function _getServerPrefix(): string
    {
        // First try to extract from API key
        if ($this->_apiKey && strpos($this->_apiKey, '-') !== false) {
            $parts = explode('-', $this->_apiKey);
            if (count($parts) === 2) {
                return $parts[1];
            }
        }

        // Fall back to configured value
        return App::env('MAILCHIMP_SERVER_PREFIX') ?: 'us1';
    }

    /**
     * Get the signup URL for a list
     */
    public function getListSignupUrl(string $listId): ?string
    {
        $response = $this->get("/lists/{$listId}");
        
        if ($response['success'] && !empty($response['data']['subscribe_url_long'])) {
            return $response['data']['subscribe_url_long'];
        }
        
        // Fall back to environment variable
        return App::env('MAILCHIMP_SIGNUP_URL');
    }
}