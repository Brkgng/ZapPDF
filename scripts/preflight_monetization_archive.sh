#!/bin/bash
set -euo pipefail

trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

strip_wrapping_quotes() {
  local value="$1"
  if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
    value="${value#\"}"
    value="${value%\"}"
  elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
    value="${value#\'}"
    value="${value%\'}"
  fi
  printf '%s' "${value}"
}

is_invalid_key() {
  local value="$1"
  [[ -z "${value}" || "${value}" == \$\(*\) || "${value}" == \$\{*\} || "${value}" == "YOUR_PUBLIC_SDK_KEY_HERE" ]]
}

parse_xcconfig_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || return 0

  while IFS= read -r raw_line || [[ -n "${raw_line}" ]]; do
    local line="${raw_line%$'\r'}"
    line="$(trim "${line}")"

    [[ -z "${line}" ]] && continue
    [[ "${line}" == //* ]] && continue
    [[ "${line}" == \#* ]] && continue
    [[ "${line}" != *"="* ]] && continue

    local key="${line%%=*}"
    local value="${line#*=}"
    key="$(trim "${key}")"
    value="$(trim "${value}")"
    value="$(printf '%s' "${value}" | sed -E 's/[[:space:]]+\/\/.*$//')"
    value="$(trim "${value}")"
    value="$(strip_wrapping_quotes "${value}")"

    if [[ "${key}" == "REVENUECAT_API_KEY" ]]; then
      resolved_key_from_files="${value}"
    fi
  done < "${file_path}"
}

resolve_key_from_build_settings() {
  local project_dir="$1"
  local project_path="${PROJECT_FILE_PATH:-${project_dir}/ZapPDF.xcodeproj}"
  local scheme_name="${SCHEME_NAME:-ZapPDF}"
  local output
  local value

  output="$(xcodebuild -showBuildSettings -project "${project_path}" -scheme "${scheme_name}" -configuration Release 2>/dev/null || true)"
  value="$(printf '%s\n' "${output}" | awk -F ' = ' '/^[[:space:]]*REVENUECAT_API_KEY = / { print $2; exit }')"
  value="$(trim "${value}")"
  printf '%s' "${value}"
}

project_dir="${PROJECT_DIR:-${SRCROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}}"
resolved_key_from_files=""
resolved_key_from_build_settings=""
resolved_key="$(trim "${REVENUECAT_API_KEY:-}")"

if [[ "${PREFLIGHT_USE_ENV_ONLY:-0}" != "1" ]]; then
  resolved_key_from_build_settings="$(resolve_key_from_build_settings "${project_dir}")"

  parse_xcconfig_file "${project_dir}/Config/AppConfig.xcconfig"
  parse_xcconfig_file "${project_dir}/Config/Secrets.local.xcconfig"

  if is_invalid_key "${resolved_key}"; then
    resolved_key="$(trim "${resolved_key_from_build_settings}")"
  fi
  if is_invalid_key "${resolved_key}"; then
    resolved_key="$(trim "${resolved_key_from_files}")"
  fi
fi

if is_invalid_key "${resolved_key}"; then
  echo "error: Missing RevenueCat API key for archive."
  echo "error: Run: cp Config/Secrets.template.xcconfig Config/Secrets.local.xcconfig"
  echo "error: Then set REVENUECAT_API_KEY in Config/Secrets.local.xcconfig and retry archive."
  exit 1
fi

echo "Monetization archive preflight passed."
