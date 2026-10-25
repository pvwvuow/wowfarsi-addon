#!/usr/bin/env bash
# WoWFarsi release pipeline for pvwvuow/wowfarsi-addon.
#
# Stages (invoked by .github/workflows/release.yml, one call per step):
#   package     - build WoWFarsi-<ver>.zip (WoWFA + WoWFarsi_Quests + all WoWFQ_* folders)
#   github      - create the GitHub Release for the tag and fetch its description
#   curseforge  - upload the same zip to CurseForge with the release description as changelog
#
# Versioning: tag v<ver>  ->  ver = tag without the leading "v".
#   tag contains "-" (e.g. v0.4.3-beta.1) -> GitHub pre-release + CurseForge releaseType "beta"
#   otherwise        (e.g. v0.4.3)        -> GitHub release      + CurseForge releaseType "release"
#
# CurseForge project id resolution order:
#   1. repository variable CF_PROJECT_ID (Settings > Secrets and variables > Actions > Variables)
#   2. "## X-Curse-Project-ID:" header inside the packaged .toc files
#
# The CF changelog always mirrors the GitHub Release description (fetched back
# from the API after creation). Editing the release body after the run does not
# re-upload the changelog.
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-pvwvuow/wowfarsi-addon}"
TAG="${GITHUB_REF_NAME:-}"
if [ -z "$TAG" ]; then
  echo "ERROR: GITHUB_REF_NAME is empty; run against a pushed v* tag." >&2
  exit 1
fi
VER="${TAG#v}"
ZIP="WoWFarsi-${VER}.zip"
WORK="${GITHUB_WORKSPACE:-$PWD}/.release-work"
mkdir -p "$WORK"

case "$VER" in
  *-*) RELEASE_TYPE="beta";   GH_PRERELEASE="--prerelease" ;;
  *)   RELEASE_TYPE="release"; GH_PRERELEASE="" ;;
esac

PACKAGE_DIRS=(WoWFA WoWFarsi_Quests WoWFQ_*)

# Unique numeric "## Interface:" values from every packaged .toc.
toc_interfaces() {
  cat WoWFA/*.toc WoWFarsi_Quests/*.toc WoWFQ_*/*.toc 2>/dev/null \
    | sed -nE 's/^##[[:space:]]*Interface:[[:space:]]*//Ip' \
    | tr ',' '\n' | tr -d ' \r\t' | grep -E '^[0-9]+$' | sort -u
}

# 120105 -> 12.1.5, 11507 -> 1.15.7
iface_to_ver() {
  local n="$1"
  echo "$(( n / 10000 )).$(( (n % 10000) / 100 )).$(( n % 100 ))"
}

stage_package() {
  echo "== package: building $ZIP (releaseType=$RELEASE_TYPE) =="
  rm -f "$ZIP"
  zip -r -X -q "$ZIP" "${PACKAGE_DIRS[@]}" \
    -x '*/.DS_Store' -x '*.pyc' -x '*/__pycache__/*'
  echo "-- zip entries:"
  unzip -l "$ZIP"
  test -s "$ZIP"
  echo "== package: OK =="
}

stage_github() {
  echo "== github: release for $TAG =="
  if ! gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    gh release create "$TAG" "$ZIP" -R "$REPO" \
      --title "WoWFarsi $VER" \
      --generate-notes $GH_PRERELEASE
  else
    echo "release $TAG already exists; skipping creation"
  fi
  gh release view "$TAG" -R "$REPO" --json body -q .body > "$WORK/release_notes.md"
  if [ ! -s "$WORK/release_notes.md" ]; then
    printf 'WoWFarsi %s\n' "$VER" > "$WORK/release_notes.md"
  fi
  echo "-- changelog source (release body), first 15 lines:"
  head -n 15 "$WORK/release_notes.md"
  echo "== github: OK =="
}

stage_curseforge() {
  echo "== curseforge: upload $ZIP (releaseType=$RELEASE_TYPE) =="
  if [ -z "${CF_API_KEY:-}" ]; then
    echo "ERROR: secret CF_API_KEY is not set on this repository." >&2
    exit 1
  fi

  local project_id="${CF_PROJECT_ID:-}"
  if [ -z "$project_id" ] || [ "$project_id" = "0" ]; then
    project_id="$({ cat WoWFA/*.toc WoWFarsi_Quests/*.toc WoWFQ_*/*.toc 2>/dev/null; } \
      | sed -nE 's/^##[[:space:]]*X-Curse-Project-ID:[[:space:]]*([0-9]+).*/\1/Ip' \
      | head -n1)"
  fi
  if [ -z "$project_id" ] || [ "$project_id" = "0" ]; then
    echo "ERROR: CurseForge project id is unknown." >&2
    echo "  Set the repository variable CF_PROJECT_ID (Settings > Secrets and variables > Actions > Variables)," >&2
    echo "  or replace the '## X-Curse-Project-ID: 0' placeholder in the .toc files with the real id." >&2
    exit 1
  fi
  echo "-- project id: $project_id"

  curl -fsS -H "X-Api-Token: $CF_API_KEY" \
    "https://wow.curseforge.com/api/game/versions" -o "$WORK/cf_versions.json"

  local idlist="" iface v ids id
  while IFS= read -r iface; do
    v="$(iface_to_ver "$iface")"
    ids="$(jq -r --arg v "$v" --arg p "${v%.*}." '
      (if type == "object" then .versions else . end)
      | (map(select(.name == $v))) as $exact
      | (if ($exact | length) > 0 then $exact
         else (map(select(.name | startswith($p)))
               | sort_by(.name | split(".") | map(tonumber? // 0))
               | if length > 0 then .[-1:] else [] end)
         end)
      | .[] | .id' "$WORK/cf_versions.json" || true)"
    if [ -z "$ids" ]; then
      echo "WARNING: no CurseForge game version matches '$v' (Interface: $iface)" >&2
    else
      while IFS= read -r id; do
        [ -n "$id" ] || continue
        idlist="$idlist $id"
        echo "-- Interface $iface -> $v -> CF game version id $id"
      done <<< "$ids"
    fi
  done < <(toc_interfaces)

  local game_versions
  game_versions="$(printf '%s\n' $idlist | grep -E '^[0-9]+$' | sort -un | jq -s -c '.')"
  if [ "$game_versions" = "[]" ]; then
    echo "ERROR: could not resolve any CurseForge game version from the toc Interface values." >&2
    exit 1
  fi
  echo "-- game versions: $game_versions"

  local metadata
  metadata="$(jq -n -c \
    --arg displayName "WoWFarsi $VER" \
    --arg releaseType "$RELEASE_TYPE" \
    --rawfile changelog "$WORK/release_notes.md" \
    --argjson gameVersions "$game_versions" \
    '{displayName: $displayName, releaseType: $releaseType,
      changelog: $changelog, changelogType: "markdown",
      gameVersions: $gameVersions}')"
  echo "-- metadata: $metadata"

  local code
  code="$(curl -sS -o "$WORK/cf_response.json" -w '%{http_code}' \
    -X POST -H "X-Api-Token: $CF_API_KEY" \
    -F "file=@$ZIP" \
    -F "metadata=$metadata" \
    "https://wow.curseforge.com/api/projects/$project_id/upload-file")"
  echo "-- CF upload HTTP status: $code"
  cat "$WORK/cf_response.json"; echo
  case "$code" in
    2*) echo "== curseforge: OK ==" ;;
    *)  echo "ERROR: CurseForge upload failed (HTTP $code); see response above." >&2
        exit 1 ;;
  esac
}

case "${1:-}" in
  package)     stage_package ;;
  github)      stage_github ;;
  curseforge)  stage_curseforge ;;
  *)
    echo "usage: $0 {package|github|curseforge}" >&2
    exit 2
    ;;
esac
