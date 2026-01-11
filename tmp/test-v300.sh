#!/bin/bash

# =============================================================================
# Test Script for Agent OS v3.0.0
# Swaps symlink, tests installation, then restores original
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FORK_DIR="/Users/darrindemchuk/code/side_projects/agent-os"
ORIGINAL_DIR="$HOME/agent-os"
BACKUP_DIR="$HOME/agent-os-original"
TEST_PROJECT="/tmp/test-agent-os-300"

cleanup() {
    echo ""
    echo -e "${YELLOW}=== Cleaning up ===${NC}"

    # Restore original if backup exists
    if [[ -d "$BACKUP_DIR" ]]; then
        echo "Restoring original agent-os..."
        rm -f "$ORIGINAL_DIR" 2>/dev/null || rm -rf "$ORIGINAL_DIR" 2>/dev/null || true
        mv "$BACKUP_DIR" "$ORIGINAL_DIR"
        echo -e "${GREEN}✓ Original agent-os restored${NC}"
    fi

    echo ""
    echo -e "${BLUE}Test project left at: $TEST_PROJECT${NC}"
    echo "You can inspect it or remove with: rm -rf $TEST_PROJECT"
}

# Set trap to cleanup on exit or error
trap cleanup EXIT

echo -e "${BLUE}=== Agent OS v3.0.0 Test Script ===${NC}"
echo ""

# Step 1: Check preconditions
echo -e "${YELLOW}=== Step 1: Checking preconditions ===${NC}"

if [[ ! -d "$FORK_DIR" ]]; then
    echo -e "${RED}Error: Fork directory not found at $FORK_DIR${NC}"
    exit 1
fi

if [[ ! -d "$ORIGINAL_DIR" ]] && [[ ! -L "$ORIGINAL_DIR" ]]; then
    echo -e "${YELLOW}Warning: No existing agent-os at $ORIGINAL_DIR${NC}"
    echo "Will create symlink without backup"
    NO_BACKUP=true
fi

if [[ -d "$BACKUP_DIR" ]]; then
    echo -e "${RED}Error: Backup already exists at $BACKUP_DIR${NC}"
    echo "Please remove it first: rm -rf $BACKUP_DIR"
    exit 1
fi

echo -e "${GREEN}✓ Preconditions met${NC}"
echo ""

# Step 2: Backup and swap
echo -e "${YELLOW}=== Step 2: Swapping agent-os symlink ===${NC}"

if [[ "$NO_BACKUP" != "true" ]]; then
    echo "Backing up $ORIGINAL_DIR to $BACKUP_DIR..."
    mv "$ORIGINAL_DIR" "$BACKUP_DIR"
fi

echo "Creating symlink: $ORIGINAL_DIR -> $FORK_DIR"
ln -s "$FORK_DIR" "$ORIGINAL_DIR"
echo -e "${GREEN}✓ Symlink created${NC}"
echo ""

# Step 3: Create test project
echo -e "${YELLOW}=== Step 3: Creating test project ===${NC}"

rm -rf "$TEST_PROJECT"
mkdir -p "$TEST_PROJECT"
cd "$TEST_PROJECT"
git init --quiet

echo -e "${GREEN}✓ Test project created at $TEST_PROJECT${NC}"
echo ""

# Step 4: Run dry-run installation
echo -e "${YELLOW}=== Step 4: Running dry-run installation ===${NC}"
echo ""

# Run with timeout and capture output
~/agent-os/scripts/project-install.sh --dry-run <<< "n" || true

echo ""

# Step 5: Ask to proceed with real installation
echo -e "${YELLOW}=== Step 5: Proceed with actual installation? ===${NC}"
read -p "Run actual installation? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}=== Running actual installation ===${NC}"
    ~/agent-os/scripts/project-install.sh

    echo ""
    echo -e "${YELLOW}=== Step 6: Verifying installation ===${NC}"
    echo ""

    echo -e "${BLUE}--- Schema files ---${NC}"
    ls -la agent-os/schemas/ 2>/dev/null || echo "No schemas directory"
    echo ""

    echo -e "${BLUE}--- Product files ---${NC}"
    ls -la agent-os/product/ 2>/dev/null || echo "No product directory"
    echo ""

    if [[ -f "agent-os/product/findings.json" ]]; then
        echo -e "${BLUE}--- findings.json content ---${NC}"
        cat agent-os/product/findings.json
        echo ""
    fi

    echo -e "${BLUE}--- Config version ---${NC}"
    grep "version:" agent-os/config.yml 2>/dev/null || echo "No config.yml"
    echo ""

    echo -e "${GREEN}=== Installation test complete! ===${NC}"
else
    echo "Skipping actual installation"
fi

echo ""
echo -e "${BLUE}Press Enter to cleanup and restore original agent-os...${NC}"
read

# Cleanup happens automatically via trap
