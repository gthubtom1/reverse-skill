#!/usr/bin/env bash
# Lightweight scope gate before ACT. Exit 0=ok, 2=not ready, 1=usage/error.
# Usage:
#   bash skills/scripts/case-guard.sh --case-root work/my-case
#   bash skills/scripts/case-guard.sh --case-root work/my-case --force  # compatibility flag; never bypasses scope hard gates
set -euo pipefail

CASE_ROOT=""
FORCE=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -CaseRoot|--case-root) CASE_ROOT="${2:-}"; shift 2 ;;
    -Force|--force) FORCE=1; shift ;;
    -Quiet|--quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Unknown arg: \"$1\"" >&2; exit 1 ;;
  esac
done

info() { [[ $QUIET -eq 1 ]] || echo "$*"; }

if [[ -z "$CASE_ROOT" ]]; then
  echo "ERROR: --case-root required" >&2
  exit 1
fi
if [[ ! -d "$CASE_ROOT" ]]; then
  echo "ERROR: CaseRoot missing: $CASE_ROOT" >&2
  exit 1
fi

SCOPE_PATH="$CASE_ROOT/scope.md"
if [[ ! -f "$SCOPE_PATH" ]]; then
  echo "ERROR: scope.md missing under $CASE_ROOT" >&2
  exit 1
fi

SCOPE="$(cat "$SCOPE_PATH")"
ISSUES=()

# Read fields only from their contract sections. A status-like line in notes,
# evidence, or ops_refs must never satisfy the authorization gate.
section_field() {
  local section="$1"
  local field="$2"
  awk -v wanted_section="$section" -v wanted_field="$field" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    /^##[[:space:]]+/ {
      heading=$0
      sub(/^##[[:space:]]+/, "", heading)
      heading=trim(heading)
      active=(tolower(heading)==tolower(wanted_section))
      next
    }
    active && tolower($0) ~ "^-" "[[:space:]]+" wanted_field ":[[:space:]]*" {
      line=$0
      sub(/^[^:]*:[[:space:]]*/, "", line)
      print trim(line)
      exit
    }
  ' "$SCOPE_PATH"
}

section_field_count() {
  local section="$1"
  local field="$2"
  awk -v wanted_section="$section" -v wanted_field="$field" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    /^##[[:space:]]+/ {
      heading=$0
      sub(/^##[[:space:]]+/, "", heading)
      heading=trim(heading)
      active=(tolower(heading)==tolower(wanted_section))
      next
    }
    active && tolower($0) ~ "^-" "[[:space:]]+" wanted_field ":[[:space:]]*" { count++ }
    END { print count + 0 }
  ' "$SCOPE_PATH"
}

section_field_names() {
  local section="$1"
  awk -v wanted_section="$section" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    /^##[[:space:]]+/ {
      heading=$0
      sub(/^##[[:space:]]+/, "", heading)
      heading=trim(heading)
      active=(tolower(heading)==tolower(wanted_section))
      next
    }
    active && $0 ~ /^-[[:space:]]+[A-Za-z0-9_]+:/ {
      line=$0
      sub(/^-[[:space:]]+/, "", line)
      sub(/:.*/, "", line)
      if (line != "") print tolower(trim(line))
    }
  ' "$SCOPE_PATH"
}

for section in auth in_scope network_profile signoff; do
  section_count="$(awk -v wanted="$section" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    /^##[[:space:]]+/ {
      heading=$0
      sub(/^##[[:space:]]+/, "", heading)
      if (tolower(trim(heading)) == tolower(wanted)) count++
    }
    END { print count + 0 }
  ' "$SCOPE_PATH")"
  [[ "$section_count" == 1 ]] || ISSUES+=("scope section '$section' must appear exactly once (found $section_count)")
  while IFS= read -r field_name; do
    [[ -n "$field_name" ]] || continue
    ISSUES+=("scope field '$field_name' is duplicated in $section")
  done < <(section_field_names "$section" | sort | uniq -d)
 done
for pair in 'auth status' 'network_profile mode' 'signoff ready_for_act'; do
  section="${pair% *}"
  field="${pair##* }"
  count="$(section_field_count "$section" "$field")"
  [[ "$count" == 1 ]] || ISSUES+=("scope field '$field' must appear exactly once (found $count)")
done

auth_granted=0
if [[ "$(section_field auth status | tr '[:upper:]' '[:lower:]')" == "granted" ]]; then
  auth_granted=1
fi
[[ $auth_granted -eq 1 ]] || ISSUES+=("auth.status is not granted")

net_mode="$(section_field network_profile mode | tr '[:upper:]' '[:lower:]')"
if [[ -z "$net_mode" ]]; then
  ISSUES+=("network_profile.mode missing")
else
  case "$net_mode" in
    offline|lab_only|authorized_target_only|unrestricted_lab) ;;
    *) ISSUES+=("network_profile.mode is unsupported: $net_mode") ;;
  esac
fi

# Parse only list entries under in_scope.assets. Notes, auth evidence and
# ops_refs must never satisfy the asset gate.
asset_lines="$(awk '
  BEGIN { inscope=0; inassets=0 }
  function trim(value) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    return value
  }
  /^##[[:space:]]+/ {
    heading=$0
    sub(/^##[[:space:]]+/, "", heading)
    if (tolower(trim(heading)) == "in_scope") { inscope=1; inassets=0; next }
    if (inscope) exit
  }
  inscope && tolower($0) ~ /^-[[:space:]]*assets:[[:space:]]*$/ { inassets=1; next }
  inassets && /^-[[:space:]]+[A-Za-z0-9_]+:/ { inassets=0; next }
  inassets && /^[[:space:]]+-[[:space:]]+/ {
    line=$0
    sub(/^[[:space:]]+-[[:space:]]+/, "", line)
    line=trim(line)
    if (line !~ /^\[[[:space:]]*\]$/ && length(line)>0) print line
  }
' "$SCOPE_PATH")"
has_asset=0
[[ -n "$asset_lines" ]] && has_asset=1
if [[ $has_asset -eq 0 ]]; then
  ISSUES+=("in_scope.assets appears empty")
fi

is_readable_regular_file() {
  local asset="$1"
  local path="$asset"
  [[ -n "$asset" && "$asset" != *://* ]] || return 1
  if [[ "$asset" != /* ]]; then path="$CASE_ROOT/$asset"; fi
  [[ -f "$path" && -r "$path" && ! -L "$path" ]] || return 1
  return 0
}
if [[ "$net_mode" == "offline" ]]; then
  has_local_asset=0
  while IFS= read -r asset; do
    [[ -n "$asset" ]] || continue
    if is_readable_regular_file "$asset"; then
      has_local_asset=1
      break
    fi
  done <<< "$asset_lines"
  if [[ $has_local_asset -eq 0 ]]; then
    ISSUES+=("offline scope has no local in_scope asset that is a readable regular file (unable to determine a local sample)")
  fi
fi

ready=0
if [[ "$(section_field signoff ready_for_act | tr '[:upper:]' '[:lower:]')" == "true" ]]; then
  ready=1
fi
[[ $ready -eq 1 ]] || ISSUES+=("ready_for_act is not true")

if [[ ${#ISSUES[@]} -eq 0 ]]; then
  info "CASE-GUARD OK: $CASE_ROOT"
  exit 0
fi

echo "CASE-GUARD NOT READY: $CASE_ROOT"
for i in "${ISSUES[@]}"; do echo " - $i"; done

if [[ $FORCE -eq 1 ]]; then
  echo "CASE-GUARD: --force does not bypass scope hard gates."
fi

echo "Edit the existing scope.md and continue this case; use a new case name only when initializing a new case."
exit 2
