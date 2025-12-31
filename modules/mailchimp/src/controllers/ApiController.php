<?php
namespace modules\mailchimp\controllers;

use Craft;
use craft\web\Controller;
use modules\mailchimp\MailchimpModule;
use yii\web\Response;

/**
 * API controller for Mailchimp module
 */
class ApiController extends Controller
{
    /**
     * @inheritdoc
     */
    protected array|bool|int $allowAnonymous = ['request'];

    /**
     * Handle API requests
     */
    public function actionRequest(): Response
    {
        $this->requirePostRequest();
        $this->requireAcceptsJson();

        $request = Craft::$app->getRequest();
        
        $method = $request->getParam('method', 'GET');
        $endpoint = $request->getParam('endpoint');
        $params = $request->getParam('params', []);

        if (!$endpoint) {
            return $this->asJson([
                'success' => false,
                'error' => 'Endpoint is required',
                'code' => 400
            ]);
        }

        // Validate HTTP method
        $allowedMethods = ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'];
        if (!in_array($method, $allowedMethods)) {
            return $this->asJson([
                'success' => false,
                'error' => 'Invalid HTTP method',
                'code' => 400
            ]);
        }

        /** @var MailchimpModule $module */
        $module = MailchimpModule::getInstance();
        
        // Simple rate limiting
        $cacheKey = 'mailchimp-rate-limit-' . Craft::$app->getRequest()->getUserIP();
        $requests = Craft::$app->getCache()->get($cacheKey) ?: 0;
        
        if ($requests >= 30) { // 30 requests per minute
            return $this->asJson([
                'success' => false,
                'error' => 'Rate limit exceeded. Please try again in a minute.',
                'code' => 429
            ]);
        }
        
        Craft::$app->getCache()->set($cacheKey, $requests + 1, 60);

        // Make the API request
        $response = $module->api->request($method, $endpoint, $params);

        return $this->asJson($response);
    }
}