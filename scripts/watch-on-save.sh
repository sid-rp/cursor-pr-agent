#!/usr/bin/env bash
set -euo pipefail

# PR-Agent File Watcher - On-Save Code Review
# Watches source files and runs AI review when they change

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 PR-Agent File Watcher${NC}"
echo -e "${CYAN}=========================${NC}"
echo ""

# Check dependencies
if ! command -v entr >/dev/null 2>&1; then
    echo -e "${RED}❌ 'entr' not found${NC}"
    echo -e "${YELLOW}📦 Install with:${NC}"
    echo -e "   ${BLUE}macOS:${NC} brew install entr"
    echo -e "   ${BLUE}Ubuntu/Debian:${NC} sudo apt install entr"
    echo -e "   ${BLUE}CentOS/RHEL:${NC} sudo yum install entr"
    echo ""
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 1
fi

# Check if PR-Agent is set up
if [ ! -d ".cursor-pr-agent" ]; then
    echo -e "${RED}❌ PR-Agent not installed${NC}"
    echo -e "${YELLOW}💡 Run the installer first:${NC}"
    echo -e "   curl -O https://raw.githubusercontent.com/sid-rp/cursor-pr-agent/main/install-pr-agent-complete.sh"
    echo -e "   ./install-pr-agent-complete.sh"
    echo -e "   ./.cursor-pr-agent/setup-hooks.sh"
    exit 1
fi

# Check if git hooks are installed
if [ ! -f ".git/hooks/post-commit" ]; then
    echo -e "${RED}❌ Git hooks not installed${NC}"
    echo -e "${YELLOW}💡 Enable git hooks first:${NC}"
    echo -e "   ./.cursor-pr-agent/setup-hooks.sh"
    exit 1
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo -e "${YELLOW}💡 Create .env with your API key:${NC}"
    echo -e "   echo 'OPENAI_API_KEY=sk-your-key' > .env"
    exit 1
fi

# Configuration
CONFIDENCE_LEVEL="${CONFIDENCE_LEVEL:-medium}"

echo -e "${GREEN}✅ Dependencies checked${NC}"
echo -e "${BLUE}📁 Repository:${NC} $(basename "$(pwd)")"
echo -e "${BLUE}⚙️  Confidence:${NC} ${CONFIDENCE_LEVEL}"
echo ""

# Get current branch
current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")

# Skip if on main/master
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo -e "${YELLOW}⏭️  On main/master branch - file watcher not recommended${NC}"
    echo -e "${YELLOW}💡 Switch to a feature branch first${NC}"
    exit 1
fi

echo -e "${BLUE}🌿 Branch:${NC} ${current_branch}"
echo ""

# Function to handle git lock
wait_for_git_lock() {
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ ! -f ".git/index.lock" ]; then
            return 0
        fi
        
        echo -e "${YELLOW}⏳ Waiting for git lock to clear (attempt $attempt/$max_attempts)...${NC}"
        sleep 0.5
        attempt=$((attempt + 1))
    done
    
    # If we get here, remove the stale lock
    echo -e "${YELLOW}🔧 Removing stale git lock file...${NC}"
    rm -f ".git/index.lock" 2>/dev/null || true
    return 0
}

# Function to run review
run_review() {
    # Create a lock file to prevent multiple simultaneous reviews
    local lock_file="/tmp/pr_agent_review_lock_$$"
    if [ -f "$lock_file" ]; then
        echo -e "${YELLOW}⏭️  Review already in progress, skipping...${NC}"
        return 0
    fi
    
    touch "$lock_file"
    trap "rm -f '$lock_file'" EXIT
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}    File Changed - Running Review${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        echo -e "${YELLOW}⏭️  On main/master branch - skipping review${NC}"
        rm -f "$lock_file"
        return 0
    fi
    
    # Wait for any existing git lock to clear
    wait_for_git_lock
    
    # Check if there are any changes (including untracked files)
    if git diff --quiet && git diff --quiet --cached && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${YELLOW}ℹ️  No changes detected${NC}"
        rm -f "$lock_file"
        return 0
    fi
    
    echo -e "${BLUE}🌿 Branch:${NC} ${current_branch}"
    echo -e "${BLUE}📝 Creating temporary commit for review...${NC}"
    
    local original_head=$(git rev-parse HEAD)
    
    # Wait for git lock before staging
    wait_for_git_lock
    
    # Stage all changes
    git add -A 2>/dev/null || true
    
    # Wait for git lock before committing
    wait_for_git_lock
    
    if git commit -m "[TEMP] Auto-review commit - will be reverted" --no-verify --quiet; then
        echo -e "${BLUE}🎯 Running PR-Agent directly${NC}"
        echo ""
        
        # Run PR-Agent directly on the current commit
        if ./.cursor-pr-agent/cursor_pr_agent_direct.py --confidence-level "$CONFIDENCE_LEVEL" --base-branch main; then
            echo -e "\n${GREEN}✅ Review completed${NC}"
        else
            echo -e "\n${YELLOW}⚠️  Review had issues (timeout or API error)${NC}"
        fi
        
        # Wait for git lock before reverting
        wait_for_git_lock
        
        # Revert the temporary commit completely to avoid triggering entr
        echo -e "${BLUE}🔄 Restoring original state...${NC}"
        git reset --hard "$original_head" --quiet
        
        echo -e "${GREEN}✅ State restored${NC}"
    else
        echo -e "${YELLOW}⚠️  No changes to commit${NC}"
    fi
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}👁️  Watching for more changes...${NC}"
    
    # Remove lock file before exiting
    rm -f "$lock_file"
    
    # Longer delay to prevent rapid re-triggering
    sleep 2
}

# Export function and variables for entr
export -f run_review wait_for_git_lock
export CONFIDENCE_LEVEL RED GREEN YELLOW BLUE CYAN NC

echo -e "${YELLOW}👁️  Watching files... (Press Ctrl+C to stop)${NC}"
echo -e "${YELLOW}💡 Save any source file to trigger review${NC}"
echo ""

# Watch files using entr - proper pattern with git lock handling
find . -maxdepth 3 -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" \) ! -path "./.cursor-pr-agent/*" ! -path "./pr-agent-setup/*" ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./__pycache__/*" | entr -d -r bash -c 'run_review'
