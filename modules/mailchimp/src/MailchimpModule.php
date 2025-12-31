<?php
namespace modules\mailchimp;

use Craft;
use yii\base\Module;

/**
 * Mailchimp module
 */
class MailchimpModule extends Module
{
    /**
     * @inheritdoc
     */
    public function init()
    {
        parent::init();

        // Register services
        $this->setComponents([
            'api' => [
                'class' => services\ApiService::class,
            ],
        ]);

        Craft::$app->getLog()->getLogger()->info(
            'Mailchimp module loaded',
            __METHOD__
        );
    }
}