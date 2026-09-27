#!/usr/bin/env bash
#
# Tag, release, and update the Homebrew formula in one shot.
#
#   ./release.sh <version>          e.g. ./release.sh 0.1.3
#
# The formula builds from the source tarball GitHub generates for the tag, so
# there's no artifact to upload — pushing the tag is enough. Bump the version in
# the tool's source first; this only ships it.
set -euo pipefail
cd "$(dirname "$0")"

version="${1:?usage: ./release.sh <version>}"
name="$(basename "$PWD" | tr '[:upper:]' '[:lower:]')"
tag="v$version"
tap="../homebrew-tap"

command -v gh >/dev/null || { echo "✗ gh not found" >&2; exit 1; }
gh auth status >/dev/null

branch="$(git symbolic-ref --quiet --short HEAD)" || { echo "✗ not on a branch" >&2; exit 1; }
[ "$branch" = main ] || { echo "✗ current branch must be main (found $branch)" >&2; exit 1; }
[ -z "$(git status --porcelain --untracked-files=all)" ] || { echo "✗ working tree must be clean" >&2; exit 1; }

git fetch origin main --tags
git push origin main

git rev-parse -q --verify "refs/tags/$tag" >/dev/null || git tag -a "$tag" -m "$name $tag"
git ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1 || git push origin "$tag"
gh release view "$tag" >/dev/null 2>&1 || gh release create "$tag" --title "$name $tag" --generate-notes

if [ -f "$tap/Formula/$name.rb" ] || [ -f "$tap/Casks/$name.rb" ]; then
  "$tap/bump.sh" "$name" "$version"
else
  echo "△ no Homebrew entry for $name — skipping tap bump"
fi
echo "✓ released $name $tag"
