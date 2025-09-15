# Cursor PR-Agent Integration

Minimal setup to run AI-powered code review locally using PR-Agent with Cursor IDE.

## 🚀 Quick Start

### Option 1: Bash Script (Any OS)
```bash
# Copy and run
curl -O https://raw.githubusercontent.com/your-repo/install-pr-agent-complete.sh
chmod +x install-pr-agent-complete.sh
./install-pr-agent-complete.sh

# Enable git hooks for automatic reviews
./.cursor-pr-agent/setup-hooks.sh
```

### Option 2: Docker (Zero Setup)
```bash
# Copy 2 files: Dockerfile.standalone + docker-run.sh
export OPENAI_API_KEY=sk-your-key
./docker-run.sh --setup-hooks  # This enables git hooks automatically
```

## ⚙️ Setup

1. **Add API Key**: Create `.env` file with `OPENAI_API_KEY=sk-your-key`
2. **Make Executable**: `chmod +x` on script files
3. **Git Repository**: Must be in a git repo with commits

## 🔍 How It Works

The integration works locally by:
- **Git Diff Analysis**: Compares current branch against default branch (main/master)
- **Smart File Filtering**: Excludes binary files, focuses on code changes only
- **Context Loading**: PR-Agent dynamically loads surrounding code context, not just diffs
- **Structured Analysis**: Uses Pydantic models for consistent AI output format
- **Local Execution**: No data sent to PR-Agent servers, uses your OpenAI API directly

## 🪝 Automatic Triggers

**Git Hooks** (auto-installed):
- `pre-commit`: Attempts to review but currently has issues with staged files. pr-agent needs a clean tree, staged uncommitted looks dirty. I tried making temporary branches to work around this but couldn't make it work reliably.
- `post-commit`: Reviews after successful commit (this works reliably)
- Triggers on `git commit` - the post-commit hook is where the actual review happens

**Enable Git Hooks**:
```bash
# After installation, enable the hooks
./.cursor-pr-agent/setup-hooks.sh
```

## 📋 Common Issues

**File Permissions**: 
```bash
chmod +x install-pr-agent-complete.sh
chmod +x docker-run.sh
```

**Issues**:
- Verify key is valid: `echo $OPENAI_API_KEY`
- Check `.env` file exists and contains key
- Ensure no extra spaces/quotes in key
- Images or pdf threw an error

**Dependencies**:
- Python 3.8+ required
- Git repository with at least one commit
- Internet connection for initial setup

**No Review Output**:
- Must have git diff (staged or committed changes)
- Check you're on a feature branch, not main/master
- Binary files are automatically excluded

## 🛡️ Security Analysis Examples

**Found Issues**:
- Hardcoded API keys and secrets
- SQL injection vulnerabilities  
- Command injection risks
- Sensitive data logging (PAN/CVV)
- Weak cryptography (MD5 usage)
- Missing authorization checks
- Insecure HTTP endpoints

## 🔮 Future Ideas

I tried making a VSCode/Cursor extension but couldn't get it to trigger properly from the command palette. The real opportunity I see is working with open-source code editors like Cline. Since PR-Agent's prompts and functions are open source, we could potentially integrate the same review logic directly into other editors that support file-save triggers, rather than relying heavily on PR-Agent's specific implementation.

What's really interesting is the possibility of using something like [Claude Context MCP](https://github.com/zilliztech/claude-context) to create shared context between Cursor and PR-Agent. Right now, Cursor's memory isn't available to other tools, but if we could bridge that gap, we'd have much richer context for code reviews. The Claude Context project does semantic codebase search with hybrid BM25 + vector search, which could give both Cursor and PR-Agent a much deeper understanding of the entire codebase.

## 🧠 PR-Agent Implementation Understanding

From what I can tell, the magic really happens in PR-Agent's prompts and how they structure the problem. They don't just look at the git diff - they dynamically load code around the changes to give the language model proper context. This means the AI sees not just what changed, but understands the surrounding functions and classes.

They also do something clever with the diff formatting itself, transforming the raw git output to make it more understandable for language models. The structured outputs using Pydantic models ensure consistent parsing, which is why we get reliable JSON responses that we can format nicely.

I haven't tried their Pinecone integration yet, but they have vector search capabilities for larger codebases. The `LocalGitProvider` handles all the git operations locally, while `PRReviewer` is the main engine that you can configure for different confidence levels. The `LiteLLMAIHandler` manages the OpenAI API calls with fallback models, which is why it's pretty robust even when the primary model is unavailable.

---

*Minimal setup, maximum insight. AI-powered code review without the complexity.*
