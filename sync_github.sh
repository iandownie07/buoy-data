#!/bin/bash

set -e

cd /home/ian/buoy_ekf/github

echo "===== $(date -u '+%Y-%m-%d %H:%M:%S UTC') ====="

# --------------------------------------------------------------------
# Recover from an interrupted previous run
# --------------------------------------------------------------------
if ! git diff --cached --quiet; then
    echo "Found leftover staged changes. Cleaning index..."
    git reset HEAD .
fi

# --------------------------------------------------------------------
# Check repository integrity
# --------------------------------------------------------------------
if ! git fsck --no-progress >/dev/null 2>&1; then
    echo "Repository appears corrupted. Aborting."
    exit 1
fi

# --------------------------------------------------------------------
# Check network
# --------------------------------------------------------------------
if ! ping -c1 github.com >/dev/null 2>&1; then
    echo "GitHub unreachable. Skipping sync."
    exit 0
fi

# --------------------------------------------------------------------
# Synchronise with GitHub FIRST
# --------------------------------------------------------------------
echo "Fetching latest changes..."
git fetch origin

echo "Rebasing..."
if ! git pull --rebase origin main; then
    echo "Rebase failed."
    git rebase --abort || true
    exit 1
fi

# --------------------------------------------------------------------
# Export latest CSVs
# --------------------------------------------------------------------
echo "Exporting CSVs..."
/home/ian/buoy_ekf/.venv/bin/python3 /home/ian/buoy_ekf/export/export_csv.py

# --------------------------------------------------------------------
# Update heartbeat
# --------------------------------------------------------------------
date -u +"%Y-%m-%dT%H:%M:%SZ" > heartbeat.txt

# --------------------------------------------------------------------
# Stage files
# --------------------------------------------------------------------
git add *.csv heartbeat.txt

# Nothing changed?
if git diff --cached --quiet; then
    echo "No changes."
    exit 0
fi

# --------------------------------------------------------------------
# Decide commit message
# --------------------------------------------------------------------
if git diff --cached --name-only | grep -qv '^heartbeat.txt$'; then
    MESSAGE="Automatic buoy update $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
else
    MESSAGE="Heartbeat $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
fi

git commit -m "$MESSAGE"

# --------------------------------------------------------------------
# Push
# --------------------------------------------------------------------
echo "Pushing..."

if git push origin main; then
    echo "Push successful."
else
    echo "Push failed. Undoing commit..."
    git reset --mixed HEAD~1
    exit 1
fi

echo "Finished."
