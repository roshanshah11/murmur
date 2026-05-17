#!/bin/bash
# Murmur v1.0 — GitHub release setup helper.
# Run from the repo root after you've finished local commits.
# Requires: gh CLI authenticated (gh auth status).
#
# Usage:
#   ./scripts/release-setup.sh                  # run all steps
#   ./scripts/release-setup.sh --dry-run        # print commands without running
#   VERSION=1.0.0 ./scripts/release-setup.sh    # also create draft release tag

set -euo pipefail

# ---------- config ----------
OWNER="roshanshah11"
OLD_NAME="voicemodel"
NEW_NAME="murmur"
TAP_NAME="homebrew-murmur"
PAGES_BRANCH="gh-pages"
DEFAULT_BRANCH="main"
VERSION="${VERSION:-}"

# ---------- flags ----------
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,11p' "$0"
      exit 0
      ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

# ---------- helpers ----------
c_green=$'\033[0;32m'
c_yellow=$'\033[0;33m'
c_red=$'\033[0;31m'
c_blue=$'\033[0;34m'
c_dim=$'\033[2m'
c_reset=$'\033[0m'

step() { printf '\n%s==> %s%s\n' "$c_blue" "$1" "$c_reset"; }
ok()   { printf '   %s✓ %s%s\n' "$c_green" "$1" "$c_reset"; }
skip() { printf '   %s↷ skipped: %s%s\n' "$c_yellow" "$1" "$c_reset"; }
fail() { printf '   %s✗ %s%s\n' "$c_red" "$1" "$c_reset"; exit 1; }

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '   %s$ %s%s\n' "$c_dim" "$*" "$c_reset"
  else
    "$@"
  fi
}

run_capture() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '   %s$ %s%s\n' "$c_dim" "$*" "$c_reset"
    echo ""
  else
    "$@"
  fi
}

require() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

# ---------- preflight ----------
step "Preflight"
require gh
require git
if [[ $DRY_RUN -eq 0 ]]; then
  gh auth status >/dev/null 2>&1 || fail "gh not authenticated — run: gh auth login"
fi
ok "gh + git ready (dry-run=$DRY_RUN)"

# Detect what the repo is currently called on GitHub.
CURRENT_REMOTE_NAME=""
if [[ $DRY_RUN -eq 0 ]]; then
  CURRENT_REMOTE_NAME="$(gh api "repos/$OWNER/$NEW_NAME" --jq .name 2>/dev/null || true)"
fi

# ---------- 1. rename repo ----------
step "1. Rename repo $OWNER/$OLD_NAME -> $OWNER/$NEW_NAME"
if [[ "$CURRENT_REMOTE_NAME" == "$NEW_NAME" ]]; then
  skip "$OWNER/$NEW_NAME already exists"
else
  # Confirm the old repo exists before attempting rename.
  if [[ $DRY_RUN -eq 0 ]]; then
    gh api "repos/$OWNER/$OLD_NAME" >/dev/null 2>&1 \
      || fail "cannot find $OWNER/$OLD_NAME — already renamed or you lack access?"
  fi
  run gh api "repos/$OWNER/$OLD_NAME" -X PATCH -f "name=$NEW_NAME"
  ok "renamed to $OWNER/$NEW_NAME"
fi

# ---------- 2. update local origin ----------
step "2. Point local origin at the new URL"
CURRENT_ORIGIN=""
if [[ $DRY_RUN -eq 0 ]]; then
  CURRENT_ORIGIN="$(git remote get-url origin 2>/dev/null || echo '')"
fi
NEW_ORIGIN="git@github.com:$OWNER/$NEW_NAME.git"
if [[ "$CURRENT_ORIGIN" == "$NEW_ORIGIN" ]]; then
  skip "origin already $NEW_ORIGIN"
else
  run git remote set-url origin "$NEW_ORIGIN"
  ok "origin -> $NEW_ORIGIN"
fi

# ---------- 3. enable GitHub Pages ----------
step "3. Enable GitHub Pages on $PAGES_BRANCH"
PAGES_STATUS=""
if [[ $DRY_RUN -eq 0 ]]; then
  PAGES_STATUS="$(gh api "repos/$OWNER/$NEW_NAME/pages" --jq .status 2>/dev/null || true)"
fi
if [[ -n "$PAGES_STATUS" ]]; then
  skip "Pages already enabled (status: $PAGES_STATUS)"
else
  # Ensure the branch exists on the remote before turning Pages on.
  if [[ $DRY_RUN -eq 0 ]]; then
    if ! git ls-remote --exit-code --heads origin "$PAGES_BRANCH" >/dev/null 2>&1; then
      printf '   %s! %s branch missing on origin — creating empty orphan%s\n' "$c_yellow" "$PAGES_BRANCH" "$c_reset"
      tmp_worktree="$(mktemp -d)"
      git worktree add --detach "$tmp_worktree" >/dev/null
      (
        cd "$tmp_worktree"
        git checkout --orphan "$PAGES_BRANCH"
        git rm -rf . >/dev/null 2>&1 || true
        echo "Murmur docs placeholder" > index.html
        git add index.html
        git commit -m "chore: initialize gh-pages" >/dev/null
        git push origin "$PAGES_BRANCH"
      )
      git worktree remove --force "$tmp_worktree"
    fi
  fi
  # Enable Pages itself.
  run gh api "repos/$OWNER/$NEW_NAME" -X PATCH -f has_pages=true
  # Pin Pages to the gh-pages branch root. (POST creates, PUT updates.)
  if [[ $DRY_RUN -eq 1 ]]; then
    run gh api "repos/$OWNER/$NEW_NAME/pages" -X POST \
        -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/"
  else
    gh api "repos/$OWNER/$NEW_NAME/pages" -X POST \
        -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null 2>&1 \
      || gh api "repos/$OWNER/$NEW_NAME/pages" -X PUT \
            -f "source[branch]=$PAGES_BRANCH" -f "source[path]=/" >/dev/null
  fi
  ok "Pages serving $PAGES_BRANCH:/"
fi

# ---------- 4. branch protection ----------
step "4. Protect $DEFAULT_BRANCH"
PROTECTED=""
if [[ $DRY_RUN -eq 0 ]]; then
  PROTECTED="$(gh api "repos/$OWNER/$NEW_NAME/branches/$DEFAULT_BRANCH/protection" --jq .url 2>/dev/null || true)"
fi
if [[ -n "$PROTECTED" ]]; then
  skip "$DEFAULT_BRANCH already protected"
else
  # Require PRs + 1 approval + status checks (CI, SwiftLint). Linear history, no force-push.
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '   %s$ gh api ... branch protection PUT%s\n' "$c_dim" "$c_reset"
  else
    gh api -X PUT "repos/$OWNER/$NEW_NAME/branches/$DEFAULT_BRANCH/protection" \
      -H "Accept: application/vnd.github+json" \
      --input - >/dev/null <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI", "SwiftLint"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
  fi
  ok "$DEFAULT_BRANCH protected (PR + 1 review + CI/SwiftLint)"
fi

# ---------- 5. create homebrew tap ----------
step "5. Create $OWNER/$TAP_NAME"
TAP_EXISTS=""
if [[ $DRY_RUN -eq 0 ]]; then
  TAP_EXISTS="$(gh api "repos/$OWNER/$TAP_NAME" --jq .name 2>/dev/null || true)"
fi
if [[ -n "$TAP_EXISTS" ]]; then
  skip "$OWNER/$TAP_NAME already exists"
else
  run gh repo create "$OWNER/$TAP_NAME" --public \
      --description "Homebrew tap for Murmur" \
      --homepage "https://github.com/$OWNER/$NEW_NAME"
  ok "tap created — release.yml will push Formula/murmur.rb here"
fi

# ---------- 6. FUNDING.yml sanity check ----------
step "6. Verify FUNDING.yml"
FUNDING_PATH=".github/FUNDING.yml"
if [[ -f "$FUNDING_PATH" ]]; then
  ok "$FUNDING_PATH present locally"
  if [[ $DRY_RUN -eq 0 ]]; then
    # Confirm GitHub sees it on the default branch.
    if gh api "repos/$OWNER/$NEW_NAME/contents/$FUNDING_PATH" --jq .name >/dev/null 2>&1; then
      ok "Sponsor button live on $OWNER/$NEW_NAME"
    else
      printf '   %s! FUNDING.yml not yet on origin — push %s and refresh the repo page%s\n' \
        "$c_yellow" "$DEFAULT_BRANCH" "$c_reset"
    fi
  fi
else
  printf '   %s! %s missing — create it with github_sponsors / ko_fi / custom entries%s\n' \
    "$c_yellow" "$FUNDING_PATH" "$c_reset"
fi

# ---------- 7. draft release ----------
step "7. Draft release"
if [[ -z "$VERSION" ]]; then
  skip "VERSION not set (export VERSION=1.0.0 to create v1.0.0 draft)"
else
  TAG="v$VERSION"
  EXISTS=""
  if [[ $DRY_RUN -eq 0 ]]; then
    EXISTS="$(gh release view "$TAG" --json tagName --jq .tagName 2>/dev/null || true)"
  fi
  if [[ "$EXISTS" == "$TAG" ]]; then
    skip "$TAG release already exists"
  else
    NOTES_FLAG=()
    if [[ -f CHANGELOG.md ]]; then
      NOTES_FLAG=(--notes-file CHANGELOG.md)
    else
      NOTES_FLAG=(--generate-notes)
    fi
    run gh release create "$TAG" --draft --title "Murmur $VERSION" "${NOTES_FLAG[@]}"
    ok "draft release $TAG created — review & publish from the web UI"
  fi
fi

# ---------- done ----------
printf '\n%sAll steps complete.%s\n' "$c_green" "$c_reset"
printf 'Next: open %shttps://github.com/%s/%s%s and confirm Pages + Sponsor button + Releases tab.\n' \
  "$c_blue" "$OWNER" "$NEW_NAME" "$c_reset"
