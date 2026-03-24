#!/usr/bin/env bash
# check-orbia-financials.sh
# Checks Orbia's investor relations page for new earnings releases and
# compares the most recent reported year against what's in orbia.html.
# Run monthly via cron, e.g.:
#   0 9 1 * * /home/user/Claude-Code/check-orbia-financials.sh >> /home/user/Claude-Code/orbia-news-check.log 2>&1

set -euo pipefail

ORBIA_HTML="/home/user/Claude-Code/orbia.html"
IR_URL="https://www.orbia.com/investor-relations/investor-news/"
LOG_TAG="[Orbia Financial Check] $(date '+%Y-%m-%d %H:%M')"

echo "$LOG_TAG — Starting check..."

# ── 1. Fetch latest IR headlines ──────────────────────────────────────────────
RAW_HTML=$(curl -fsSL --max-time 20 "$IR_URL" 2>/dev/null || true)

if [[ -z "$RAW_HTML" ]]; then
  echo "$LOG_TAG — WARNING: Could not reach $IR_URL. Check your network connection."
  exit 1
fi

# ── 2. Detect most recently mentioned earnings year in the IR page ────────────
# Looks for patterns like "Full-Year 2025", "Fourth Quarter 2025", etc.
LATEST_YEAR=$(echo "$RAW_HTML" \
  | grep -oE "(Full-Year|Fourth Quarter|Annual) 20[0-9]{2}" \
  | grep -oE "20[0-9]{2}" \
  | sort -n | tail -1 || true)

if [[ -z "$LATEST_YEAR" ]]; then
  echo "$LOG_TAG — WARNING: Could not detect a reported earnings year on the IR page."
  exit 1
fi

echo "$LOG_TAG — Latest earnings year detected on IR page: $LATEST_YEAR"

# ── 3. Detect the most recent year column in orbia.html ──────────────────────
# Looks for <th class="col-year">20XX</th> entries
HTML_LATEST_YEAR=$(grep -oE 'col-year">20[0-9]{2}' "$ORBIA_HTML" \
  | grep -oE "20[0-9]{2}" \
  | sort -n | tail -1 || true)

echo "$LOG_TAG — Latest year column in orbia.html: $HTML_LATEST_YEAR"

# ── 4. Compare and alert ──────────────────────────────────────────────────────
if [[ "$LATEST_YEAR" -gt "$HTML_LATEST_YEAR" ]]; then
  echo ""
  echo "⚠️  ACTION REQUIRED — $LOG_TAG"
  echo "   Orbia IR page references FY${LATEST_YEAR} results,"
  echo "   but orbia.html only goes up to ${HTML_LATEST_YEAR}."
  echo "   Update the financials table in $ORBIA_HTML with reported actuals."
  echo "   IR page: $IR_URL"
  echo ""
else
  echo "$LOG_TAG — ✅ orbia.html is up to date (table year ${HTML_LATEST_YEAR} matches IR page year ${LATEST_YEAR})."
fi
