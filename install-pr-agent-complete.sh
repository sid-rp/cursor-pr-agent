#!/bin/bash

# 🚀 Complete PR-Agent Integration Installer
# Uses official qodo-ai/pr-agent repository
# Self-contained installer for any repository

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    cat << 'EOF'
🚀 PR-Agent Universal Installer

USAGE:
  ./install-pr-agent-complete.sh [OPTIONS]

OPTIONS:
  --help, -h     Show this help message
  --docker       Build Docker image for portable installation

DESCRIPTION:
  This script installs PR-Agent integration in any Git repository.
  It provides automated AI-powered code review capabilities.

REQUIREMENTS:
  - Git repository
  - Python 3.8+
  - OpenAI API key (set in .env file)

WHAT IT INSTALLS:
  - PR-Agent Python integration
  - Git hooks for automatic review
  - Configuration files
  - Documentation

DOCKER USAGE:
  # Build the installer image
  ./install-pr-agent-complete.sh --docker
  
  # Use in any repository
  docker run -v $(pwd):/workspace -w /workspace pr-agent-installer

EXAMPLES:
  # Install in current repository
  ./install-pr-agent-complete.sh
  
  # Manual review after installation
  ./.cursor-pr-agent/cursor_pr_agent_direct.py
  
  # Set up git hooks
  ./.cursor-pr-agent/setup-hooks.sh

EOF
    exit 0
fi

# Check for Docker build flag
if [[ "$1" == "--docker" ]]; then
    echo "🐳 Building PR-Agent installer Docker image..."
    docker build -f Dockerfile.pr-agent-installer -t pr-agent-installer .
    echo "✅ Docker image 'pr-agent-installer' built successfully!"
    echo ""
    echo "Usage in any repository:"
    echo "  docker run -v \$(pwd):/workspace -w /workspace pr-agent-installer"
    exit 0
fi

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
OFFICIAL_REPO="https://github.com/qodo-ai/pr-agent.git"
TEMP_DIR="/tmp/pr-agent-installer-$$"
INSTALL_DIR=".cursor-pr-agent"

echo -e "${CYAN}${BOLD}🚀 Complete PR-Agent Integration Installer${NC}"
echo -e "${CYAN}${BOLD}==========================================${NC}"
echo -e "${BLUE}Using official repository: ${OFFICIAL_REPO}${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    echo -e "${BLUE}💡 Run this script from inside a git repository${NC}"
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
echo -e "${BLUE}📁 Repository: $(basename "$REPO_ROOT")${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check for Python
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}❌ Python 3 is required but not installed${NC}"
    echo -e "${BLUE}💡 Install Python 3: https://python.org/downloads/${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python 3 found: $(python3 --version)${NC}"

# Check for pip
if ! command -v pip3 >/dev/null 2>&1; then
    echo -e "${RED}❌ pip3 is required but not installed${NC}"
    echo -e "${BLUE}💡 Install pip3 with your package manager${NC}"
    exit 1
fi
echo -e "${GREEN}✅ pip3 found${NC}"

# Check for git
if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}❌ git is required but not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ git found${NC}"

echo ""

# Create temporary directory
echo -e "${BLUE}📦 Downloading PR-Agent from official repository...${NC}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Clone the official repository
if ! git clone --depth 1 "$OFFICIAL_REPO" pr-agent-repo; then
    echo -e "${RED}❌ Failed to clone PR-Agent repository${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Successfully downloaded PR-Agent${NC}"

# Go back to the target repository
cd "$REPO_ROOT"

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Copy official PR-Agent requirements.txt
echo -e "${BLUE}📋 Using official PR-Agent requirements.txt...${NC}"
if [ -f "$TEMP_DIR/pr-agent-repo/requirements.txt" ]; then
    cp "$TEMP_DIR/pr-agent-repo/requirements.txt" "$INSTALL_DIR/"
    echo -e "${GREEN}✅ Official requirements.txt copied${NC}"
    
    # Install dependencies directly from the official requirements
    echo -e "${BLUE}📚 Installing dependencies from official requirements.txt...${NC}"
    
    # Try different installation strategies with the official requirements
    if pip3 install --user -r "$INSTALL_DIR/requirements.txt" --quiet 2>/dev/null; then
        echo -e "${GREEN}✅ All dependencies installed in user space${NC}"
        DEPS_INSTALLED=true
    elif pip3 install -r "$INSTALL_DIR/requirements.txt" --break-system-packages --quiet 2>/dev/null; then
        echo -e "${GREEN}✅ All dependencies installed (system packages)${NC}"
        DEPS_INSTALLED=true
    else
        echo -e "${YELLOW}⚠️  Failed to install full requirements, trying essential packages only...${NC}"
        
        # Create a minimal requirements file for essential packages only
        cat > "$INSTALL_DIR/requirements-minimal.txt" << 'EOF'
PyYAML==6.0.1
openai>=1.55.3
GitPython==3.1.41
tiktoken==0.8.0
loguru==0.7.2
pydantic==2.8.2
dynaconf==3.2.4
litellm==1.73.6
tenacity==8.2.3
aiohttp==3.10.2
EOF
        
        if pip3 install --user -r "$INSTALL_DIR/requirements-minimal.txt" --quiet 2>/dev/null; then
            echo -e "${GREEN}✅ Essential dependencies installed in user space${NC}"
            DEPS_INSTALLED=true
        elif pip3 install -r "$INSTALL_DIR/requirements-minimal.txt" --break-system-packages --quiet 2>/dev/null; then
            echo -e "${GREEN}✅ Essential dependencies installed (system packages)${NC}"
            DEPS_INSTALLED=true
        else
            echo -e "${YELLOW}⚠️  Failed to install dependencies, trying individual packages...${NC}"
            
            # Try to install the most essential packages individually
            for pkg in "PyYAML==6.0.1" "openai>=1.55.3" "dynaconf==3.2.4" "GitPython==3.1.41" "tiktoken==0.8.0"; do
                if pip3 install --user "$pkg" --quiet 2>/dev/null || pip3 install "$pkg" --break-system-packages --quiet 2>/dev/null; then
                    echo -e "${GREEN}✅ Installed $pkg${NC}"
                else
                    echo -e "${YELLOW}⚠️  Could not install $pkg${NC}"
                fi
            done
            DEPS_INSTALLED=partial
        fi
    fi
else
    echo -e "${RED}❌ Could not find official requirements.txt${NC}"
    exit 1
fi

# Always copy the pr_agent module for local use as backup
if [ -d "$TEMP_DIR/pr-agent-repo/pr_agent" ]; then
    cp -r "$TEMP_DIR/pr-agent-repo/pr_agent" "$INSTALL_DIR/"
    echo -e "${GREEN}✅ PR-Agent module copied locally${NC}"
else
    echo -e "${RED}❌ Could not find pr_agent module${NC}"
    exit 1
fi

# Create the main integration script
echo -e "${BLUE}🔧 Creating integration script...${NC}"
cat > "$INSTALL_DIR/cursor_pr_agent_direct.py" << 'EOF'
#!/usr/bin/env python3
"""
Direct PR-Agent Integration for Cursor IDE

This script directly uses PR-Agent's internal classes and functions to provide
code review without Docker dependencies.

Uses the official qodo-ai/pr-agent repository.
"""

import os
import sys
import asyncio
import argparse
import subprocess
import tempfile
from pathlib import Path

# Add local pr_agent to path if it exists
script_dir = Path(__file__).parent
local_pr_agent = script_dir / "pr_agent"
if local_pr_agent.exists():
    sys.path.insert(0, str(script_dir))

# Import dependencies with fallbacks
try:
    import yaml
    YAML_AVAILABLE = True
except ImportError:
    print("⚠️  PyYAML not available. Install with: pip install PyYAML")
    YAML_AVAILABLE = False

try:
    from dotenv import load_dotenv
    DOTENV_AVAILABLE = True
except ImportError:
    print("⚠️  python-dotenv not available but should be installed via requirements.txt")
    DOTENV_AVAILABLE = False

def load_env_file():
    """Load environment variables from .env file"""
    env_file = Path(".env")
    if not env_file.exists():
        print("⚠️  No .env file found")
        return
    
    # Since we install python-dotenv via requirements.txt, it should always be available
    load_dotenv(env_file, override=True)
    print("🔑 Loaded environment variables from .env using python-dotenv")

def format_review_output(prediction_dict, confidence_level="medium"):
    """Format the PR-Agent review output for console display"""
    
    if not prediction_dict or 'review' not in prediction_dict:
        return "No review data available"
    
    review_data = prediction_dict['review']
    output = []
    
    # Header
    output.append("\\n🔍 PR-Agent Code Review Results")
    output.append("=" * 50)
    output.append("")
    
    # Key Issues (Most Important)
    if 'key_issues_to_review' in review_data:
        issues = review_data['key_issues_to_review']
        if issues:
            output.append("🚨 Key Issues Found:")
            output.append("")
            
            for i, issue in enumerate(issues, 1):
                if isinstance(issue, dict):
                    file_name = issue.get('relevant_file', 'Unknown file')
                    issue_header = issue.get('issue_header', 'Issue')
                    issue_content = issue.get('issue_content', 'No description')
                    start_line = issue.get('start_line', '')
                    end_line = issue.get('end_line', '')
                    
                    output.append(f"{i}. **{issue_header}** - 📁 \\`{file_name}\\`" + 
                                (f" (Lines {start_line}-{end_line})" if start_line else ""))
                    output.append(f"   {issue_content}")
                    output.append("")
    
    # Security Concerns
    if 'security_concerns' in review_data:
        security = review_data['security_concerns']
        if security and security.strip():
            output.append("🔒 Security Concerns:")
            output.append("")
            # Split into bullet points for better readability
            lines = security.strip().split('\\n')
            for line in lines:
                line = line.strip()
                if line:
                    if line.startswith('- '):
                        output.append(f"   {line}")
                    else:
                        output.append(f"   • {line}")
            output.append("")
    
    # Effort Estimate
    if 'estimated_effort_to_review_[1-5]' in review_data:
        effort = review_data['estimated_effort_to_review_[1-5]']
        if effort:
            output.append(f"⏱️  Estimated Review Effort: {effort}/5")
            output.append("")
    
    # Tests
    if 'relevant_tests' in review_data:
        tests = review_data['relevant_tests']
        if tests and tests.strip().lower() not in ['no', 'none', 'n/a']:
            output.append(f"🧪 Test Coverage: {tests}")
            output.append("")
    
    # Summary
    num_issues = len(review_data.get('key_issues_to_review', []))
    has_security = bool(review_data.get('security_concerns', '').strip())
    
    output.append("📊 Summary:")
    if num_issues > 0:
        output.append(f"   • {num_issues} key issue{'s' if num_issues != 1 else ''} found")
    if has_security:
        output.append(f"   • Security concerns identified")
    if num_issues == 0 and not has_security:
        output.append(f"   • No major issues detected")
    
    output.append(f"   • Confidence level: {confidence_level}")
    output.append("")
    
    return "\\n".join(output)

def check_pr_agent_available():
    """Check if PR-Agent is available and can be imported"""
    try:
        import pr_agent
        from pr_agent.config_loader import get_settings
        from pr_agent.git_providers.local_git_provider import LocalGitProvider
        from pr_agent.tools.pr_reviewer import PRReviewer
        return True, None
    except ImportError as e:
        return False, str(e)

def check_git_status():
    """Check if git repository is clean"""
    try:
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True)
        if result.returncode != 0:
            return False, f"Git status failed: {result.stderr}"
        
        if result.stdout.strip():
            return False, "Repository has uncommitted changes. Please commit or stash them first."
        
        return True, "Repository is clean"
    except Exception as e:
        return False, f"Error checking git status: {e}"

def get_default_branch():
    """Get the default branch name or fallback strategy"""
    # Get current branch
    current_result = subprocess.run(['git', 'branch', '--show-current'], 
                                  capture_output=True, text=True)
    current_branch = current_result.stdout.strip() if current_result.returncode == 0 else ""
    
    try:
        # Try to get the default branch from remote
        result = subprocess.run(['git', 'symbolic-ref', 'refs/remotes/origin/HEAD'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            remote_default = result.stdout.strip().split('/')[-1]
            if remote_default != current_branch:
                return remote_default
    except:
        pass
    
    # Get all branches
    result = subprocess.run(['git', 'branch', '--format=%(refname:short)'], 
                          capture_output=True, text=True)
    branches = []
    if result.returncode == 0 and result.stdout.strip():
        branches = [b.strip() for b in result.stdout.strip().split('\n') if b.strip()]
    
    # Check common branch names (but not the current branch)
    for branch in ['main', 'master', 'develop']:
        if branch != current_branch and branch in branches:
            return branch
    
    # Return the first branch that's not the current branch
    for branch in branches:
        if branch != current_branch:
            return branch
    
    # If we're on the only branch, create a master branch as reference
    if len(branches) <= 1:
        # Check if master exists, if not create it
        master_check = subprocess.run(['git', 'show-ref', '--verify', '--quiet', 'refs/heads/master'], 
                                    capture_output=True)
        if master_check.returncode != 0:
            # Create master branch at first commit if it doesn't exist
            first_commit = subprocess.run(['git', 'rev-list', '--max-parents=0', 'HEAD'], 
                                        capture_output=True, text=True)
            if first_commit.returncode == 0 and first_commit.stdout.strip():
                subprocess.run(['git', 'branch', 'master', first_commit.stdout.strip()], 
                             capture_output=True, text=True)
                return 'master'
    
    # Final fallback
    return 'main'

async def run_pr_agent_review(base_branch: str = None, confidence_level: str = "medium"):
    """Run PR-Agent review using the official implementation"""
    
    # Auto-detect base branch if not provided
    if base_branch is None:
        base_branch = get_default_branch()
        print(f"🔍 Auto-detected base branch: {base_branch}")
    
    print(f"🎯 **PR-Agent Review** (Confidence: {confidence_level})")
    print("=" * 50)
    
    # Load environment variables
    load_env_file()
    
    # Check API key
    api_key = os.getenv("OPENAI_API_KEY") or os.getenv("OPENAI_KEY")
    if not api_key:
        return "❌ OPENAI_API_KEY not found. Add it to your .env file."
    
    print("🔑 API key loaded from environment")
    
    # Check git status
    clean, status_msg = check_git_status()
    if not clean:
        return f"❌ {status_msg}"
    
    print("✅ Git repository is clean")
    
    try:
        # Import PR-Agent components
        from pr_agent.config_loader import get_settings
        from pr_agent.git_providers.local_git_provider import LocalGitProvider
        from pr_agent.tools.pr_reviewer import PRReviewer
        from pr_agent.algo.pr_processing import get_pr_diff
        from pr_agent.algo.utils import convert_to_markdown_v2
        
        print("📚 PR-Agent modules imported successfully")
        
        # Configure settings
        get_settings().set("git_provider", "local")
        get_settings().set("config.git_provider", "local")
        get_settings().set("openai.key", api_key)
        get_settings().set("pr_reviewer.require_score_review", False)
        get_settings().set("pr_reviewer.require_soc2_review", True)
        get_settings().set("pr_reviewer.require_can_be_split_review", False)
        # Disable label functionality to prevent errors with LocalGitProvider
        get_settings().set("pr_reviewer.enable_review_labels_effort", False)
        get_settings().set("pr_reviewer.enable_review_labels_security", False)
        
        # Set confidence-based filtering
        if confidence_level == "high":
            get_settings().set("pr_reviewer.require_focused_review", True)
            get_settings().set("pr_reviewer.require_estimate_effort_to_review", False)
        elif confidence_level == "low":
            get_settings().set("pr_reviewer.require_focused_review", False)
            get_settings().set("pr_reviewer.require_estimate_effort_to_review", True)
        
        print(f"⚙️  Configuration set for {confidence_level} confidence level")
        
        # Initialize git provider
        git_provider = LocalGitProvider(target_branch_name=base_branch)
        print(f"🔗 Local git provider initialized (target: {base_branch})")
        
        # Get current branch
        current_branch = subprocess.run(['git', 'branch', '--show-current'], 
                                      capture_output=True, text=True).stdout.strip()
        
        if not current_branch:
            return "❌ Could not determine current branch"
        
        print(f"🌿 Current branch: {current_branch}")
        print(f"🎯 Comparing against: {base_branch}")
        
        # Special handling for single branch or first commit scenarios
        if base_branch == current_branch:
            return f"ℹ️  On the default branch '{current_branch}' - no review needed. Create a feature branch to get reviews."
        
        # Check if base branch exists or if we're comparing against HEAD~
        if base_branch.startswith('HEAD~'):
            # Check if we have enough commits
            commit_result = subprocess.run(['git', 'rev-list', '--count', 'HEAD'], 
                                         capture_output=True, text=True)
            if commit_result.returncode == 0:
                commit_count = int(commit_result.stdout.strip())
                if commit_count <= 1:
                    return f"ℹ️  Only one commit in repository - no previous version to compare against. Make more changes and commit again for review."
        
        # Check if there are differences (excluding PR-Agent setup files)
        diff_result = subprocess.run(['git', 'diff', f'{base_branch}..HEAD', '--', 
                                    ':(exclude).cursor-pr-agent/*', ':(exclude)__pycache__/*',
                                    ':(exclude).pr_agent.toml', ':(exclude)install-pr-agent-complete.sh'], 
                                   capture_output=True, text=True)
        
        if not diff_result.stdout.strip():
            return f"ℹ️  No changes detected between '{current_branch}' and '{base_branch}'"
        
        print("📊 Changes detected, starting review...")
        
        # Get diff files using PR-Agent's method
        diff_files = git_provider.get_diff_files()
        
        print(f"🔍 Found {len(diff_files)} files with changes")
        
        # Initialize PR reviewer with target branch as URL (LocalGitProvider expects this)
        pr_reviewer = PRReviewer(base_branch)
        
        # Set the git provider
        pr_reviewer.git_provider = git_provider
        
        print("🤖 Running PR-Agent analysis...")
        
        # Run the review
        result = await pr_reviewer.run()
        
        # PR-Agent's run() method may return different formats
        if isinstance(result, tuple):
            prediction, review = result
        else:
            prediction = result
            review = None
        
        if not prediction and not review:
            return "⚠️  PR-Agent completed but no review was generated"
        
        # Format and display results using our custom formatter
        if prediction:
            if hasattr(prediction, 'dict'):
                prediction_dict = prediction.dict()
            else:
                prediction_dict = prediction
            
            # Use our custom formatter for better console output
            formatted_output = format_review_output(prediction_dict, confidence_level)
            print(formatted_output)
        else:
            print("\\n🔍 PR-Agent Code Review Results")
            print("=" * 50)
            print("\\n📊 Summary:")
            print("   • No specific issues found by PR-Agent")
            print(f"   • Confidence level: {confidence_level}")
            print("")
        
        print(f"✅ PR-Agent review completed!")
        return "✅ Review completed successfully"
        
    except Exception as e:
        error_msg = f"❌ PR-Agent review failed: {e}"
        print(error_msg)
        return error_msg

def main():
    parser = argparse.ArgumentParser(description="PR-Agent Direct Integration")
    parser.add_argument("--base-branch", "-b", default=None, 
                       help="Base branch to compare against (default: auto-detect)")
    parser.add_argument("--confidence-level", "-c", 
                       choices=["high", "medium", "low"], default="medium",
                       help="Filter suggestions by confidence level (default: medium)")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Enable verbose output")
    
    args = parser.parse_args()
    
    if args.verbose:
        import logging
        logging.basicConfig(level=logging.DEBUG)
    
    try:
        result = asyncio.run(run_pr_agent_review(args.base_branch, args.confidence_level))
        print("\n" + "="*50)
        print("📋 SUMMARY:")
        if "❌" in result:
            print(result)
            sys.exit(1)
        else:
            print("✅ Review completed successfully")
    except KeyboardInterrupt:
        print("\n⚠️  Review interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

chmod +x "$INSTALL_DIR/cursor_pr_agent_direct.py"
echo -e "${GREEN}✅ Integration script created${NC}"

# Create git hooks setup script
echo -e "${BLUE}🪝 Creating git hooks setup script...${NC}"
cat > "$INSTALL_DIR/setup-hooks.sh" << 'EOF'
#!/bin/bash

# Git Hooks Setup for PR-Agent Integration
# This script installs pre-commit and post-commit hooks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🪝 Setting up PR-Agent Git Hooks${NC}"
echo "=================================="

# Get the repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

# Create pre-commit hook
echo -e "${BLUE}📝 Creating pre-commit hook...${NC}"
cat > "$HOOKS_DIR/pre-commit" << 'HOOK_EOF'
#!/bin/bash

# PR-Agent Pre-Commit Hook
# Runs code review before commit

# Skip on main/master branches
current_branch=$(git branch --show-current)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    exit 0
fi

# Skip if no .env file (no API key)
if [ ! -f ".env" ]; then
    echo "⚠️  No .env file found, skipping PR-Agent review"
    exit 0
fi

# Load environment variables from .env file for the git hook
set -a
source .env
set +a

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    PR-Agent Pre-Commit Review"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if there are staged changes
if ! git diff --cached --quiet; then
    echo "🔍 Running PR-Agent review on staged changes..."
    
    # Temporarily commit staged changes for review
    git stash push --keep-index -m "temp-for-pr-agent-review"
    
    # Run PR-Agent review (will auto-detect base branch)
    if ./.cursor-pr-agent/cursor_pr_agent_direct.py --confidence-level medium; then
        echo "✅ PR-Agent review completed"
        echo "📄 Check pr_agent_review.md for results"
    else
        echo "⚠️  PR-Agent review had issues, but proceeding with commit"
    fi
    
    # Restore stashed changes
    if git stash list | grep -q "temp-for-pr-agent-review"; then
        git stash pop
    fi
else
    echo "ℹ️  No staged changes to review"
fi

echo ""
HOOK_EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo -e "${GREEN}✅ Pre-commit hook installed${NC}"

# Create post-commit hook
echo -e "${BLUE}📝 Creating post-commit hook...${NC}"
cat > "$HOOKS_DIR/post-commit" << 'HOOK_EOF'
#!/bin/bash

# PR-Agent Post-Commit Hook
# Runs code review after commit

# Skip on main/master branches
current_branch=$(git branch --show-current)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    exit 0
fi

# Skip if no .env file (no API key)
if [ ! -f ".env" ]; then
    echo "⚠️  No .env file found, skipping PR-Agent review"
    exit 0
fi

# Load environment variables from .env file for the git hook
set -a
source .env
set +a

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "    PR-Agent Post-Commit Review"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get commit info
commit_hash=$(git rev-parse HEAD)
commit_msg=$(git log -1 --pretty=format:"%s")

echo "📊 Just committed:"
echo "   Hash: $commit_hash"
echo "   Message: $commit_msg"
echo ""

echo "🤖 Running PR-Agent review on latest commit..."
echo "    Comparing $current_branch against default branch (auto-detect)"
echo ""

# Run PR-Agent review (will auto-detect base branch)
if ./.cursor-pr-agent/cursor_pr_agent_direct.py --confidence-level medium; then
    echo ""
    echo "🔍 Review the suggestions above before pushing"
else
    echo ""
    echo "⚠️  PR-Agent review encountered issues"
    echo "💡 You can run it manually: ./.cursor-pr-agent/cursor_pr_agent_direct.py"
fi

echo ""
HOOK_EOF

chmod +x "$HOOKS_DIR/post-commit"
echo -e "${GREEN}✅ Post-commit hook installed${NC}"

echo ""
echo -e "${GREEN}🎉 Git hooks setup complete!${NC}"
echo ""
echo -e "${BLUE}📋 What was installed:${NC}"
echo -e "  • Pre-commit hook: Reviews staged changes before commit"
echo -e "  • Post-commit hook: Reviews changes after commit"
echo ""
echo -e "${BLUE}💡 The hooks will:${NC}"
echo -e "  • Skip on main/master branches"
echo -e "  • Skip if no .env file is found"
echo -e "  • Run automatically on commits in feature branches"
echo ""
echo -e "${YELLOW}⚠️  Note: Make sure your .env file contains OPENAI_API_KEY${NC}"
EOF

chmod +x "$INSTALL_DIR/setup-hooks.sh"
echo -e "${GREEN}✅ Git hooks setup script created${NC}"

# Copy PR-Agent configuration
echo -e "${BLUE}⚙️  Creating PR-Agent configuration...${NC}"
if [ -f "$TEMP_DIR/pr-agent-repo/.pr_agent.toml" ]; then
    cp "$TEMP_DIR/pr-agent-repo/.pr_agent.toml" "$REPO_ROOT/"
    echo -e "${GREEN}✅ PR-Agent configuration copied${NC}"
else
    # Create basic configuration
    cat > "$REPO_ROOT/.pr_agent.toml" << 'EOF'
[config]
git_provider = "local"
publish_output = false

[pr_reviewer]
require_score_review = false
require_soc2_review = true
require_can_be_split_review = false
enable_review_labels_effort = false
enable_review_labels_security = true
EOF
    echo -e "${GREEN}✅ Basic PR-Agent configuration created${NC}"
fi

# Create .env template if it doesn't exist
if [ ! -f "$REPO_ROOT/.env" ]; then
    echo -e "${BLUE}📝 Creating .env template...${NC}"
    cat > "$REPO_ROOT/.env" << 'EOF'
# OpenAI API Key for PR-Agent (REQUIRED)
OPENAI_API_KEY=your-openai-api-key-here

# Optional: Other AI providers
# ANTHROPIC_KEY=your-anthropic-key
# GOOGLE_AI_STUDIO_GEMINI_API_KEY=your-gemini-key

# Optional: PR-Agent specific settings
# PR_AGENT_MAX_TOKENS=8000
# PR_AGENT_MODEL=gpt-4o-mini
EOF
    echo -e "${YELLOW}⚠️  Please edit .env file and add your OPENAI_API_KEY${NC}"
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi

# Add files to .gitignore
echo -e "${BLUE}🔒 Updating .gitignore...${NC}"
if [ -f "$REPO_ROOT/.gitignore" ]; then
    # Add .env if not already there
    if ! grep -q "^\.env$" "$REPO_ROOT/.gitignore"; then
        echo ".env" >> "$REPO_ROOT/.gitignore"
        echo -e "${GREEN}✅ Added .env to .gitignore${NC}"
    fi
    # Note: PR-Agent now prints results directly, no output files to ignore
    # Add .cursor-pr-agent/ if not already there
    if ! grep -q "^\.cursor-pr-agent/$" "$REPO_ROOT/.gitignore"; then
        echo -e "\n# PR-Agent integration files\n.cursor-pr-agent/" >> "$REPO_ROOT/.gitignore"
        echo -e "${GREEN}✅ Added .cursor-pr-agent/ to .gitignore${NC}"
    fi
    # Add Python cache files if not already there
    if ! grep -q "__pycache__/" "$REPO_ROOT/.gitignore"; then
        echo -e "\n# Python cache files\n__pycache__/\n*.py[cod]\n*$py.class" >> "$REPO_ROOT/.gitignore"
        echo -e "${GREEN}✅ Added Python cache patterns to .gitignore${NC}"
    fi
    # Add PR-Agent config files if not already there
    if ! grep -q "\.pr_agent\.toml" "$REPO_ROOT/.gitignore"; then
        echo -e "\n# PR-Agent configuration\n.pr_agent.toml\ninstall-pr-agent-complete.sh\n\n# Docker setup files (downloaded for setup)\nDockerfile.standalone\ndocker-run.sh" >> "$REPO_ROOT/.gitignore"
        echo -e "${GREEN}✅ Added PR-Agent config files to .gitignore${NC}"
    fi
else
    echo -e "${BLUE}🔒 Creating .gitignore...${NC}"
    cat > "$REPO_ROOT/.gitignore" << 'EOF'
# Environment variables
.env

# PR-Agent integration files
.cursor-pr-agent/

# PR-Agent configuration
.pr_agent.toml
install-pr-agent-complete.sh

# Docker setup files (downloaded for setup)
Dockerfile.standalone
docker-run.sh

# Python cache files
__pycache__/
*.py[cod]
*$py.class
EOF
    echo -e "${GREEN}✅ .gitignore created${NC}"
fi

# Create comprehensive README
echo -e "${BLUE}📚 Creating documentation...${NC}"
cat > "$INSTALL_DIR/README.md" << 'EOF'
# 🚀 PR-Agent Integration

Complete integration of [qodo-ai/pr-agent](https://github.com/qodo-ai/pr-agent) for automated code review.

## 🎯 What This Provides

- **Automated Code Review**: AI-powered analysis of your code changes
- **Security Scanning**: Detects vulnerabilities, injection attacks, secrets
- **Code Quality**: Identifies bugs, performance issues, best practices
- **Confidence Levels**: Filter suggestions by High/Medium/Low confidence
- **Git Integration**: Automatic reviews on commits via git hooks

## 📋 Files in This Directory

- `cursor_pr_agent_direct.py` - Main integration script
- `setup-hooks.sh` - Git hooks installer
- `requirements.txt` - Python dependencies
- `README.md` - This documentation
- `pr_agent/` - Local PR-Agent installation (if pip install failed)

## 🚀 Quick Start

### 1. Configure API Key
Edit the `.env` file in your repository root:
```bash
OPENAI_API_KEY=your-actual-api-key-here
```

### 2. Test the Integration
```bash
# Manual review of current branch vs main
./.cursor-pr-agent/cursor_pr_agent_direct.py

# High confidence issues only
./.cursor-pr-agent/cursor_pr_agent_direct.py --confidence-level high

# Compare against different branch
./.cursor-pr-agent/cursor_pr_agent_direct.py --base-branch develop
```

### 3. Set Up Automatic Reviews (Optional)
```bash
# Install git hooks for automatic reviews on commits
./.cursor-pr-agent/setup-hooks.sh
```

## 🔧 Usage Examples

### Manual Reviews
```bash
# Basic review (medium confidence)
./.cursor-pr-agent/cursor_pr_agent_direct.py

# High priority issues only
./.cursor-pr-agent/cursor_pr_agent_direct.py -c high

# All issues including low confidence
./.cursor-pr-agent/cursor_pr_agent_direct.py -c low

# Compare against specific branch
./.cursor-pr-agent/cursor_pr_agent_direct.py -b develop

# Verbose output for debugging
./.cursor-pr-agent/cursor_pr_agent_direct.py -v
```

### Automatic Reviews
After running `setup-hooks.sh`, reviews will run automatically:
- **Pre-commit**: Reviews staged changes before commit
- **Post-commit**: Reviews changes after commit
- **Smart skipping**: Skips on main/master branches and when no API key

## 🎛️ Configuration

### Confidence Levels
- **High**: Only critical security issues and definite bugs
- **Medium** (default): Important issues with good confidence
- **Low**: All suggestions including minor improvements

### Environment Variables
Set in your `.env` file:
```bash
# Required
OPENAI_API_KEY=your-key-here

# Optional
PR_AGENT_MAX_TOKENS=8000
PR_AGENT_MODEL=gpt-4o-mini
```

### PR-Agent Settings
Modify `.pr_agent.toml` in your repository root for advanced configuration.

## 📊 Output

Reviews are saved to `pr_agent_review.md` with:
- Security vulnerabilities
- Code quality issues
- Performance suggestions
- Best practice recommendations
- Confidence ratings for each suggestion

## 🛠️ Troubleshooting

### "PR-Agent not available" Error
```bash
# Reinstall dependencies
pip3 install --user -r .cursor-pr-agent/requirements.txt

# Or manually install core packages
pip3 install --user pr-agent PyYAML python-dotenv openai
```

### "ModuleNotFoundError: No module named 'yaml'" or similar
```bash
# Install missing dependencies
pip3 install --user -r .cursor-pr-agent/requirements.txt

# Or install specific missing package
pip3 install --user PyYAML python-dotenv
```

### "Repository has uncommitted changes"
```bash
git add . && git commit -m "Save changes"
# OR
git stash
```

### "OPENAI_API_KEY not found"
1. Check your `.env` file exists
2. Verify the API key format: `OPENAI_API_KEY=sk-...`
3. Make sure `.env` is in your repository root

### No Changes Detected
- Make sure you're on a feature branch (not main/master)
- Ensure there are actual differences: `git diff main..HEAD`

## 🔗 Links

- [Official PR-Agent Repository](https://github.com/qodo-ai/pr-agent)
- [PR-Agent Documentation](https://qodo-merge-docs.qodo.ai/)
- [OpenAI API Keys](https://platform.openai.com/api-keys)

## 🤝 Support

For issues with:
- **This integration**: Check the troubleshooting section above
- **PR-Agent itself**: Visit the [official repository](https://github.com/qodo-ai/pr-agent)
- **OpenAI API**: Check [OpenAI's documentation](https://platform.openai.com/docs)
EOF

echo -e "${GREEN}✅ Documentation created${NC}"

# Final summary
echo ""
echo -e "${GREEN}${BOLD}🎉 Installation Complete!${NC}"
echo ""
echo -e "${CYAN}📋 What was installed:${NC}"
echo -e "${BLUE}  • PR-Agent package and dependencies${NC}"
echo -e "${BLUE}  • Requirements file: $INSTALL_DIR/requirements.txt${NC}"
echo -e "${BLUE}  • Integration script: $INSTALL_DIR/cursor_pr_agent_direct.py${NC}"
echo -e "${BLUE}  • Git hooks setup: $INSTALL_DIR/setup-hooks.sh${NC}"
echo -e "${BLUE}  • Configuration: .pr_agent.toml${NC}"
echo -e "${BLUE}  • Environment template: .env${NC}"
echo -e "${BLUE}  • Documentation: $INSTALL_DIR/README.md${NC}"
echo -e "${BLUE}  • Updated .gitignore${NC}"
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo -e "${YELLOW}1. Edit .env file and add your OPENAI_API_KEY${NC}"
echo -e "${BLUE}2. Test the integration:${NC}"
echo -e "${BLUE}   ./.cursor-pr-agent/cursor_pr_agent_direct.py --base-branch main${NC}"
echo -e "${BLUE}3. Set up automatic git hooks (optional):${NC}"
echo -e "${BLUE}   ./.cursor-pr-agent/setup-hooks.sh${NC}"
echo ""
echo -e "${CYAN}💡 Usage Examples:${NC}"
echo -e "${BLUE}  # Manual review${NC}"
echo -e "${BLUE}  ./.cursor-pr-agent/cursor_pr_agent_direct.py${NC}"
echo ""
echo -e "${BLUE}  # High priority issues only${NC}"
echo -e "${BLUE}  ./.cursor-pr-agent/cursor_pr_agent_direct.py --confidence-level high${NC}"
echo ""
echo -e "${BLUE}  # Compare against develop branch${NC}"
echo -e "${BLUE}  ./.cursor-pr-agent/cursor_pr_agent_direct.py --base-branch develop${NC}"
echo ""
echo -e "${GREEN}${BOLD}🎊 Happy coding with AI-powered code review!${NC}"
echo ""
echo -e "${BLUE}📖 For detailed documentation, see: $INSTALL_DIR/README.md${NC}"
