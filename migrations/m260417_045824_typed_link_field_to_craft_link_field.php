<?php

namespace craft\contentmigrations;

use Craft;
use craft\base\ElementInterface;
use craft\base\FieldInterface;
use craft\db\Migration;
use craft\db\Query;
use craft\fields\Link;
use craft\helpers\Db;
use craft\helpers\Json;
use craft\helpers\App;

/**
 * m260417_045824_typed_link_field_to_craft_link_field migration.
 *
 * Migrates sebastianlenz/linkfield to native Craft 5 Link field.
 * Based on: https://github.com/sebastian-lenz/craft-linkfield/issues/286#issuecomment-2704530000
 */
class m260417_045824_typed_link_field_to_craft_link_field extends Migration
{
    public array $allowedTypes = [
        'asset',
        'category',
        'email',
        'entry',
        'url',
        'tel',
        'custom',
    ];

    /**
     * @inheritdoc
     * @throws \JsonException
     */
    public function safeUp(): bool
    {
        App::maxPowerCaptain();

        // Get all Lenz LinkField fields
        $fields = (new Query())
            ->from('{{%fields}}')
            ->where(['type' => 'typedlinkfield\fields\LinkField'])
            ->orWhere(['type' => 'lenz\linkfield\fields\LinkField'])
            ->all();

        // Loop through each field and migrate settings in this pass
        foreach ($fields as $field) {
            echo "Preparing to migrate field '{$field['handle']}' ({$field['uid']}) settings.\n";

            // Allow everything by default:
            $nativeFieldSettings = [
                'advancedFields' => [
                    'target'
                ],
                'fullGraphqlData' => true,
                'maxLength' => 255,
                'showLabelField' => true,
                'typeSettings' => [
                    'entry' => [
                        'sources' => '*'
                    ],
                    'url' => [
                        'allowRootRelativeUrls' => '1',
                        'allowAnchors' => '1'
                    ],
                    'asset' => [
                        'sources' => '*',
                        'allowedKinds' => '*',
                        'showUnpermittedVolumes' => '',
                        'showUnpermittedFiles' => ''
                    ],
                    'category' => [
                        'sources' => '*'
                    ]
                ],
                'types' => [
                    'entry',
                    'url',
                    'asset',
                    'category',
                    'email',
                    'phone'
                ],
            ];

            // Update the type and settings for typedlinkfield fields to native Craft Link field equivalents
            $this->update(
                '{{%fields}}',
                [
                    'type' => Link::class,
                    'settings' => json_encode($nativeFieldSettings, JSON_THROW_ON_ERROR)
                ],
                ['uid' => $field['uid']]
            );

            echo "> Field '{$field['handle']}' settings migrated.\n\n";
        }

        // Clear caches so Craft picks up the field type changes
        Craft::$app->getCache()->flush();

        // now iterate through the content and migrate it using the new field settings
        $fields = (new Query())
            ->from('{{%fields}}')
            ->where(['type' => Link::class])
            ->all();

        foreach ($fields as $field) {
            // Migrate content
            echo "Preparing to migrate field '{$field['handle']}' ({$field['uid']}) content.\n";
            $fieldModel = Craft::$app->getFields()->getFieldById($field['id']);

            if ($fieldModel) {
                // Get content from the lenz_linkfield table
                $contentRows = (new Query())
                    ->select(['*'])
                    ->from('{{%lenz_linkfield}}')
                    ->where(['fieldId' => $fieldModel['id']])
                    ->all();

                if (count($contentRows) < 1) {
                    echo "> No content to migrate for field '{$field['handle']}'\n";
                    continue;
                }

                $migratedCount = 0;
                $skippedCount = 0;
                $errorCount = 0;

                // Migrate all content regardless of field context (global, matrix, etc.)
                foreach ($contentRows as $row) {
                    $settings = $this->convertLinkContent($fieldModel, $row);

                    $element = Craft::$app->getElements()->getElementById($row['elementId'], null, $row['siteId']);
                    if ($element) {
                        if ($settings) {
                            $newContent = $this->getElementContentForField($element, $fieldModel, $settings);

                            Db::update('{{%elements_sites}}', ['content' => $newContent], ['elementId' => $row['elementId'], 'siteId' => $row['siteId']]);

                            $migratedCount++;
                        } else {
                            if ($settings === null) {
                                $skippedCount++;
                            } else {
                                echo "    > Unable to convert content for element #{$row['elementId']}\n";
                                $errorCount++;
                            }
                        }
                    } else {
                        $skippedCount++;
                    }
                }

                echo "> Field '{$field['handle']}' content migrated: {$migratedCount} migrated, {$skippedCount} skipped, {$errorCount} errors.\n\n";
            }
        }

        return true;
    }

    /**
     * @inheritdoc
     */
    public function safeDown(): bool
    {
        echo "m260417_045824_typed_link_field_to_craft_link_field cannot be reverted.\n";
        return false;
    }

    public function convertLinkContent($field, array $settings): bool|array|null
    {
        $linkType = $settings['type'] ?? null;

        if (!$linkType) {
            return null;
        }

        if (!in_array($linkType, $this->allowedTypes)) {
            return false;
        }

        $advanced = Json::decode($settings['payload']);
        $linkValue = $settings['linkedUrl'] ?? null;
        $linkText = $advanced['customText'] ?? null;
        $linkSiteId = $settings['siteId'] ?? null;
        $linkId = $settings['linkedId'] ?? null;
        $linkTarget = $advanced['target'] ?? null;

        if (($linkType === 'entry' || $linkType === 'asset' || $linkType === 'category') && (!$linkId || !$linkSiteId)) {
            return false;
        }

        if ($linkType === 'entry') {
            $linkValue = "{entry:{$linkId}@{$linkSiteId}:url}";
        } elseif ($linkType === 'asset') {
            $linkValue = "{asset:{$linkId}@{$linkSiteId}:url}";
        } elseif ($linkType === 'category') {
            $linkValue = "{category:{$linkId}@{$linkSiteId}:url}";
        } elseif ($linkType === 'email') {
            $linkValue = 'mailto:' . $linkValue;
        } elseif ($linkType === 'tel') {
            $linkType = 'phone';
            $linkValue = 'tel:' . $linkValue;
        } elseif ($linkType === 'custom') {
            $linkType = 'url';
        }

        return [
            'value' => $linkValue,
            'type' => $linkType,
            'label' => $linkText,
            'target' => $linkTarget,
        ];
    }

    // From:
    // https://github.com/verbb/hyper/blob/craft-5/src/migrations/PluginContentMigration.php#L141
    protected function getElementContentForField(ElementInterface $element, FieldInterface $field, array $fieldValue): array
    {
        $fieldContent = [];

        // Get the field content as JSON, indexed by field layout element UID
        if ($fieldLayout = $element->getFieldLayout()) {
            foreach ($fieldLayout->getCustomFields() as $fieldLayoutField) {
                $sourceHandle = $fieldLayoutField->layoutElement?->getOriginalHandle() ?? $fieldLayoutField->handle;

                if ($field->handle === $sourceHandle) {
                    $fieldContent[$fieldLayoutField->layoutElement->uid] = $fieldValue;
                }
            }
        }

        // Fetch the current JSON content so we can merge in the new field content
        $oldContent = Json::decode((new Query())
            ->select(['content'])
            ->from('{{%elements_sites}}')
            ->where(['elementId' => $element->id, 'siteId' => $element->siteId])
            ->scalar() ?? '') ?? [];

        // Another sanity check just in cases where content is double encoded
        if (is_string($oldContent) && Json::isJsonObject($oldContent)) {
            $oldContent = Json::decode($oldContent);
        }

        return array_merge($oldContent, $fieldContent);
    }
}
