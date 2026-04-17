<?php
/**
 * Linkfield Migration Controller
 *
 * Migrates sebastianlenz/linkfield to native Craft 5 Link field.
 *
 * Usage:
 *   ddev craft my-module/linkfield/analyze     - Analyze current linkfield usage
 *   ddev craft my-module/linkfield/migrate     - Run full migration
 *   ddev craft my-module/linkfield/migrate-data - Migrate data only (after field type change)
 */

namespace modules\console\controllers;

use Craft;
use craft\console\Controller;
use craft\db\Query;
use craft\helpers\Console;
use craft\helpers\Db;
use craft\helpers\Json;
use yii\console\ExitCode;

class LinkfieldController extends Controller
{
    /**
     * Analyze current linkfield usage
     */
    public function actionAnalyze(): int
    {
        $this->stdout("Analyzing linkfield usage...\n\n", Console::FG_CYAN);

        // Get all linkfield fields
        $fields = (new Query())
            ->select(['id', 'handle', 'name', 'settings'])
            ->from('{{%fields}}')
            ->where(['type' => 'lenz\\linkfield\\fields\\LinkField'])
            ->all();

        $this->stdout("Found " . count($fields) . " linkfield fields:\n", Console::FG_GREEN);
        foreach ($fields as $field) {
            $this->stdout("  - {$field['handle']} (ID: {$field['id']}, Name: {$field['name']})\n");
        }

        // Count data by type
        $this->stdout("\nData breakdown by type:\n", Console::FG_CYAN);
        $typeCounts = (new Query())
            ->select(['type', 'COUNT(*) as count'])
            ->from('{{%lenz_linkfield}}')
            ->groupBy('type')
            ->all();

        foreach ($typeCounts as $row) {
            $type = $row['type'] ?: '(empty)';
            $this->stdout("  - {$type}: {$row['count']} records\n");
        }

        // Count total records
        $total = (new Query())
            ->from('{{%lenz_linkfield}}')
            ->count();
        $this->stdout("\nTotal linkfield records: {$total}\n", Console::FG_GREEN);

        return ExitCode::OK;
    }

    /**
     * Migrate linkfield data to native Link field format
     *
     * This assumes field types have already been changed in project config.
     */
    public function actionMigrateData(): int
    {
        $this->stdout("Starting linkfield data migration...\n\n", Console::FG_CYAN);

        // Get field mappings (fieldId => handle)
        $fields = (new Query())
            ->select(['id', 'handle', 'uid'])
            ->from('{{%fields}}')
            ->where(['type' => 'craft\\fields\\Link'])
            ->all();

        if (empty($fields)) {
            $this->stdout("No native Link fields found. Have you updated the field types in project config?\n", Console::FG_RED);
            return ExitCode::UNSPECIFIED_ERROR;
        }

        $fieldMap = [];
        foreach ($fields as $field) {
            $fieldMap[$field['id']] = $field['handle'];
        }

        $this->stdout("Found " . count($fields) . " native Link fields to migrate data for.\n\n");

        // Get all linkfield data
        $linkfieldData = (new Query())
            ->select('*')
            ->from('{{%lenz_linkfield}}')
            ->where(['not', ['type' => null]])
            ->andWhere(['not', ['type' => '']])
            ->all();

        $this->stdout("Processing " . count($linkfieldData) . " linkfield records...\n\n");

        $migrated = 0;
        $skipped = 0;
        $errors = 0;

        foreach ($linkfieldData as $row) {
            $fieldId = $row['fieldId'];
            $elementId = $row['elementId'];
            $siteId = $row['siteId'];

            if (!isset($fieldMap[$fieldId])) {
                $skipped++;
                continue;
            }

            $handle = $fieldMap[$fieldId];
            $linkData = $this->convertToNativeFormat($row);

            if ($linkData === null) {
                $skipped++;
                continue;
            }

            try {
                // Get current content
                $content = (new Query())
                    ->select(['content'])
                    ->from('{{%elements_sites}}')
                    ->where([
                        'elementId' => $elementId,
                        'siteId' => $siteId,
                    ])
                    ->scalar();

                $contentArray = $content ? Json::decode($content) : [];
                $contentArray[$handle] = $linkData;

                // Update content
                Craft::$app->db->createCommand()
                    ->update('{{%elements_sites}}', [
                        'content' => Json::encode($contentArray),
                    ], [
                        'elementId' => $elementId,
                        'siteId' => $siteId,
                    ])
                    ->execute();

                $migrated++;

                if ($migrated % 100 === 0) {
                    $this->stdout("  Migrated {$migrated} records...\n");
                }
            } catch (\Exception $e) {
                $errors++;
                $this->stdout("  Error migrating element {$elementId}: {$e->getMessage()}\n", Console::FG_RED);
            }
        }

        $this->stdout("\n");
        $this->stdout("Migration complete!\n", Console::FG_GREEN);
        $this->stdout("  Migrated: {$migrated}\n");
        $this->stdout("  Skipped: {$skipped}\n");
        $this->stdout("  Errors: {$errors}\n");

        return ExitCode::OK;
    }

    /**
     * Convert linkfield data to native Link field format
     */
    private function convertToNativeFormat(array $row): ?array
    {
        $type = $row['type'];
        $linkedUrl = $row['linkedUrl'];
        $linkedId = $row['linkedId'];
        $linkedSiteId = $row['linkedSiteId'];
        $linkedTitle = $row['linkedTitle'];
        $payload = $row['payload'] ? Json::decode($row['payload']) : [];

        // Build native link data structure
        $linkData = [];

        switch ($type) {
            case 'entry':
                if (!$linkedId) {
                    return null;
                }
                $linkData = [
                    'type' => 'entry',
                    'value' => (int)$linkedId,
                ];
                break;

            case 'asset':
                if (!$linkedId) {
                    return null;
                }
                $linkData = [
                    'type' => 'asset',
                    'value' => (int)$linkedId,
                ];
                break;

            case 'url':
            case 'custom':
                if (!$linkedUrl || $linkedUrl === '#') {
                    return null;
                }
                $linkData = [
                    'type' => 'url',
                    'value' => $linkedUrl,
                ];
                break;

            case 'email':
                if (!$linkedUrl) {
                    return null;
                }
                $linkData = [
                    'type' => 'email',
                    'value' => str_replace('mailto:', '', $linkedUrl),
                ];
                break;

            case 'tel':
                if (!$linkedUrl) {
                    return null;
                }
                $linkData = [
                    'type' => 'phone',
                    'value' => str_replace('tel:', '', $linkedUrl),
                ];
                break;

            default:
                return null;
        }

        // Add label if set (check both linkedTitle and payload.customText)
        if ($linkedTitle) {
            $linkData['label'] = $linkedTitle;
        } elseif (isset($payload['customText']) && $payload['customText']) {
            $linkData['label'] = $payload['customText'];
        }

        // Add target if set in payload
        if (isset($payload['target']) && $payload['target']) {
            $linkData['target'] = $payload['target'];
        }

        return $linkData;
    }

    /**
     * Fix double-encoded content and add missing labels
     */
    public function actionFixMigration(): int
    {
        $this->stdout("Fixing linkfield migration issues...\n\n", Console::FG_CYAN);

        // Get field mappings (fieldId => handle)
        $fields = (new Query())
            ->select(['id', 'handle'])
            ->from('{{%fields}}')
            ->where(['type' => 'craft\\fields\\Link'])
            ->all();

        $fieldMap = [];
        foreach ($fields as $field) {
            $fieldMap[$field['id']] = $field['handle'];
        }

        // Get all linkfield data
        $linkfieldData = (new Query())
            ->select('*')
            ->from('{{%lenz_linkfield}}')
            ->where(['not', ['type' => null]])
            ->andWhere(['not', ['type' => '']])
            ->all();

        $this->stdout("Processing " . count($linkfieldData) . " linkfield records...\n\n");

        $fixed = 0;
        $skipped = 0;
        $errors = 0;

        foreach ($linkfieldData as $row) {
            $fieldId = $row['fieldId'];
            $elementId = $row['elementId'];
            $siteId = $row['siteId'];

            if (!isset($fieldMap[$fieldId])) {
                $skipped++;
                continue;
            }

            $handle = $fieldMap[$fieldId];
            $linkData = $this->convertToNativeFormat($row);

            if ($linkData === null) {
                $skipped++;
                continue;
            }

            try {
                // Get current raw content from DB
                $content = (new Query())
                    ->select(['content'])
                    ->from('{{%elements_sites}}')
                    ->where([
                        'elementId' => $elementId,
                        'siteId' => $siteId,
                    ])
                    ->scalar();

                // Decode content - handle double-encoding
                $contentArray = [];
                if ($content) {
                    // First decode
                    $decoded = Json::decode($content);
                    // If result is still a string, decode again (was double-encoded)
                    if (is_string($decoded)) {
                        $decoded = Json::decode($decoded);
                    }
                    if (is_array($decoded)) {
                        $contentArray = $decoded;
                    }
                }

                // Set the link data
                $contentArray[$handle] = $linkData;

                // Store as raw JSON string using direct SQL to avoid any auto-encoding
                $jsonContent = Json::encode($contentArray);

                Craft::$app->db->createCommand()
                    ->update('{{%elements_sites}}', [
                        'content' => new \yii\db\Expression(':content', [':content' => $jsonContent]),
                    ], [
                        'elementId' => $elementId,
                        'siteId' => $siteId,
                    ])
                    ->execute();

                $fixed++;

                if ($fixed % 100 === 0) {
                    $this->stdout("  Fixed {$fixed} records...\n");
                }
            } catch (\Exception $e) {
                $errors++;
                $this->stdout("  Error fixing element {$elementId}: {$e->getMessage()}\n", Console::FG_RED);
            }
        }

        $this->stdout("\n");
        $this->stdout("Fix complete!\n", Console::FG_GREEN);
        $this->stdout("  Fixed: {$fixed}\n");
        $this->stdout("  Skipped: {$skipped}\n");
        $this->stdout("  Errors: {$errors}\n");

        return ExitCode::OK;
    }

    /**
     * Show field config changes needed for project config
     */
    public function actionShowConfigChanges(): int
    {
        $this->stdout("Field config changes needed for native Link field:\n\n", Console::FG_CYAN);

        $this->stdout("For each linkfield in config/project/fields/*.yaml:\n\n");
        $this->stdout("1. Change 'type' from:\n");
        $this->stdout("   type: lenz\\linkfield\\fields\\LinkField\n", Console::FG_RED);
        $this->stdout("   to:\n");
        $this->stdout("   type: craft\\fields\\Link\n", Console::FG_GREEN);

        $this->stdout("\n2. Replace 'settings' block. Example:\n");
        $this->stdout("   Old settings:\n", Console::FG_RED);
        $this->stdout("   settings:\n");
        $this->stdout("     allowCustomText: true\n");
        $this->stdout("     allowTarget: true\n");
        $this->stdout("     typeSettings:\n");
        $this->stdout("       entry:\n");
        $this->stdout("         enabled: true\n");
        $this->stdout("         sources: '*'\n");
        $this->stdout("       ...\n");

        $this->stdout("\n   New settings:\n", Console::FG_GREEN);
        $this->stdout("   settings:\n");
        $this->stdout("     types:\n");
        $this->stdout("       - entry\n");
        $this->stdout("       - asset\n");
        $this->stdout("       - url\n");
        $this->stdout("       - email\n");
        $this->stdout("       - phone\n");
        $this->stdout("     showLabel: true\n");
        $this->stdout("     showTarget: true\n");

        return ExitCode::OK;
    }
}
