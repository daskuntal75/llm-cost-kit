# shellcheck shell=sh
# anthropic-admin-key.sh — sourceable loader for ANTHROPIC_ADMIN_API_KEY
#
# Loads the admin key from the macOS Keychain (service=anthropic-admin-api-key,
# account=$USER) into ANTHROPIC_ADMIN_API_KEY if it isn't already set.
#
# Usage:
#   source ~/.local/lib/anthropic-admin-key.sh           # silent load
#   source ~/.local/lib/anthropic-admin-key.sh --require # exit 1 if missing
#
# Designed to be cheap (one `security` call max, skipped if env already set).
# Never echoes or logs the key. Failures go to stderr only.

__anthropic_admin_key_load() {
  # Already populated? Honor it and skip the Keychain hit.
  if [ -n "${ANTHROPIC_ADMIN_API_KEY:-}" ]; then
    return 0
  fi

  # macOS only — `security` is the system keychain CLI.
  if ! command -v security >/dev/null 2>&1; then
    echo "anthropic-admin-key: 'security' CLI not found (non-macOS host?)" >&2
    return 1
  fi

  local _val
  _val=$(security find-generic-password \
           -s "anthropic-admin-api-key" \
           -a "${USER:-$(id -un)}" \
           -w 2>/dev/null) || _val=""

  if [ -z "$_val" ]; then
    echo "anthropic-admin-key: not found in Keychain (service=anthropic-admin-api-key, account=$USER)" >&2
    echo "anthropic-admin-key: store one with 'anthropic-admin-key --store'" >&2
    return 1
  fi

  ANTHROPIC_ADMIN_API_KEY="$_val"
  export ANTHROPIC_ADMIN_API_KEY
  unset _val
  return 0
}

__anthropic_admin_key_load
__anthropic_admin_key_rc=$?

# --require mode: caller wants a hard failure if the key isn't available.
case "${1:-}" in
  --require)
    if [ $__anthropic_admin_key_rc -ne 0 ]; then
      echo "anthropic-admin-key: --require failed; aborting" >&2
      # In a sourced context, `return` exits the source; in `sh -c`, fall through to exit.
      return 1 2>/dev/null || exit 1
    fi
    ;;
esac

unset __anthropic_admin_key_rc
unset -f __anthropic_admin_key_load 2>/dev/null
