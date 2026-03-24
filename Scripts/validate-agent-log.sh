#!/usr/bin/env bash

set -u
shopt -s nullglob

ROOT_DIR="GraceNotes/docs/agent-log"
INITIATIVES_DIR="${ROOT_DIR}/initiatives"
STRICT_MODE=0

WARNINGS=0
ERRORS=0

usage() {
  echo "Usage: $0 [--strict] [path ...]"
  echo
  echo "Examples:"
  echo "  $0"
  echo "  $0 GraceNotes/docs/agent-log/initiatives/001-guided-onboarding"
  echo "  $0 --strict GraceNotes/docs/agent-log/initiatives/001-guided-onboarding/qa.md"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  echo "WARN: $1"
}

fail_or_warn() {
  local message="$1"
  if [[ "${STRICT_MODE}" -eq 1 ]]; then
    ERRORS=$((ERRORS + 1))
    echo "ERROR: ${message}"
  else
    warn "${message}"
  fi
}

has_match() {
  local file_path="$1"
  local regex="$2"
  awk -v re="${regex}" '
    $0 ~ re { found=1; exit }
    END { if (found) exit 0; exit 1 }
  ' "${file_path}"
}

check_heading() {
  local file_path="$1"
  local heading="$2"
  local required="$3"

  if has_match "${file_path}" "^## ${heading}$"; then
    return
  fi

  if [[ "${required}" == "required" ]]; then
    fail_or_warn "${file_path}: missing required section '## ${heading}'"
  else
    warn "${file_path}: missing recommended section '## ${heading}'"
  fi
}

check_frontmatter() {
  local file_path="$1"

  if ! has_match "${file_path}" "^---$"; then
    warn "${file_path}: missing frontmatter block (recommended)"
    return
  fi

  local key
  for key in initiative_id role status updated_at related_issue related_pr; do
    if ! has_match "${file_path}" "^${key}:"; then
      warn "${file_path}: missing frontmatter key '${key}' (recommended)"
    fi
  done
}

validate_role_file() {
  local file_path="$1"

  check_heading "${file_path}" "Decision" "required"
  check_heading "${file_path}" "Open Questions" "required"
  check_heading "${file_path}" "Next Owner" "required"

  check_heading "${file_path}" "Inputs Reviewed" "recommended"
  check_heading "${file_path}" "Rationale" "recommended"
  check_heading "${file_path}" "Risks" "recommended"

  check_frontmatter "${file_path}"
}

validate_pushback_file() {
  local file_path="$1"

  local token
  for token in "Constraint" "Current Impact" "Not-Now Decision" "Revisit Trigger"; do
    if ! has_match "${file_path}" "\`${token}\`:"; then
      fail_or_warn "${file_path}: missing pushback field '${token}'"
    fi
  done

  check_frontmatter "${file_path}"
}

collect_initiative_dirs() {
  local -a input_paths=("$@")
  local -a dirs=()
  local line

  if [[ "${#input_paths[@]}" -eq 0 ]]; then
    local file_path
    for file_path in "${INITIATIVES_DIR}"/*/*.md "${INITIATIVES_DIR}"/archive/*/*.md; do
      [[ -f "${file_path}" ]] || continue
      dirs+=("$(dirname "${file_path}")")
    done
    printf "%s\n" "${dirs[@]}" | awk 'NF' | sort -u
    return
  fi

  local path
  for path in "${input_paths[@]}"; do
    if [[ "${path}" == *"/initiatives/"* ]]; then
      if [[ -d "${path}" ]]; then
        dirs+=("${path}")
      elif [[ -f "${path}" ]]; then
        dirs+=("$(dirname "${path}")")
      fi
    fi
  done

  printf "%s\n" "${dirs[@]}" | awk 'NF' | sort -u
}

main() {
  local -a paths=()
  local -a initiative_dirs=()
  local line
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --strict)
        STRICT_MODE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        paths+=("$1")
        shift
        ;;
    esac
  done

  if [[ ! -d "${INITIATIVES_DIR}" ]]; then
    echo "No agent-log initiatives directory found at ${INITIATIVES_DIR}"
    exit 0
  fi

  if [[ "${#paths[@]}" -gt 0 ]]; then
    while IFS= read -r line; do
      initiative_dirs+=("${line}")
    done < <(collect_initiative_dirs "${paths[@]}")
  else
    while IFS= read -r line; do
      initiative_dirs+=("${line}")
    done < <(collect_initiative_dirs)
  fi

  if [[ "${#initiative_dirs[@]}" -eq 0 ]]; then
    echo "No initiative directories to validate."
    exit 0
  fi

  local initiative_dir
  for initiative_dir in "${initiative_dirs[@]}"; do
    echo "Validating ${initiative_dir}"

    local role_file
    for role_file in brief.md architecture.md qa.md testing.md release.md; do
      if [[ -f "${initiative_dir}/${role_file}" ]]; then
        validate_role_file "${initiative_dir}/${role_file}"
      fi
    done

    if [[ -f "${initiative_dir}/pushback.md" ]]; then
      validate_pushback_file "${initiative_dir}/pushback.md"
    fi
  done

  echo "Validation complete: ${WARNINGS} warning(s), ${ERRORS} error(s)."

  if [[ "${ERRORS}" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
