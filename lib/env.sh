#!/usr/bin/env bash
# Safe .env handling. Nothing in here ever prints a value.

# env_load <file>: source KEY=VALUE lines (quotes stripped) into the environment. Returns 1 if the file is missing.
env_load() {
  local f="$1" line key val
  [ -f "$f" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in *=*) ;; *) continue ;; esac
    key="${line%%=*}"; val="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    case "$key" in [A-Za-z_]*) ;; *) continue ;; esac
    val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
    export "$key=$val"
  done < "$f"
  return 0
}

# env_filled VAR: 0 if VAR is set and non-empty. Never prints.
env_filled() { eval "[ -n \"\${$1:-}\" ]"; }

# env_set_if_blank FILE VAR VALUE: append VAR=VALUE to FILE only if VAR is blank there. VALUE is never echoed to the terminal.
env_set_if_blank() {
  local f="$1" k="$2" v="$3"
  if grep -qE "^${k}=.+" "$f" 2>/dev/null; then return 0; fi
  if grep -qE "^${k}=$" "$f" 2>/dev/null; then
    # replace the blank line in place (portable: write temp, mv)
    awk -v k="$k" -v v="$v" 'BEGIN{done=0} $0==k"=" && !done {print k"="v; done=1; next} {print}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else
    printf '%s=%s\n' "$k" "$v" >> "$f"
  fi
  chmod 600 "$f" 2>/dev/null || true
}
