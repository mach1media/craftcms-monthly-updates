#!/bin/bash

# Unit tests for sync functions (sync-db.sh, sync-assets.sh, sync-directories.sh)

# Get script directory and source test framework
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../test-framework.sh"

# Source the helpers functions
source "$SCRIPT_DIR/../../scripts/helpers.sh"

test_sync_db_config_parsing() {
    test_suite "Sync Functions - Database Sync Config"
    
    setup_test_environment
    
    # Create test config for database sync
    local test_config="$TEST_DIR/test_config.yml"
    create_mock_config "$test_config" "
ssh_host: db.example.com
ssh_user: dbuser
ssh_port: 22
remote_project_dir: /var/www/project
backup_dir: storage/backups
production_url: https://example.com
"
    
    export CONFIG_FILE="$test_config"
    
    test_case "Database sync config values are parsed"
    
    # Parse config values like sync-db.sh does
    SSH_HOST=$(get_config "ssh_host")
    SSH_USER=$(get_config "ssh_user")
    SSH_PORT=$(get_config "ssh_port" "22")
    REMOTE_PROJECT_DIR=$(get_config "remote_project_dir")
    BACKUP_DIR=$(get_config "backup_dir")
    PRODUCTION_URL=$(get_config "production_url")
    
    assert_equals "db.example.com" "$SSH_HOST" "SSH_HOST should be parsed"
    assert_equals "dbuser" "$SSH_USER" "SSH_USER should be parsed"
    assert_equals "22" "$SSH_PORT" "SSH_PORT should default to 22"
    assert_equals "/var/www/project" "$REMOTE_PROJECT_DIR" "REMOTE_PROJECT_DIR should be parsed"
    assert_equals "storage/backups" "$BACKUP_DIR" "BACKUP_DIR should be parsed"
    assert_equals "https://example.com" "$PRODUCTION_URL" "PRODUCTION_URL should be parsed"
    
    teardown_test_environment
}

test_backup_file_naming() {
    test_suite "Sync Functions - Backup File Naming"
    
    setup_test_environment
    
    # Mock function to generate backup filename like sync-db.sh
    generate_backup_filename() {
        local production_url="$1"
        local date_suffix="$2"
        
        # Extract domain from URL - fix the regex
        local domain=$(echo "$production_url" | sed 's|^https\?://||' | sed 's|/.*$||' | sed 's|:.*$||')
        echo "${domain}_${date_suffix}.sql"
    }
    
    test_case "Backup filename generation from URL"
    
    result=$(generate_backup_filename "https://example.com" "20250104")
    assert_equals "example.com_20250104.sql" "$result" "Should generate filename from https URL"
    
    result=$(generate_backup_filename "http://test.local" "20250104")
    assert_equals "test.local_20250104.sql" "$result" "Should generate filename from http URL"
    
    result=$(generate_backup_filename "https://sub.example.com:8080/path" "20250104")
    assert_equals "sub.example.com_20250104.sql" "$result" "Should extract domain from complex URL"
    
    teardown_test_environment
}

test_asset_storage_type_handling() {
    test_suite "Sync Functions - Asset Storage Type Handling"
    
    setup_test_environment
    
    # Mock function to check if asset sync should be skipped
    should_skip_asset_sync() {
        local asset_storage_type="$1"
        
        case "$asset_storage_type" in
            "local")
                return 1  # Don't skip - need to sync
                ;;
            "s3"|"spaces"|"other")
                return 0  # Skip - cloud storage
                ;;
            *)
                return 1  # Default - don't skip
                ;;
        esac
    }
    
    test_case "Asset sync decisions based on storage type"
    
    should_skip_asset_sync "local"
    local local_result=$?
    assert_equals "1" "$local_result" "Should not skip sync for local storage"
    
    should_skip_asset_sync "s3"
    local s3_result=$?
    assert_equals "0" "$s3_result" "Should skip sync for S3 storage"
    
    should_skip_asset_sync "spaces"
    local spaces_result=$?
    assert_equals "0" "$spaces_result" "Should skip sync for Spaces storage"
    
    should_skip_asset_sync "other"
    local other_result=$?
    assert_equals "0" "$other_result" "Should skip sync for other cloud storage"
    
    should_skip_asset_sync ""
    local empty_result=$?
    assert_equals "1" "$empty_result" "Should not skip sync for empty/unknown storage type"
    
    teardown_test_environment
}

test_directory_sync_parsing() {
    test_suite "Sync Functions - Directory Sync Parsing"
    
    setup_test_environment
    
    # Mock function to parse additional sync directories
    parse_sync_directories() {
        local additional_sync_dirs="$1"
        
        if [ -z "$additional_sync_dirs" ]; then
            return 0
        fi
        
        # Split comma-separated directories and process each
        IFS=',' read -ra DIRS <<< "$additional_sync_dirs"
        for dir in "${DIRS[@]}"; do
            # Trim whitespace
            dir=$(echo "$dir" | xargs)
            
            if [ -n "$dir" ]; then
                echo "SYNC_DIR:$dir"
            fi
        done
    }
    
    test_case "Additional directories parsing"
    
    result=$(parse_sync_directories "")
    assert_equals "" "$result" "Should handle empty directories list"
    
    result=$(parse_sync_directories "storage/runtime")
    assert_equals "SYNC_DIR:storage/runtime" "$result" "Should parse single directory"
    
    result=$(parse_sync_directories "storage/runtime,config/project,web/cpresources")
    expected="SYNC_DIR:storage/runtime
SYNC_DIR:config/project
SYNC_DIR:web/cpresources"
    assert_equals "$expected" "$result" "Should parse multiple directories"
    
    result=$(parse_sync_directories " storage/runtime , config/project , web/cpresources ")
    expected="SYNC_DIR:storage/runtime
SYNC_DIR:config/project
SYNC_DIR:web/cpresources"
    assert_equals "$expected" "$result" "Should trim whitespace from directories"
    
    result=$(parse_sync_directories "dir1,,dir2")
    expected="SYNC_DIR:dir1
SYNC_DIR:dir2"
    assert_equals "$expected" "$result" "Should skip empty entries"
    
    teardown_test_environment
}

test_ftp_connection_string_building() {
    test_suite "Sync Functions - FTP Connection String Building"
    
    setup_test_environment
    
    # Mock function to build FTP connection strings
    build_ftp_connection() {
        local ftp_host="$1"
        local ftp_user="$2"
        local ftp_port="${3:-21}"
        
        echo "ftp://${ftp_user}@${ftp_host}:${ftp_port}"
    }
    
    test_case "FTP connection string construction"
    
    result=$(build_ftp_connection "ftp.example.com" "ftpuser")
    assert_equals "ftp://ftpuser@ftp.example.com:21" "$result" "Should build FTP string with default port"
    
    result=$(build_ftp_connection "ftp.example.com" "ftpuser" "2121")
    assert_equals "ftp://ftpuser@ftp.example.com:2121" "$result" "Should build FTP string with custom port"
    
    teardown_test_environment
}

test_backup_cleanup_logic() {
    test_suite "Sync Functions - Backup Cleanup Logic"
    
    setup_test_environment
    
    # Create mock backup files
    local backup_dir="$TEST_DIR/backups"
    mkdir -p "$backup_dir"
    
    # Create files with different ages (using touch with timestamps)
    touch -t 202501010000 "$backup_dir/old_backup_20250101.sql"
    touch -t 202501020000 "$backup_dir/older_backup_20250102.sql"
    touch -t 202501030000 "$backup_dir/recent_backup_20250103.sql"
    touch -t 202501040000 "$backup_dir/newest_backup_20250104.sql"
    
    # Mock cleanup function that keeps only N newest files
    cleanup_old_backups() {
        local backup_directory="$1"
        local keep_count="${2:-5}"
        
        # Find backup files and count them
        local backup_files=$(find "$backup_directory" -name "*.sql" -type f | wc -l | xargs)
        echo "FOUND_BACKUPS:$backup_files"
        
        if [ "$backup_files" -gt "$keep_count" ]; then
            # Would normally delete old files, just indicate what would be deleted
            local files_to_delete=$((backup_files - keep_count))
            echo "WOULD_DELETE:$files_to_delete"
        fi
    }
    
    test_case "Backup cleanup counting"
    
    result=$(cleanup_old_backups "$backup_dir" 5)
    assert_contains "FOUND_BACKUPS:4" "$result" "Should find 4 backup files"
    assert_not_contains "WOULD_DELETE" "$result" "Should not delete when under limit"
    
    # Add more files to trigger cleanup
    touch "$backup_dir/extra1.sql"
    touch "$backup_dir/extra2.sql"
    touch "$backup_dir/extra3.sql"
    
    result=$(cleanup_old_backups "$backup_dir" 5)
    assert_contains "FOUND_BACKUPS:7" "$result" "Should find 7 backup files"
    assert_contains "WOULD_DELETE:2" "$result" "Should delete 2 files to keep 5"
    
    teardown_test_environment
}

test_database_import_validation() {
    test_suite "Sync Functions - Database Import Validation"
    
    setup_test_environment
    
    # Mock function to validate database import files
    validate_sql_file() {
        local sql_file="$1"
        
        if [ ! -f "$sql_file" ]; then
            echo "FILE_NOT_FOUND"
            return 1
        fi
        
        # Check file size
        local file_size=$(stat -c%s "$sql_file" 2>/dev/null || stat -f%z "$sql_file" 2>/dev/null || echo "0")
        
        if [ "$file_size" -eq 0 ]; then
            echo "EMPTY_FILE"
            return 1
        fi
        
        if [ "$file_size" -lt 100 ]; then
            echo "TOO_SMALL"
            return 1
        fi
        
        # Check for SQL content
        if head -n 5 "$sql_file" | grep -q "CREATE\|INSERT\|DROP\|ALTER"; then
            echo "VALID_SQL"
            return 0
        else
            echo "INVALID_SQL"
            return 1
        fi
    }
    
    test_case "SQL file validation"
    
    # Test missing file
    result=$(validate_sql_file "/nonexistent/file.sql")
    assert_equals "FILE_NOT_FOUND" "$result" "Should detect missing file"
    
    # Test empty file
    local empty_file="$TEST_DIR/empty.sql"
    touch "$empty_file"
    result=$(validate_sql_file "$empty_file")
    assert_equals "EMPTY_FILE" "$result" "Should detect empty file"
    
    # Test too small file
    local small_file="$TEST_DIR/small.sql"
    echo "-- Small" > "$small_file"
    result=$(validate_sql_file "$small_file")
    assert_equals "TOO_SMALL" "$result" "Should detect too small file"
    
    # Test valid SQL file
    local valid_file="$TEST_DIR/valid.sql"
    cat > "$valid_file" << 'EOF'
-- Valid SQL backup
CREATE TABLE test (id INT PRIMARY KEY, name VARCHAR(255));
INSERT INTO test (id, name) VALUES (1, 'Test Data');
INSERT INTO test (id, name) VALUES (2, 'More Data');
-- End of backup
EOF
    
    result=$(validate_sql_file "$valid_file")
    assert_equals "VALID_SQL" "$result" "Should validate proper SQL file"
    
    teardown_test_environment
}

# Run all tests
main() {
    echo -e "${BLUE}Starting Sync Functions Unit Tests${NC}"
    
    test_sync_db_config_parsing
    test_backup_file_naming
    test_asset_storage_type_handling
    test_directory_sync_parsing
    test_ftp_connection_string_building
    test_backup_cleanup_logic
    test_database_import_validation
    
    test_summary
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi