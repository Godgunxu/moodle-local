#!/bin/bash
# Push Moodle project to GitHub
# This script guides you through the GitHub setup and push process

set -e

echo "================================"
echo "GitHub Setup & Push Guide"
echo "================================"
echo ""

# Check if git is initialized
if [ ! -d .git ]; then
    echo "❌ Git repository not initialized"
    echo "Run: git init"
    exit 1
fi

# Check if commits exist
if ! git rev-parse HEAD > /dev/null 2>&1; then
    echo "❌ No commits found"
    echo "Add files and commit first"
    exit 1
fi

echo "✓ Git repository initialized"
echo "✓ Commits found"
echo ""

# Prompt for GitHub username
echo "To push to GitHub, you need:"
echo "1. A GitHub account (https://github.com/signup)"
echo "2. A personal access token or SSH key configured"
echo ""

read -p "Enter your GitHub username: " GITHUB_USER
read -p "Enter repository name (default: moodle-docker-aws): " REPO_NAME

REPO_NAME=${REPO_NAME:-moodle-docker-aws}

echo ""
echo "📝 Repository Details:"
echo "  GitHub User: $GITHUB_USER"
echo "  Repository: $REPO_NAME"
echo "  URL: https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""

# Ask for authentication method
echo "🔐 Authentication Method:"
echo "1. HTTPS with Personal Access Token (recommended for new users)"
echo "2. SSH (faster, if key already configured)"
read -p "Choose method (1 or 2): " AUTH_METHOD

case $AUTH_METHOD in
    1)
        echo ""
        echo "📋 Personal Access Token Steps:"
        echo "1. Go to: https://github.com/settings/tokens"
        echo "2. Click 'Generate new token (classic)'"
        echo "3. Give it these permissions:"
        echo "   - repo (full control)"
        echo "   - read:user"
        echo "4. Copy the token"
        echo ""
        read -sp "Paste your Personal Access Token: " GITHUB_TOKEN
        echo ""
        GIT_URL="https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/$REPO_NAME.git"
        ;;
    2)
        GIT_URL="git@github.com:$GITHUB_USER/$REPO_NAME.git"
        echo "Using SSH"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "📡 Instructions to create repository on GitHub:"
echo "================================"
echo "1. Go to https://github.com/new"
echo "2. Enter repository name: $REPO_NAME"
echo "3. Description: Moodle Docker to AWS Migration"
echo "4. Keep it EMPTY (don't initialize with README)"
echo "5. Click 'Create repository'"
echo "6. GitHub will show commands - you can ignore them"
echo ""
echo "⚠️  IMPORTANT: Create the repository BEFORE pressing Enter below!"
echo "================================"
echo ""
read -p "Press Enter after creating the GitHub repository..."

echo ""
echo "🔗 Adding remote..."
git remote add origin "$GIT_URL" 2>/dev/null || {
    echo "⚠️  Remote 'origin' already exists. Updating..."
    git remote set-url origin "$GIT_URL"
}

echo "✓ Remote added"
echo ""

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "📤 Pushing to GitHub..."
echo "   Branch: $BRANCH"
echo "   URL: https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""

git branch -M main 2>/dev/null || true
git push -u origin main 2>/dev/null || git push -u origin master

echo ""
echo "================================"
echo "✅ Push Complete!"
echo "================================"
echo ""
echo "Your repository is now online at:"
echo "  👉 https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "Next steps:"
echo "1. Visit your repository on GitHub"
echo "2. Check that files are uploaded"
echo "3. Share the link with your team"
echo ""
echo "Future pushes are easier:"
echo "  git add ."
echo "  git commit -m 'Your message'"
echo "  git push origin main"
echo ""
