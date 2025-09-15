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
WATCH_EXTENSIONS="${WATCH_EXTENSIONS:-py,js,ts,tsx,jsx,go,rs,java,cpp,c,h,hpp,sh,yml,yaml,json}"

echo -e "${GREEN}✅ Dependencies checked${NC}"
echo -e "${BLUE}📁 Repository:${NC} $(basename "$(pwd)")"
echo -e "${BLUE}⚙️  Confidence:${NC} ${CONFIDENCE_LEVEL}"
echo -e "${BLUE}📝 Extensions:${NC} ${WATCH_EXTENSIONS}"
echo ""

# Create file pattern for entr
PATTERN=$(echo "$WATCH_EXTENSIONS" | sed 's/,/\\|/g')

echo -e "${YELLOW}👁️  Watching files... (Press Ctrl+C to stop)${NC}"
echo -e "${YELLOW}💡 Save any source file to trigger review${NC}"
echo ""

# Function to run review
run_review() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}    File Changed - Running Review${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get current branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    
    # Skip if on main/master
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        echo -e "${YELLOW}⏭️  On main/master branch - skipping review${NC}"
        return 0
    fi
    
    # Check if there are any changes
    if git diff --quiet && git diff --quiet --cached; then
        echo -e "${YELLOW}ℹ️  No changes detected${NC}"
        return 0
    fi
    
    echo -e "${BLUE}🌿 Branch:${NC} ${current_branch}"
    echo -e "${BLUE}📝 Creating temporary commit for review...${NC}"
    
    # Save current state
    local has_staged_changes=false
    local has_unstaged_changes=false
    
    if ! git diff --quiet --cached; then
        has_staged_changes=true
    fi
    
    if ! git diff --quiet; then
        has_unstaged_changes=true
    fi
    
    # Create temporary commit for PR-Agent analysis
    local temp_commit_created=false
    local original_head=$(git rev-parse HEAD)
    
    # Stage all changes
    git add -A
    
    # Create temporary commit
    if git commit -m "[TEMP] Auto-review commit - will be reverted" --quiet; then
        temp_commit_created=true
        echo -e "${BLUE}🎯 Running PR-Agent review...${NC}"
        echo ""
        
        # Run the review on the temporary commit
        if timeout 45s ./.cursor-pr-agent/cursor_pr_agent_direct.py --confidence-level "$CONFIDENCE_LEVEL"; then
            echo -e "\n${GREEN}✅ Review completed${NC}"
        else
            echo -e "\n${YELLOW}⚠️  Review had issues (timeout or API error)${NC}"
        fi
        
        # Revert the temporary commit
        echo -e "${BLUE}🔄 Restoring original state...${NC}"
        git reset --soft "$original_head"
        
        # Restore original staging state
        if [[ "$has_staged_changes" == "false" ]]; then
            git reset HEAD . --quiet 2>/dev/null || true
        fi
        
        echo -e "${GREEN}✅ State restored${NC}"
    else
        echo -e "${YELLOW}⚠️  No changes to commit${NC}"
    fi
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}👁️  Watching for more changes...${NC}"
}

# Export the function so entr can use it
export -f run_review
export CONFIDENCE_LEVEL
export RED GREEN YELLOW BLUE CYAN NC

# Watch files and trigger review on changes
git ls-files | grep -E "\\.($PATTERN)$" | entr -c bash -c 'run_review'
