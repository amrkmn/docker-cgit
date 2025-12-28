#!/bin/bash
# Core repository operations library
# Functions for creating, cloning, updating, deleting, and listing repositories

function create_repo() {
    local REPO_NAME="$1"
    local REPO_DESC="${2:-A git repository}"
    local REPO_OWNER="${3:-$CGIT_OWNER}"

    if [ -z "$REPO_NAME" ]; then
        echo "Usage: repo create <repo-name> [description] [owner]"
        echo ""
        echo "Examples:"
        echo "  repo create my-project"
        echo "  repo create my-project 'My awesome project'"
        echo "  repo create my-project 'My awesome project' 'John Doe <john@example.com>'"
        exit 1
    fi

    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    local REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"

    if [ -d "$REPO_PATH" ]; then
        echo "Error: Repository already exists at $REPO_PATH"
        exit 1
    fi

    echo "Creating bare repository: $REPO_PATH"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    git init --bare "${REPO_NAME}.git"

    cd "$REPO_PATH"
    echo "Configuring cgit metadata..."
    git config --local cgit.name "$REPO_NAME"
    git config --local cgit.desc "$REPO_DESC"
    git config --local cgit.owner "$REPO_OWNER"
    git config --local cgit.defbranch "main"
    git config --local cgit.readme ":README.md"

    clear_cache

    echo ""
    echo "Repository created successfully!"
    echo "Repository path: $REPO_PATH"
    echo "Display name:    $REPO_NAME"
    echo "Description:     $REPO_DESC"
    echo "Owner:           $REPO_OWNER"
    echo ""
    echo "To use this repository:"
    echo "  git clone ssh://git@${CGIT_HOST}:${CGIT_PORT}/${REPO_NAME}.git"
    echo ""
}

function clone_repo() {
    local GIT_URL=""
    local REPO_NAME=""
    local REPO_DESC="Mirrored repository"
    local REPO_OWNER="$CGIT_OWNER"
    local ENABLE_MIRROR=false
    local MIRROR_SCHEDULE="0 */6 * * *"
    local MIRROR_TIMEOUT=600

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mirror)
                ENABLE_MIRROR=true
                shift
                ;;
            --schedule)
                MIRROR_SCHEDULE="$2"
                shift 2
                ;;
            --timeout)
                MIRROR_TIMEOUT="$2"
                shift 2
                ;;
            *)
                if [ -z "$GIT_URL" ]; then
                    GIT_URL="$1"
                elif [ -z "$REPO_NAME" ]; then
                    REPO_NAME="$1"
                elif [ "$REPO_DESC" == "Mirrored repository" ]; then
                    REPO_DESC="$1"
                elif [ "$REPO_OWNER" == "$CGIT_OWNER" ]; then
                    REPO_OWNER="$1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$GIT_URL" ]; then
        echo "Usage: repo clone <git-url> [repo-name] [description] [owner] [--mirror] [--schedule CRON] [--timeout SECONDS]"
        echo ""
        echo "Examples:"
        echo "  repo clone https://github.com/user/repo.git"
        echo "  repo clone https://github.com/user/repo.git repo-name 'Custom Description' 'Owner Name <email>'"
        echo "  repo clone https://github.com/user/repo.git --mirror"
        echo "  repo clone https://github.com/user/repo.git --mirror --schedule '0 2 * * *' --timeout 900"
        exit 1
    fi

    if [ -z "$REPO_NAME" ]; then
        REPO_NAME=$(basename "$GIT_URL" .git)
        echo "Auto-detected repository name: $REPO_NAME"
    fi

    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    local REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"

    if [ -d "$REPO_PATH" ]; then
        echo "Error: Repository already exists at $REPO_PATH"
        exit 1
    fi

    echo "Cloning repository from: $GIT_URL"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    git clone --bare --mirror "$GIT_URL" "${REPO_NAME}.git"

    cd "$REPO_PATH"
    echo "Configuring cgit metadata..."
    git config --local cgit.name "$REPO_NAME"
    git config --local cgit.desc "$REPO_DESC"
    git config --local cgit.owner "$REPO_OWNER"

    local DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    git config --local cgit.defbranch "$DEFAULT_BRANCH"
    git config --local cgit.readme ":README.md"

    local CLONE_URLS="git://${CGIT_HOST}/${REPO_NAME}.git https://${CGIT_HOST}/${REPO_NAME}.git ssh://git@${CGIT_HOST}:${CGIT_PORT}/${REPO_NAME}.git"
    git config --local cgit.clone-url "$CLONE_URLS"

    clear_cache

    echo ""
    echo "Repository mirrored successfully!"
    echo "Repository path: $REPO_PATH"
    echo "Display name:    $REPO_NAME"
    echo "Description:     $REPO_DESC"
    echo "Default branch:  $DEFAULT_BRANCH"
    echo "Source URL:      $GIT_URL"
    echo "Clone URLs:"
    echo "  git://$CGIT_HOST/$REPO_NAME.git"
    echo "  https://$CGIT_HOST/$REPO_NAME.git"
    echo "  ssh://git@$CGIT_HOST:$CGIT_PORT/$REPO_NAME.git"
    echo "Owner:           $REPO_OWNER"
    echo ""
    
    # Enable auto-sync if --mirror flag was provided
    if [ "$ENABLE_MIRROR" = true ]; then
        echo "Enabling mirror auto-sync..."
        python3 /opt/cgit/bin/mirror-manager.py enable "$REPO_NAME" --schedule "$MIRROR_SCHEDULE" --timeout "$MIRROR_TIMEOUT"
        echo ""
    else
        echo "To update this mirror:"
        echo "  repo update ${REPO_NAME}"
        echo ""
    fi
}

function update_repo() {
    local REPO_NAME="$1"

    if [ -z "$REPO_NAME" ]; then
        echo "Usage: repo update <repo-name>"
        echo ""
        echo "Example:"
        echo "  repo update my-project"
        exit 1
    fi

    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    local REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"

    if [ ! -d "$REPO_PATH" ]; then
        echo "Error: Repository does not exist at $REPO_PATH"
        exit 1
    fi

    echo "Updating repository: $REPO_NAME"

    if ! su - git -c "cd '$REPO_PATH' && git remote | grep -q ."; then
        echo "Error: No remote configured for this repository"
        exit 1
    fi

    local REMOTE_NAME=$(su - git -c "cd '$REPO_PATH' && git remote | head -n 1")
    local REMOTE_URL=$(su - git -c "cd '$REPO_PATH' && git remote get-url '$REMOTE_NAME'")

    echo ""
    echo "Fetching updates from $REMOTE_NAME ($REMOTE_URL)..."
    su - git -c "cd '$REPO_PATH' && git remote update '$REMOTE_NAME' --prune"

    echo ""
    echo "Repository updated successfully!"
    echo ""

    clear_cache
}

function delete_repo() {
    local REPO_NAME=""
    local SKIP_CONFIRM=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                SKIP_CONFIRM=true
                shift
                ;;
            *)
                if [ -z "$REPO_NAME" ]; then
                    REPO_NAME="$1"
                else
                    echo "Error: Unknown argument '$1'"
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$REPO_NAME" ]; then
        echo "Usage: repo delete <repo-name> [--yes]"
        echo ""
        echo "Options:"
        echo "  -y, --yes    Skip confirmation prompt"
        echo ""
        echo "Example:"
        echo "  repo delete my-project"
        echo "  repo delete my-project --yes"
        exit 1
    fi

    validate_repo_name "$REPO_NAME"
    REPO_NAME="${REPO_NAME%.git}"
    local REPO_PATH="${REPO_DIR}/${REPO_NAME}.git"

    if [ ! -d "$REPO_PATH" ]; then
        echo "Error: Repository does not exist at $REPO_PATH"
        exit 1
    fi

    echo "Deleting repository: $REPO_PATH"
    echo "This will permanently delete all repository data!"

    if [ "$SKIP_CONFIRM" = false ]; then
        if [ -t 0 ]; then
            echo ""
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                echo "Deletion cancelled."
                exit 0
            fi
        else
            echo ""
            echo "Error: Not running in interactive mode."
            echo "To delete without confirmation, use: repo delete $REPO_NAME --yes"
            exit 1
        fi
    fi

    echo ""
    echo "Proceeding with deletion..."
    rm -rf "$REPO_PATH"
    clear_cache

    echo ""
    echo "Repository deleted successfully!"
}

function list_repos() {
    if [ ! -d "$REPO_DIR" ]; then
        echo "Error: Repository directory does not exist: $REPO_DIR"
        exit 1
    fi

    local REPOS=$(find "$REPO_DIR" -maxdepth 1 -type d -name "*.git" | sort)

    if [ -z "$REPOS" ]; then
        echo "No repositories found in $REPO_DIR"
        exit 0
    fi

    echo "Found $(echo "$REPOS" | wc -l) repository/repositories:"
    echo ""

    for REPO_PATH in $REPOS; do
        local REPO_NAME=$(basename "$REPO_PATH" .git)
        local NAME=$(git -C "$REPO_PATH" config --local cgit.name 2>/dev/null || echo "$REPO_NAME")
        local DESC=$(git -C "$REPO_PATH" config --local cgit.desc 2>/dev/null || echo "No description")
        local OWNER=$(git -C "$REPO_PATH" config --local cgit.owner 2>/dev/null || echo "Unknown")
        local DEFAULT_BRANCH=$(git -C "$REPO_PATH" config --local cgit.defbranch 2>/dev/null || echo "main")
        local LAST_COMMIT=$(git -C "$REPO_PATH" log -1 --format=%cd --date=short 2>/dev/null || echo "Never")
        local BRANCHES=$(git -C "$REPO_PATH" branch -a 2>/dev/null | wc -l)

        echo "Name:            $NAME"
        echo "Path:            $REPO_PATH"
        echo "Description:     $DESC"
        echo "Owner:           $OWNER"
        echo "Default branch:  $DEFAULT_BRANCH"
        echo "Branches:        $BRANCHES"
        echo "Last commit:     $LAST_COMMIT"
        echo "Clone URL:       ssh://git@${CGIT_HOST}:${CGIT_PORT}/${REPO_NAME}.git"
        echo ""
    done
}
