#!/bin/bash
# Mirror management operations library
# Functions for managing automatic mirror synchronization

function mirror_enable() {
    local REPO_NAME="$1"
    local SCHEDULE="0 */6 * * *"
    local TIMEOUT=600
    
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --schedule)
                SCHEDULE="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [ -z "$REPO_NAME" ]; then
        echo "Usage: repo mirror enable <repo-name> [--schedule CRON] [--timeout SECONDS]"
        echo ""
        echo "Examples:"
        echo "  repo mirror enable my-repo"
        echo "  repo mirror enable my-repo --schedule '0 2 * * *'"
        echo "  repo mirror enable my-repo --schedule '0 */12 * * *' --timeout 900"
        exit 1
    fi
    
    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    
    # Check if repo exists
    local REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"
    if [ ! -d "$REPO_PATH" ]; then
        echo "Error: Repository does not exist at $REPO_PATH"
        exit 1
    fi
    
    python3 /opt/cgit/bin/mirror-manager.py enable "$REPO_NAME" --schedule "$SCHEDULE" --timeout "$TIMEOUT"
}

function mirror_disable() {
    local REPO_NAME="$1"
    
    if [ -z "$REPO_NAME" ]; then
        echo "Usage: repo mirror disable <repo-name>"
        echo ""
        echo "Example:"
        echo "  repo mirror disable my-repo"
        exit 1
    fi
    
    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    
    python3 /opt/cgit/bin/mirror-manager.py disable "$REPO_NAME"
}

function mirror_list() {
    python3 /opt/cgit/bin/mirror-manager.py list "$@"
}

function mirror_status() {
    local REPO_NAME="$1"
    
    if [ -z "$REPO_NAME" ]; then
        echo "Usage: repo mirror status <repo-name>"
        echo ""
        echo "Example:"
        echo "  repo mirror status my-repo"
        exit 1
    fi
    
    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    
    python3 /opt/cgit/bin/mirror-manager.py get "$REPO_NAME"
}

function mirror_sync() {
    local REPO_NAME="$1"
    
    if [ -z "$REPO_NAME" ]; then
        echo "Usage: repo mirror sync <repo-name>"
        echo ""
        echo "Example:"
        echo "  repo mirror sync my-repo"
        exit 1
    fi
    
    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    local REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"
    
    if [ ! -d "$REPO_PATH" ]; then
        echo "Error: Repository does not exist at $REPO_PATH"
        exit 1
    fi
    
    echo "Syncing repository: $REPO_NAME"
    
    # Get timeout from config
    local TIMEOUT=$(python3 /opt/cgit/bin/mirror-manager.py get "$REPO_NAME" 2>/dev/null | grep -o '"timeout": [0-9]*' | grep -o '[0-9]*')
    TIMEOUT=${TIMEOUT:-600}
    
    local START_TIME=$(date +%s)
    
    if timeout "$TIMEOUT" su - git -c "cd '$REPO_PATH' && git remote update --prune" 2>&1; then
        local END_TIME=$(date +%s)
        local DURATION=$((END_TIME - START_TIME))
        echo ""
        echo "✓ Repository synced successfully! (${DURATION}s)"
        python3 /opt/cgit/bin/mirror-manager.py update-status "$REPO_NAME" success --duration "$DURATION"
    else
        local EXIT_CODE=$?
        local END_TIME=$(date +%s)
        local DURATION=$((END_TIME - START_TIME))
        
        if [ $EXIT_CODE -eq 124 ]; then
            echo ""
            echo "✗ Sync timeout after ${TIMEOUT}s"
            python3 /opt/cgit/bin/mirror-manager.py update-status "$REPO_NAME" timeout --error "Timeout after ${TIMEOUT}s"
        else
            echo ""
            echo "✗ Sync failed with exit code $EXIT_CODE"
            python3 /opt/cgit/bin/mirror-manager.py update-status "$REPO_NAME" failed --error "Exit code $EXIT_CODE"
        fi
        exit 1
    fi
    
    clear_cache
}

function mirror_sync_all() {
    echo "Syncing all enabled mirrors..."
    
    # Get list of enabled mirrors
    local MIRRORS=$(python3 /opt/cgit/bin/mirror-manager.py list --enabled-only 2>/dev/null | grep -oP '^\s+\K[^:]+(?=:)')
    
    if [ -z "$MIRRORS" ]; then
        echo "No enabled mirrors found"
        return 0
    fi
    
    local TOTAL=0
    local SUCCESS=0
    local FAILED=0
    
    for REPO in $MIRRORS; do
        TOTAL=$((TOTAL + 1))
        echo ""
        echo "[$TOTAL] Syncing $REPO..."
        
        if mirror_sync "$REPO" 2>&1; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done
    
    echo ""
    echo "======================================"
    echo "Sync completed: $TOTAL total, $SUCCESS success, $FAILED failed"
    echo "======================================"
}

function mirror_logs() {
    local REPO_NAME="$1"
    local LOG_FILE="/opt/cgit/data/logs/mirror-sync.log"
    
    if [ ! -f "$LOG_FILE" ]; then
        echo "No mirror sync logs found"
        return 0
    fi
    
    if [ -n "$REPO_NAME" ]; then
        validate_repo_name "$REPO_NAME"
        REPO_NAME="${REPO_NAME%.git}"
        echo "Mirror sync logs for: $REPO_NAME"
        echo "======================================"
        grep "$REPO_NAME" "$LOG_FILE" 2>/dev/null || echo "No logs found for $REPO_NAME"
    else
        echo "Recent mirror sync logs:"
        echo "======================================"
        tail -n 50 "$LOG_FILE"
    fi
}

function mirror_command() {
    local subcommand="$1"
    
    # Show help if no subcommand provided
    if [ -z "$subcommand" ]; then
        echo "Mirror auto-sync commands:"
        echo ""
        echo "Usage: repo mirror <subcommand> [args...]"
        echo ""
        echo "Subcommands:"
        echo "  enable <repo> [--schedule CRON] [--timeout SECONDS]"
        echo "                                Enable auto-sync for repository"
        echo "  disable <repo>                Disable auto-sync"
        echo "  list [--enabled-only]         List mirrored repositories"
        echo "  status <repo>                 Show mirror sync status"
        echo "  sync <repo>                   Manually sync repository now"
        echo "  sync-all                      Sync all enabled mirrors"
        echo "  logs [repo]                   View sync logs"
        echo ""
        echo "Examples:"
        echo "  repo mirror enable my-repo"
        echo "  repo mirror enable my-repo --schedule '0 2 * * *'"
        echo "  repo mirror sync my-repo"
        echo "  repo mirror list"
        return 0
    fi
    
    shift
    
    case "$subcommand" in
        enable)
            mirror_enable "$@"
            ;;
        disable)
            mirror_disable "$@"
            ;;
        list)
            mirror_list "$@"
            ;;
        status)
            mirror_status "$@"
            ;;
        sync)
            mirror_sync "$@"
            ;;
        sync-all)
            mirror_sync_all "$@"
            ;;
        logs)
            mirror_logs "$@"
            ;;
        *)
            echo "Error: Unknown mirror subcommand '$subcommand'"
            echo ""
            echo "Available mirror subcommands:"
            echo "  enable <repo> [--schedule CRON] [--timeout SECONDS]"
            echo "  disable <repo>"
            echo "  list [--enabled-only]"
            echo "  status <repo>"
            echo "  sync <repo>"
            echo "  sync-all"
            echo "  logs [repo]"
            exit 1
            ;;
    esac
}
