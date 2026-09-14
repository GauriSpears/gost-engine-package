#!/usr/bin/env bash
# Emit GitHub Actions matrix.include JSON: last + previous major for Debian & Alma, plus Arch rolling.
set -euo pipefail

fetch_cycles() {
  local product="$1"
  curl -fsSL --retry 3 --retry-delay 2 "https://endoflife.date/api/${product}.json" 2>/dev/null || echo "[]"
}

# Returns up to 2 newest non-EOL cycle names (major), newline-separated
two_latest_majors() {
  local json="$1"
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required" >&2
    return 1
  fi
  # Prefer cycles that are not eol; sort by release/newest first via cycle as number when possible
  echo "$json" | jq -r '
    [.[]
      | select((.eol | tostring | ascii_downcase) != "true")
      | select(.cycle != null)
      | {cycle: (.cycle | tostring), release: (.release // .cycle | tostring)}
    ]
    | sort_by(.release) | reverse
    | [.[].cycle]
    | unique
    | .[0:2]
    | .[]
  ' 2>/dev/null || true
}

items="[]"

# --- Debian ---
deb_json=$(fetch_cycles debian)
deb_majors=$(two_latest_majors "$deb_json" || true)
if [[ -z "${deb_majors//[$'\n']/}" ]]; then
  # fallback if API fails
  deb_majors=$'13\n12'
fi
while IFS= read -r maj; do
  [[ -z "$maj" ]] && continue
  # cycle might be "13" or "13.x" — take leading integer
  ver=$(echo "$maj" | sed -n 's/^\([0-9][0-9]*\).*/\1/p')
  [[ -z "$ver" ]] && continue
  img="debian:$ver"     
  items=$(jq -c --arg d debian --arg v "$ver" --arg i "$img" --arg p deb \
    '. + [{distro:$d, version:$v, image:$i, pkg:$p}]' <<<"$items")
done <<< "$deb_majors"

# --- AlmaLinux (RHEL-compatible) ---
alma_json=$(fetch_cycles almalinux)
alma_majors=$(two_latest_majors "$alma_json" || true)
if [[ -z "${alma_majors//[$'\n']/}" ]]; then
  alma_majors=$'10\n9'
fi
while IFS= read -r maj; do
  [[ -z "$maj" ]] && continue
  ver=$(echo "$maj" | sed -n 's/^\([0-9][0-9]*\).*/\1/p')
  [[ -z "$ver" ]] && continue
  img="almalinux:${ver}"
  items=$(jq -c --arg d almalinux --arg v "$ver" --arg i "$img" --arg p rpm \
    '. + [{distro:$d, version:$v, image:$i, pkg:$p}]' <<<"$items")
done <<< "$alma_majors"

# --- Arch (rolling only) ---
items=$(jq -c '. + [{distro:"arch", version:"rolling", image:"archlinux:latest", pkg:"arch"}]' <<<"$items")

# Deduplicate by distro+version
items=$(jq -c 'unique_by(.distro + "-" + .version)' <<<"$items")

echo "$items"
