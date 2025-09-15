#!/bin/bash

# Self-contained Docker runner for PR-Agent
# No need to clone any repository - everything is embedded!

set -e

echo "🐳 PR-Agent Standalone Docker Runner"
echo "===================================="

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Create the Dockerfile on-the-fly
echo "📦 Creating Docker image (one-time setup)..."

# Check if image already exists
if docker image inspect pr-agent-standalone >/dev/null 2>&1; then
    echo "✅ Using existing pr-agent-standalone image"
else
    echo "🔧 Building pr-agent-standalone image..."
    
    # Create temporary directory for build context
    TEMP_DIR=$(mktemp -d)
    
    # Copy the Dockerfile to temp directory
    if [ -f "Dockerfile.standalone" ]; then
        cp Dockerfile.standalone "$TEMP_DIR/Dockerfile"
    else
        echo "❌ Dockerfile.standalone not found"
        echo "💡 Make sure you're running this from the pr-agent directory"
        exit 1
    fi
    
    # Build the image
    docker build -t pr-agent-standalone "$TEMP_DIR"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    echo "✅ Image built successfully!"
fi

echo ""
echo "🚀 Usage Examples:"
echo ""
echo "1. Set your API key once:"
echo "   export OPENAI_API_KEY=sk-your-key"
echo ""
echo "2. One-time review (auto-detects API key):"
echo "   ./docker-run.sh"
echo ""
echo "3. High confidence only:"
echo "   ./docker-run.sh -c high"
echo ""
echo "4. Persistent mode with git hooks:"
echo "   ./docker-run.sh --persistent"
echo ""
echo "5. Setup hooks and exit:"
echo "   ./docker-run.sh --setup-hooks"
echo ""

# Check if we should just show help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    docker run --rm pr-agent-standalone --help
    exit 0
fi

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository"
    echo "💡 Navigate to your project root and run again"
    exit 1
fi

# Check for API key
if [ -z "$OPENAI_API_KEY" ] && [ ! -f ".env" ]; then
    echo "❌ Error: OPENAI_API_KEY not found"
    echo "💡 Either:"
    echo "   1. Set in your shell: export OPENAI_API_KEY=sk-your-key"
    echo "   2. Or create .env file with: OPENAI_API_KEY=your-key"
    exit 1
fi

# Run the Docker container
echo "🤖 Running PR-Agent in Docker..."
echo ""

# Determine if we need persistent mode
if [[ "$*" == *"--persistent"* ]]; then
    # Run without --rm for persistent mode
    docker run -v "$(pwd)":/workspace -e OPENAI_API_KEY pr-agent-standalone "$@"
else
    # Run with --rm for one-time execution
    docker run --rm -v "$(pwd)":/workspace -e OPENAI_API_KEY pr-agent-standalone "$@"
fi
