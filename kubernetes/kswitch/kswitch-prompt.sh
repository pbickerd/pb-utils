# kswitch-prompt.sh - shell integration for kswitch.sh. Source this file from
# ~/.bashrc or ~/.kshrc; do not run it. Works with bash 3.2+ and ksh93.
#
# Defines a `kswitch` function that runs kswitch.sh and, after a switch, shows
# the current kubectl context at the start of PS1. This has to be a function:
# a script runs in a child process and cannot change its parent shell's prompt.
#
#   kswitch [context]        switch, then show the context in the prompt
#   kswitch -p               show the context in the prompt without switching
#   kswitch -r               restore the original prompt
#
# Set KSWITCH_BIN to the path of kswitch.sh if it is not next to this file.

if [ -z "${KSWITCH_BIN:-}" ]; then
  if [ -n "${BASH_VERSION:-}" ]; then
    KSWITCH_BIN=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kswitch.sh
  elif [ -n "${KSH_VERSION:-}" ]; then
    # eval keeps the ksh-only syntax away from bash's parser.
    eval 'KSWITCH_BIN=$(cd "$(dirname "${.sh.file}")" && pwd)/kswitch.sh'
  fi
fi

# Print the current context by reading the kubeconfig directly; running
# kubectl on every prompt would be noticeably slow. Like kubectl, the first
# file in KUBECONFIG that sets current-context wins.
function _kswitch_current {
  typeset IFS f ctx
  IFS=:
  for f in ${KUBECONFIG:-$HOME/.kube/config}; do
    [ -r "$f" ] || continue
    ctx=$(sed -n "s/^current-context:[[:space:]]*[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\}[[:space:]]*\$/\1/p" "$f")
    if [ -n "$ctx" ]; then
      printf '%s\n' "$ctx"
      return 0
    fi
  done
  return 1
}

# Prompt segment, e.g. "(prod-eu) ". Prints nothing if there is no context.
function _kswitch_ps1 {
  typeset ctx
  ctx=$(_kswitch_current) && printf '(%s) ' "$ctx"
}

function _kswitch_prompt_on {
  # Already on: keep the original prompt we saved the first time.
  [ -n "${_KSWITCH_ORIG_PS1+x}" ] && return 0
  _KSWITCH_ORIG_PS1=$PS1
  # Single quotes: the segment is re-evaluated each time the prompt is drawn.
  PS1='$(_kswitch_ps1)'$PS1
}

function _kswitch_prompt_off {
  [ -n "${_KSWITCH_ORIG_PS1+x}" ] || return 0
  PS1=$_KSWITCH_ORIG_PS1
  unset _KSWITCH_ORIG_PS1
}

function kswitch {
  case "${1:-}" in
    -p | --prompt)
      _kswitch_prompt_on
      return 0
      ;;
    -r | --reset-prompt)
      _kswitch_prompt_off
      return 0
      ;;
  esac

  if [ ! -x "${KSWITCH_BIN:-}" ]; then
    printf 'kswitch: kswitch.sh not found; set KSWITCH_BIN to its path\n' >&2
    return 1
  fi
  "$KSWITCH_BIN" "$@" || return

  case "${1:-}" in
    -l | --list | -c | --current | -h | --help) ;;
    *) _kswitch_prompt_on ;;
  esac
}
