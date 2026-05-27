#!/bin/bash
# _lib.sh — Shared library for doc-it and plan-it
# Source: source "$(dirname "$0")/_lib.sh"
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERSION="1.0.0"

msg()  { printf "${GREEN}%s${NC}\n" "$1"; }
info() { printf "${CYAN}%s${NC}\n" "$1"; }
warn() { printf "${YELLOW}%s${NC}\n" "$1"; }
err()  { printf "${RED}%s${NC}\n" "$1"; }

DOCIT_BEGIN="<!-- BEGIN DOCIT MANAGED BLOCK -->"
DOCIT_END="<!-- END DOCIT MANAGED BLOCK -->"
PLANIT_BEGIN="<!-- BEGIN PLAN-IT MANAGED BLOCK -->"
PLANIT_END="<!-- END PLAN-IT MANAGED BLOCK -->"
PLANIT_OPENCODE_BEGIN="<!-- BEGIN PLAN-IT OPENCODE MANAGED BLOCK -->"
PLANIT_OPENCODE_END="<!-- END PLAN-IT OPENCODE MANAGED BLOCK -->"
PLANIT_KILO_BEGIN="<!-- BEGIN PLAN-IT KILO MANAGED BLOCK -->"
PLANIT_KILO_END="<!-- END PLAN-IT KILO MANAGED BLOCK -->"
PLANIT_PROMPT_BEGIN="<!-- BEGIN PLAN-IT PROMPT -->"
PLANIT_PROMPT_END="<!-- END PLAN-IT PROMPT -->"

MANAGED_JSON_RULES='{
  "agent.plan.prompt": { "mode": "replace" },
  "agent.plan.permission.write": { "mode": "merge-object" }
}'

# ---------------------------------------------------------------------------
# Atomic write
# ---------------------------------------------------------------------------

atomic_write() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  local tmp
  tmp="$(mktemp "${target}.XXXX")"
  cat > "$tmp"
  mv "$tmp" "$target"
}

# ---------------------------------------------------------------------------
# Sentinel block management
# ---------------------------------------------------------------------------

replace_managed_block() {
  local file="$1" begin="$2" end="$3" content="$4"

  if [ ! -f "$file" ]; then
    mkdir -p "$(dirname "$file")"
    {
      printf '%s\n' "$begin"
      printf '%s' "$content"
      printf '\n%s\n' "$end"
    } > "$file"
    return
  fi

  local tmp
  tmp="$(mktemp "${file}.XXXX")"

  if grep -qF "$begin" "$file" 2>/dev/null; then
    local in_block=0
    while IFS= read -r line; do
      if [ "$in_block" -eq 0 ] && printf '%s' "$line" | grep -qF "$begin"; then
        in_block=1
        printf '%s\n' "$begin" >> "$tmp"
        printf '%s' "$content" >> "$tmp"
        printf '\n' >> "$tmp"
      elif [ "$in_block" -eq 1 ] && printf '%s' "$line" | grep -qF "$end"; then
        in_block=0
        printf '%s\n' "$end" >> "$tmp"
      elif [ "$in_block" -eq 0 ]; then
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$file"
  else
    cp "$file" "$tmp"
    printf '\n%s\n' "$begin" >> "$tmp"
    printf '%s' "$content" >> "$tmp"
    printf '\n%s\n' "$end" >> "$tmp"
  fi

  mv "$tmp" "$file"
}

remove_managed_block() {
  local file="$1" begin="$2" end="$3"

  [ ! -f "$file" ] && return
  if ! grep -qF "$begin" "$file" 2>/dev/null; then
    return
  fi

  local tmp
  tmp="$(mktemp "${file}.XXXX")"
  local in_block=0

  while IFS= read -r line; do
    if [ "$in_block" -eq 0 ] && printf '%s' "$line" | grep -qF "$begin"; then
      in_block=1
    elif [ "$in_block" -eq 1 ] && printf '%s' "$line" | grep -qF "$end"; then
      in_block=0
    elif [ "$in_block" -eq 0 ]; then
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$file"

  mv "$tmp" "$file"
}

replace_managed_block_in_string() {
  local input="$1" begin="$2" end="$3" content="$4"

  if printf '%s' "$input" | grep -qF "$begin"; then
    printf '%s' "$input" | node -e "
      const fs = require('fs');
      const input = fs.readFileSync('/dev/stdin', 'utf-8');
      const begin = process.argv[1];
      const end = process.argv[2];
      const content = process.argv[3];
      const escapeRegex = s => s.replace(/[.*+?^\${}()|[\]\\\\]/g, '\\\\$&');
      const regex = new RegExp(escapeRegex(begin) + '[\\\\s\\\\S]*?' + escapeRegex(end));
      if (regex.test(input)) {
        process.stdout.write(input.replace(regex, begin + '\n' + content + '\n' + end));
      } else {
        process.stdout.write(input);
      }
    " "$begin" "$end" "$content"
  else
    printf '%s\n%s\n%s\n%s\n' "$input" "$begin" "$content" "$end"
  fi
}

validate_sentinels() {
  local file="$1"
  local issues=0

  [ ! -f "$file" ] && { echo "FILE_MISSING"; return 1; }

  local stack=()
  local line_num=0
  local i

  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if printf '%s' "$line" | grep -qF "<!-- BEGIN"; then
      stack+=("$line")
    fi
    if printf '%s' "$line" | grep -qF "<!-- END"; then
      if [ ${#stack[@]} -eq 0 ]; then
        echo "UNMATCHED_END:$line_num"
        issues=$((issues + 1))
      else
        unset 'stack[${#stack[@]}-1]'
      fi
    fi
  done < "$file"

  if [ ${#stack[@]} -gt 0 ]; then
    for i in "${stack[@]}"; do
      echo "UNCLOSED_BLOCK:$i"
      issues=$((issues + 1))
    done
  fi

  return "$issues"
}

# ---------------------------------------------------------------------------
# JSON merge
# ---------------------------------------------------------------------------

merge_json_config() {
  local target="$1" snippet="$2" rules="${3:-$MANAGED_JSON_RULES}"

  if [ ! -f "$target" ]; then
    mkdir -p "$(dirname "$target")"
    echo '{}' > "$target"
  fi

  local tmp
  tmp="$(mktemp "${target}.XXXX")"

  node -e "
    const fs = require('fs');
    const targetPath = process.argv[1];
    const snippet = JSON.parse(process.argv[2]);
    const rules = JSON.parse(process.argv[3] || '{}');
    const tmpPath = process.argv[4];
    const target = JSON.parse(fs.readFileSync(targetPath, 'utf-8'));

    function deepMerge(a, b, path) {
      for (const k of Object.keys(b)) {
        const fullPath = path ? path + '.' + k : k;
        if (rules[fullPath] && rules[fullPath].mode === 'replace') {
          a[k] = b[k];
        } else if (rules[fullPath] && rules[fullPath].mode === 'merge-object') {
          a[k] = a[k] || {};
          Object.assign(a[k], b[k]);
        } else if (b[k] && typeof b[k] === 'object' && !Array.isArray(b[k]) && a[k] && typeof a[k] === 'object' && !Array.isArray(a[k])) {
          deepMerge(a[k], b[k], fullPath);
        } else if (Array.isArray(b[k]) && Array.isArray(a[k])) {
          const merged = new Set([...a[k], ...b[k]]);
          a[k] = [...merged];
        } else {
          a[k] = b[k];
        }
      }
    }

    deepMerge(target, snippet, '');
    fs.writeFileSync(tmpPath, JSON.stringify(target, null, 2) + '\n');
  " "$target" "$snippet" "$rules" "$tmp"

  mv "$tmp" "$target"
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

write_if_missing() {
  local file="$1"
  if [ -f "$file" ] && [ -z "${RESTORE_SEEDS:-}" ]; then
    warn "Skipping existing file: $file"
    return 0
  fi
  mkdir -p "$(dirname "$file")"
  local tmp
  tmp="$(mktemp "${file}.XXXX")"
  cat > "$tmp"
  mv "$tmp" "$file"
  msg "Created: $file"
}

write_generated() {
  local file="$1" generator="$2" source="$3"
  mkdir -p "$(dirname "$file")"
  local tmp
  tmp="$(mktemp "${file}.XXXX")"
  cat > "$tmp" << GENERATED_HEADER
<!-- GENERATED FILE -- DO NOT EDIT -->
<!-- generator: $generator -->
<!-- source: $source -->
<!-- generated-at: $(date -u +%Y-%m-%dT%H:%M:%SZ) -->

GENERATED_HEADER
  cat >> "$tmp"
  mv "$tmp" "$file"
}

safe_cp_tool() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"

  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    msg "Copied tool: $(basename "$dst")"
    return
  fi

  if head -5 "$dst" 2>/dev/null | grep -q "doc-it-managed: true"; then
    local src_sha dst_sha
    src_sha=$(sha256sum "$src" 2>/dev/null | cut -d' ' -f1 || echo "")
    dst_sha=$(sha256sum "$dst" 2>/dev/null | cut -d' ' -f1 || echo "")
    if [ -n "$src_sha" ] && [ "$src_sha" = "$dst_sha" ]; then
      info "Tool unchanged: $(basename "$dst")"
      return
    fi

    local src_ver="" dst_ver=""
    src_ver=$(head -10 "$src" | grep "source-version:" | sed 's/.*source-version: *\([^ ]*\).*/\1/' || true)
    dst_ver=$(head -10 "$dst" | grep "source-version:" | sed 's/.*source-version: *\([^ ]*\).*/\1/' || true)

    if [ -n "$src_ver" ] && [ -n "$dst_ver" ]; then
      if semver_gt "$src_ver" "$dst_ver"; then
        cp "$src" "$dst"
        msg "Upgraded tool: $(basename "$dst") ($dst_ver → $src_ver)"
      else
        warn "Skipping user-modified tool: $(basename "$dst")"
      fi
    else
      cp "$src" "$dst"
    fi
  else
    warn "Skipping user-modified tool: $(basename "$dst")"
  fi
}

# ---------------------------------------------------------------------------
# Semantic version comparison
# ---------------------------------------------------------------------------

semver_gt() {
  local v1="$1" v2="$2"
  node -e "
    const p1 = (process.argv[1] || '0.0.0').split('.').map(Number);
    const p2 = (process.argv[2] || '0.0.0').split('.').map(Number);
    for (let i = 0; i < 3; i++) {
      if ((p1[i] || 0) > (p2[i] || 0)) process.exit(0);
      if ((p1[i] || 0) < (p2[i] || 0)) process.exit(1);
    }
    process.exit(1);
  " "$v1" "$v2" && return 0 || return 1
}

# ---------------------------------------------------------------------------
# Manifest management
# ---------------------------------------------------------------------------

manifest_init() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  if [ ! -f "$path" ]; then
    atomic_write "$path" << MANIFEST_EOF
{
  "schema_version": 1,
  "tool_version": "$VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "files": [],
  "backups": []
}
MANIFEST_EOF
  fi
}

manifest_add() {
  local path="$1" filepath="$2" ownership="$3" src_ver="${4:-}"

  if [ ! -f "$path" ]; then
    manifest_init "$path"
  fi

  local sha256
  if [ -f "$filepath" ]; then
    sha256=$(sha256sum "$filepath" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
  else
    sha256="unknown"
  fi

  local tmp installed_at
  tmp="$(mktemp "${path}.XXXX")"
  installed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  node -e "
    const fs = require('fs');
    const manifestPath = process.argv[1];
    const filepath = process.argv[2];
    const ownership = process.argv[3];
    const sha256 = process.argv[4];
    const installedAt = process.argv[5];
    const srcVer = process.argv[6] || '';
    const tmpPath = process.argv[7];
    const m = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
    const entry = { path: filepath, ownership, sha256, installed_at: installedAt };
    if (srcVer) entry.source_version = srcVer;
    const existing = m.files.findIndex(f => f.path === filepath);
    if (existing >= 0) {
      m.files[existing] = entry;
    } else {
      m.files.push(entry);
    }
    fs.writeFileSync(tmpPath, JSON.stringify(m, null, 2) + '\n');
  " "$path" "$filepath" "$ownership" "$sha256" "$installed_at" "$src_ver" "$tmp"
  mv "$tmp" "$path"
}

manifest_remove() {
  local path="$1" filepath="$2"

  [ ! -f "$path" ] && return

  local tmp
  tmp="$(mktemp "${path}.XXXX")"
  node -e "
    const fs = require('fs');
    const manifestPath = process.argv[1];
    const filepath = process.argv[2];
    const tmpPath = process.argv[3];
    const m = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
    m.files = m.files.filter(f => f.path !== filepath);
    fs.writeFileSync(tmpPath, JSON.stringify(m, null, 2) + '\n');
  " "$path" "$filepath" "$tmp"
  mv "$tmp" "$path"
}

# ---------------------------------------------------------------------------
# Safe operations
# ---------------------------------------------------------------------------

safe_rmdir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    local has_files=false
    shopt -s nullglob dotglob
    for _ in "$dir"/*; do has_files=true; break; done
    shopt -u nullglob dotglob
    if ! $has_files; then
      rmdir "$dir" && info "Removed empty directory: $dir"
    fi
  fi
}

prune_backups() {
  local pattern="$1" keep="${2:-3}"
  local count=0
  shopt -s nullglob
  local files=($pattern)
  shopt -u nullglob
  if [ ${#files[@]} -le "$keep" ]; then
    return
  fi
  while IFS= read -r f; do
    count=$((count + 1))
    if [ "$count" -gt "$keep" ]; then
      rm -f "$f"
      info "Pruned old backup: $f"
    fi
  done < <(ls -t "${files[@]}" 2>/dev/null || true)
}

safe_sed_inplace() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}
