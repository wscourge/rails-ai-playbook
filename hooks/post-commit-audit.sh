#!/bin/bash
# Post-commit quality audit hook for Claude Code
# Copy to .claude/hooks/post-commit-audit.sh and register in .claude/settings.json
#
# Universal linter checks work out of the box.
# Design system checks (marked CUSTOMIZE) should be tuned per project.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only trigger on git commit commands
if [[ ! "$COMMAND" =~ git[[:space:]]+commit ]]; then
  exit 0
fi

# Get files changed in the most recent commit
FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null)
if [ -z "$FILES" ]; then
  exit 0
fi

# Separate files by type
TSX_FILES=$(echo "$FILES" | grep '\.tsx$' || true)
TS_FILES=$(echo "$FILES" | grep '\.ts$' || true)
ALL_TS=$(echo -e "${TSX_FILES}\n${TS_FILES}" | sed '/^$/d' || true)
CSS_FILES=$(echo "$FILES" | grep '\.css$' || true)
RB_FILES=$(echo "$FILES" | grep '\.rb$' || true)
YML_FILES=$(echo "$FILES" | grep -E '(config/locales|app/frontend/locales)/.*\.yml$' || true)

FAILURES=0
PASSES=0
FAILURE_DETAILS=""
PASS_DETAILS=""

check() {
  local label="$1"
  local result="$2"
  local detail="$3"

  if [ "$result" = "PASS" ]; then
    PASSES=$((PASSES + 1))
    PASS_DETAILS="${PASS_DETAILS}  ✅ ${label}\n"
  else
    FAILURES=$((FAILURES + 1))
    FAILURE_DETAILS="${FAILURE_DETAILS}  ❌ ${label}\n"
    if [ -n "$detail" ]; then
      FAILURE_DETAILS="${FAILURE_DETAILS}$(echo "$detail" | head -10 | sed 's/^/     /')\n"
    fi
  fi
}

# ─── Linters (universal) ────────────────────────────────

if [ -n "$ALL_TS" ]; then
  ESLINT_OUT=$(echo "$ALL_TS" | xargs bunx eslint --no-warn-ignored 2>&1 || true)
  if echo "$ESLINT_OUT" | grep -q "error"; then
    check "ESLint" "FAIL" "$ESLINT_OUT"
  else
    check "ESLint" "PASS"
  fi
else
  check "ESLint (no .ts/.tsx files)" "PASS"
fi

FORMAT_FILES=""
if [ -n "$ALL_TS" ]; then FORMAT_FILES="$ALL_TS"; fi
if [ -n "$CSS_FILES" ]; then FORMAT_FILES=$(echo -e "${FORMAT_FILES}\n${CSS_FILES}" | sed '/^$/d'); fi
if [ -n "$YML_FILES" ]; then FORMAT_FILES=$(echo -e "${FORMAT_FILES}\n${YML_FILES}" | sed '/^$/d'); fi

if [ -n "$FORMAT_FILES" ]; then
  PRETTIER_OUT=$(echo "$FORMAT_FILES" | xargs bunx prettier --check 2>&1 || true)
  if echo "$PRETTIER_OUT" | grep -qE "\[warn\]"; then
    check "Prettier" "FAIL" "$PRETTIER_OUT"
  else
    check "Prettier" "PASS"
  fi
else
  check "Prettier (no formattable files)" "PASS"
fi

if [ -n "$CSS_FILES" ]; then
  STYLELINT_OUT=$(echo "$CSS_FILES" | xargs bunx stylelint 2>&1 || true)
  if echo "$STYLELINT_OUT" | grep -qE "✖|error"; then
    check "Stylelint" "FAIL" "$STYLELINT_OUT"
  else
    check "Stylelint" "PASS"
  fi
else
  check "Stylelint (no .css files)" "PASS"
fi

if [ -n "$ALL_TS" ]; then
  TSC_OUT=$(bunx tsc --noEmit 2>&1 || true)
  TSC_RELEVANT=""
  for f in $ALL_TS; do
    MATCH=$(echo "$TSC_OUT" | grep "^$f" || true)
    if [ -n "$MATCH" ]; then
      TSC_RELEVANT="${TSC_RELEVANT}${MATCH}\n"
    fi
  done
  if [ -z "$TSC_RELEVANT" ]; then
    check "TypeScript" "PASS"
  else
    check "TypeScript" "FAIL" "$(echo -e "$TSC_RELEVANT")"
  fi
else
  check "TypeScript (no .ts/.tsx files)" "PASS"
fi

if [ -n "$RB_FILES" ]; then
  RUBOCOP_OUT=$(echo "$RB_FILES" | xargs bundle exec rubocop --force-exclusion --format simple 2>&1 || true)
  if echo "$RUBOCOP_OUT" | grep -q "no offenses detected"; then
    check "RuboCop" "PASS"
  elif echo "$RUBOCOP_OUT" | grep -qE "[0-9]+ offense"; then
    check "RuboCop" "FAIL" "$RUBOCOP_OUT"
  else
    check "RuboCop" "PASS"
  fi
else
  check "RuboCop (no .rb files)" "PASS"
fi

if [ -n "$YML_FILES" ]; then
  YAMLLINT_OUT=$(echo "$YML_FILES" | xargs yamllint -f parsable 2>&1 || true)
  if echo "$YAMLLINT_OUT" | grep -qE "\[error\]"; then
    check "yamllint" "FAIL" "$YAMLLINT_OUT"
  else
    check "yamllint" "PASS"
  fi
else
  check "yamllint (no locale .yml files)" "PASS"
fi

# ─── Design System Checks (.tsx) — CUSTOMIZE per project ─

if [ -n "$TSX_FILES" ]; then
  HITS=$(echo "$TSX_FILES" | xargs grep -n '\(bg\|text\|border\|shadow\)-\[hsl' 2>/dev/null || true)
  [ -z "$HITS" ] && check "No hardcoded HSL colors" "PASS" || check "No hardcoded HSL — use design tokens" "FAIL" "$HITS"

  HITS=$(echo "$TSX_FILES" | xargs grep -n '<button\b\|<input\b' 2>/dev/null || true)
  [ -z "$HITS" ] && check "No raw <button>/<input>" "PASS" || check "Raw HTML — use shadcn Button/Input" "FAIL" "$HITS"

  HITS=$(echo "$TSX_FILES" | xargs grep -n '`/[a-z].*\${' 2>/dev/null || true)
  [ -z "$HITS" ] && check "No hardcoded routes" "PASS" || check "Hardcoded routes — use path props" "FAIL" "$HITS"

  # CUSTOMIZE: Add project-specific design checks here, e.g.:
  # - Border radius enforcement (rounded vs rounded-lg)
  # - Opacity modifier bans (bg-muted/40)
  # - Frontend date formatting bans (toLocaleDateString)
  # - Frontend data transformation bans (.reduce)
  # - Shadow style enforcement
fi

# ─── Backend Safety (.rb) — universal ────────────────────

if [ -n "$RB_FILES" ]; then
  CONTROLLER_FILES=$(echo "$RB_FILES" | grep 'controllers/' || true)
  if [ -n "$CONTROLLER_FILES" ]; then
    HITS=$(echo "$CONTROLLER_FILES" | xargs grep -n '\(Incident\|Property\|User\)\.find\b' 2>/dev/null | grep -v 'find_visible\|find_by' || true)
    [ -z "$HITS" ] && check "No unscoped .find()" "PASS" || check "Unscoped .find() — use scoped query" "FAIL" "$HITS"
  fi

  HITS=$(echo "$RB_FILES" | xargs grep -n '\.permit!' 2>/dev/null || true)
  [ -z "$HITS" ] && check "No .permit!" "PASS" || check ".permit! — whitelist attributes" "FAIL" "$HITS"
fi

# ─── Output ──────────────────────────────────────────────

FILE_LIST=$(echo "$FILES" | sed 's/^/  /' | tr '\n' '|' | sed 's/|/\\n/g')

if [ "$FAILURES" -gt 0 ]; then
  CONTEXT="POST-COMMIT AUDIT: ❌ ${FAILURES} FAILED / ${PASSES} passed

Files: $(echo "$FILES" | tr '\n' ', ' | sed 's/,$//')

Failures:
$(echo -e "$FAILURE_DETAILS")
FIX ALL FAILURES before moving to next task. See docs/CODE_QUALITY.md."

  jq -n --arg ctx "$CONTEXT" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": $ctx
    }
  }'
else
  CONTEXT="POST-COMMIT AUDIT: ✅ ALL ${PASSES} CHECKS PASSED

Files: $(echo "$FILES" | tr '\n' ', ' | sed 's/,$//')"

  jq -n --arg ctx "$CONTEXT" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": $ctx
    }
  }'
fi

exit 0
