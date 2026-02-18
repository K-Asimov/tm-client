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

if [ ! -f "$CHANGELOG" ]; then
  cat > "$CHANGELOG" <<EOF
# Changelog

All notable changes to this project will be documented in this file.

EOF
fi

TEMP=$(mktemp)
# Read header lines until the first "## [" entry (or end of header)
HEADER_DONE=false
while IFS= read -r line; do
  if [[ "$line" == "## ["* ]]; then
    HEADER_DONE=true
    # Insert new entry before first existing entry
    cat >> "$TEMP" <<EOF

## [$VERSION] - $DATE

### Added
-

### Fixed
-

EOF
  fi
  echo "$line" >> "$TEMP"
  if $HEADER_DONE; then
    # Append rest of file
    break
  fi
done < "$CHANGELOG"

if ! $HEADER_DONE; then
  # No existing entries — append at end
  cat >> "$TEMP" <<EOF

## [$VERSION] - $DATE

### Added
-

### Fixed
-

EOF
fi

# Append remaining lines (after the first "## [" line)
if $HEADER_DONE; then
  tail -n +$(grep -n "^## \[" "$CHANGELOG" | head -1 | cut -d: -f1) "$CHANGELOG" | tail -n +2 >> "$TEMP"
fi

mv "$TEMP" "$CHANGELOG"
echo "    Updated $CHANGELOG"

# --- 3. Open CHANGELOG for editing ---
echo ""
echo "Please review and edit CHANGELOG.md for this release, then press Enter to continue..."
${EDITOR:-vi} "$CHANGELOG"

# --- 4. Commit ---
git add "$PBXPROJ" "$CHANGELOG"
git commit -m "chore: release $TAG"
echo "    Committed changes"

# --- 5. Create annotated tag ---
git tag -a "$TAG" -m "Release $TAG"
echo "    Created tag $TAG"

echo ""
echo "Done! Push with:"
echo "  git push origin main --tags"
