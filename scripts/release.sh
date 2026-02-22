#!/bin/bash
set -e

VERSION=$1

# --- Validation ---
if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 1.0.0"
  exit 1
fi

if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in semver format (e.g., 1.0.0)"
  exit 1
fi

TAG="v$VERSION"

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Error: Tag $TAG already exists"
  exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: You have uncommitted changes. Please commit or stash them first."
  exit 1
fi

echo "==> Releasing $TAG"

# --- 1. Update version in project.pbxproj ---
PBXPROJ="TMClient.xcodeproj/project.pbxproj"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9.]*;/CURRENT_PROJECT_VERSION = $VERSION;/g" "$PBXPROJ"
echo "    Updated $PBXPROJ"

# --- 2. Update CHANGELOG.md ---
DATE=$(date +%Y-%m-%d)
CHANGELOG="CHANGELOG.md"
PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)

if [ ! -f "$CHANGELOG" ]; then
  cat > "$CHANGELOG" <<EOF
# Changelog

All notable changes to this project will be documented in this file.

EOF
fi

TEMP=$(mktemp)
ENTRY=$(mktemp)
ADDED_ITEMS=$(mktemp)
FIXED_ITEMS=$(mktemp)
CHANGED_ITEMS=$(mktemp)
COMMIT_LOG_ITEMS=$(mktemp)
trap 'rm -f "$TEMP" "$ENTRY" "$ADDED_ITEMS" "$FIXED_ITEMS" "$CHANGED_ITEMS" "$COMMIT_LOG_ITEMS"' EXIT

if [ -n "$PREV_TAG" ]; then
  echo "    Collecting commits from $PREV_TAG..HEAD"
  LOG_RANGE="$PREV_TAG..HEAD"
else
  echo "    No previous tag found. Collecting all commits up to HEAD"
  LOG_RANGE="HEAD"
fi

while IFS= read -r line; do
  commit_hash="${line%%$'\t'*}"
  subject="${line#*$'\t'}"
  [ -z "$subject" ] && continue

  cleaned_subject=$(echo "$subject" | sed -E 's/^(feat|fix|chore|docs|refactor|perf|test|build|ci|style)(\([^)]+\))?!?:[[:space:]]*//')
  [ -z "$cleaned_subject" ] && cleaned_subject="$subject"
  lower_subject=$(echo "$subject" | tr '[:upper:]' '[:lower:]')
  printf -- "- %s %s\n" "$commit_hash" "$subject" >> "$COMMIT_LOG_ITEMS"

  case "$lower_subject" in
    feat*|add*)
      printf -- "- %s\n" "$cleaned_subject" >> "$ADDED_ITEMS"
      ;;
    fix*|bugfix*|hotfix*)
      printf -- "- %s\n" "$cleaned_subject" >> "$FIXED_ITEMS"
      ;;
    *)
      printf -- "- %s\n" "$cleaned_subject" >> "$CHANGED_ITEMS"
      ;;
  esac
done < <(git log --pretty=format:'%h%x09%s' "$LOG_RANGE")

if [ ! -s "$ADDED_ITEMS" ] && [ ! -s "$FIXED_ITEMS" ] && [ ! -s "$CHANGED_ITEMS" ]; then
  printf -- "- No user-facing changes recorded\n" >> "$CHANGED_ITEMS"
fi
if [ ! -s "$COMMIT_LOG_ITEMS" ]; then
  printf -- "- No commits found\n" >> "$COMMIT_LOG_ITEMS"
fi

{
  echo ""
  echo "## [$VERSION] - $DATE"
  echo ""

  if [ -s "$ADDED_ITEMS" ]; then
    echo "### Added"
    cat "$ADDED_ITEMS"
    echo ""
  fi

  if [ -s "$FIXED_ITEMS" ]; then
    echo "### Fixed"
    cat "$FIXED_ITEMS"
    echo ""
  fi

  if [ -s "$CHANGED_ITEMS" ]; then
    echo "### Changed"
    cat "$CHANGED_ITEMS"
    echo ""
  fi
} > "$ENTRY"

awk -v entry_file="$ENTRY" '
BEGIN {
  while ((getline line < entry_file) > 0) {
    entry = entry line ORS
  }
  close(entry_file)
  inserted = 0
}
{
  if (!inserted && $0 ~ /^## \[/) {
    printf "%s", entry
    inserted = 1
  }
  print
}
END {
  if (!inserted) {
    printf "%s", entry
  }
}
' "$CHANGELOG" > "$TEMP"

mv "$TEMP" "$CHANGELOG"
echo "    Updated $CHANGELOG"

# --- 3. Commit ---
git add "$PBXPROJ" "$CHANGELOG"
if [ -n "$PREV_TAG" ]; then
  CHANGES_SCOPE="Changes since $PREV_TAG:"
else
  CHANGES_SCOPE="Changes in this release:"
fi
git commit -m "$(cat <<EOF
chore: release $TAG

Release $TAG ($DATE)

$CHANGES_SCOPE
$(cat "$COMMIT_LOG_ITEMS")
EOF
)"
echo "    Committed changes"

# --- 4. Create annotated tag ---
RELEASE_COMMIT=$(git rev-parse HEAD)
git tag -a "$TAG" "$RELEASE_COMMIT" -m "Release $TAG ($DATE)"
echo "    Created tag $TAG"

echo ""
echo "Done! Push with:"
echo "  git push origin main --tags"
