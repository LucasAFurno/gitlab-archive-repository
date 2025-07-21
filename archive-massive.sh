#!/usr/bin/env bash
set -euo pipefail

# Default configuration
API_URL="https://gitlab.com/api/v4/projects"
TOKEN_FILE="${TOKEN_FILE:-$HOME/.gitlab_token}"
AUTO_CONFIRM=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -h          Show this help message and exit
  -t FILE     Specify token file (default: $TOKEN_FILE)
  -y          Auto-confirm without prompting

Description:
  Reads GitLab project URLs from stdin, archives each via the GitLab API,
  and verifies that they were archived successfully.
EOF
}

# Parse command-line options
while getopts ":ht:y" opt; do
  case $opt in
    h) usage; exit 0 ;;
    t) TOKEN_FILE="$OPTARG" ;;
    y) AUTO_CONFIRM=true ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND -1))

# 1) Load token: prefer GITLAB_TOKEN env, then file, then prompt & save
if [[ -n "${GITLAB_TOKEN:-}" ]]; then
  TOKEN="$GITLAB_TOKEN"
elif [[ -r "$TOKEN_FILE" ]]; then
  TOKEN=$(<"$TOKEN_FILE")
else
  read -rs -p "Enter your GitLab Private Token: " TOKEN
  echo
  mkdir -p "$(dirname "$TOKEN_FILE")"
  echo -n "$TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "✔️  Token saved to $TOKEN_FILE"
fi

# 2) Read all input from stdin
echo -e "\nPaste text containing GitLab project URLs, then press Ctrl-D:"
INPUT=$(cat)

# 3) Extract unique .git URLs
mapfile -t URLS < <(
  grep -oE 'https://gitlab\.com/[^ ]+\.git' <<<"$INPUT" |
  uniq
)

if (( ${#URLS[@]} == 0 )); then
  echo "❌ No valid URLs found. Aborting."
  exit 1
fi

# 4) Display and confirm
echo -e "\nThe following projects will be archived:"
for url in "${URLS[@]}"; do
  echo "  • $url"
done

if ! $AUTO_CONFIRM; then
  read -rp $'\nContinue? (y/N): ' reply
  [[ $reply =~ ^[Yy]$ ]] || { echo "❌ Aborted."; exit 0; }
fi

# 5) Archive and verify each project
for url in "${URLS[@]}"; do
  # Extract project path (e.g. group/name)
  proj=${url#https://gitlab.com/}
  proj=${proj%.git}

  # URL-encode for API
  encoded=$(python3 - <<EOF
import urllib.parse,sys
print(urllib.parse.quote(sys.argv[1], safe=""))
EOF
  "$proj")

  # Archive via API
  if curl -s -f -X POST -H "PRIVATE-TOKEN: $TOKEN" \
        "$API_URL/$encoded/archive" >/dev/null; then
    echo "✅ Archived: $proj"
  else
    echo "❌ Failed to archive: $proj"
  fi

  # Verify archived state
  resp=$(curl -s -H "PRIVATE-TOKEN: $TOKEN" "$API_URL/$encoded")
  archived=$(jq -r '.archived' <<<"$resp")

  if [[ "$archived" == "true" ]]; then
    echo "🔍 Verified: $proj is archived."
  else
    echo "🔍 Verified: $proj is NOT archived."
  fi
  echo
done
