#!/usr/bin/env bash
#
# kswitch.sh - switch the current kubectl context, with a simple arrow-key picker.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [context]

Switch the current kubectl context.

With no context given, an interactive picker is shown:
  Up/Down or k/j   move
  Enter            switch to the highlighted context
  q or Esc         cancel

Options:
  -l, --list           list contexts (current marked with *) and exit
  -c, --current        print the current context and exit
  -h, --help           show this help and exit

Prompt options (only when run via the kswitch function from kswitch-prompt.sh):
  -p, --prompt         show the current context in the shell prompt
  -r, --reset-prompt   restore the original shell prompt
EOF
}

die() {
  printf 'kswitch: %s\n' "$*" >&2
  exit 1
}

# Interactive picker. Draws on /dev/tty and prints the chosen item to stdout.
# Usage: pick <initial-index> <item>...
pick() {
  local selected=$1
  shift
  local items=("$@")
  local count=${#items[@]}
  local rows height offset=0 drawn=0 key rest i esc_timeout=1

  if ((BASH_VERSINFO[0] >= 4)); then
    esc_timeout=0.1
  fi

  rows=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f1)
  # Some terminals report 0 rows; fall back to a standard height.
  if ((${rows:-0} < 2)); then
    rows=24
  fi
  height=$((rows - 1))
  if ((count < height)); then
    height=$count
  fi

  local saved_stty
  saved_stty=$(stty -g </dev/tty)
  # Restore the cursor and terminal settings however we leave. saved_stty is
  # expanded now, as the local is out of scope by the time the trap runs.
  # shellcheck disable=SC2064
  trap "printf '\e[?25h' >/dev/tty; stty '$saved_stty' </dev/tty" EXIT
  trap 'exit 130' INT TERM
  printf '\e[?25l' >/dev/tty

  while true; do
    # Keep the selection inside the visible window.
    if ((selected < offset)); then
      offset=$selected
    elif ((selected >= offset + height)); then
      offset=$((selected - height + 1))
    fi

    if ((drawn)); then
      printf '\e[%dA' "$height" >/dev/tty
    fi
    for ((i = offset; i < offset + height; i++)); do
      if ((i == selected)); then
        printf '\e[2K\e[7m> %s\e[0m\n' "${items[i]}" >/dev/tty
      else
        printf '\e[2K  %s\n' "${items[i]}" >/dev/tty
      fi
    done
    drawn=1

    IFS= read -rsn1 key </dev/tty
    case $key in
      $'\e')
        # Arrow keys arrive as Esc followed by "[A" or "[B"; a short timeout
        # tells them apart from a plain Esc. Bash 3.2 (macOS) only accepts
        # whole-second timeouts, so a plain Esc takes a second to cancel there.
        rest=''
        read -rsn2 -t "$esc_timeout" rest </dev/tty || true
        case $rest in
          '[A') ((selected > 0)) && selected=$((selected - 1)) ;;
          '[B') ((selected < count - 1)) && selected=$((selected + 1)) ;;
          '') break ;; # plain Esc
        esac
        ;;
      k) ((selected > 0)) && selected=$((selected - 1)) ;;
      j) ((selected < count - 1)) && selected=$((selected + 1)) ;;
      q) break ;;
      '')
        # Enter: clear the menu and return the choice.
        printf '\e[%dA\e[J' "$height" >/dev/tty
        printf '%s\n' "${items[selected]}"
        return 0
        ;;
    esac
  done

  printf '\e[%dA\e[J' "$height" >/dev/tty
  return 1
}

main() {
  local mode=switch target=''

  while (($#)); do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -l | --list) mode=list ;;
      -c | --current) mode=current ;;
      -p | --prompt | -r | --reset-prompt)
        die "$1 must be run via the kswitch shell function; source kswitch-prompt.sh (see README)"
        ;;
      -*) die "unknown option: $1 (see --help)" ;;
      *)
        [[ -z $target ]] || die "only one context may be given"
        target=$1
        ;;
    esac
    shift
  done

  command -v kubectl >/dev/null || die "kubectl not found in PATH"

  local current line contexts=()
  current=$(kubectl config current-context 2>/dev/null || true)
  # A read loop rather than mapfile, which macOS's bash 3.2 lacks.
  while IFS= read -r line; do
    contexts+=("$line")
  done < <(kubectl config get-contexts -o name)
  ((${#contexts[@]})) || die "no contexts found in kubeconfig"

  case $mode in
    current)
      [[ -n $current ]] || die "no current context set"
      printf '%s\n' "$current"
      exit 0
      ;;
    list)
      local ctx
      for ctx in "${contexts[@]}"; do
        if [[ $ctx == "$current" ]]; then
          printf '* %s\n' "$ctx"
        else
          printf '  %s\n' "$ctx"
        fi
      done
      exit 0
      ;;
  esac

  if [[ -z $target ]]; then
    [[ -t 0 && -t 2 ]] || die "no context given and not running in a terminal (see --help)"

    local i start=0
    for i in "${!contexts[@]}"; do
      if [[ ${contexts[i]} == "$current" ]]; then
        start=$i
      fi
    done
    target=$(pick "$start" "${contexts[@]}") || exit 1
  fi

  local found=0 ctx
  for ctx in "${contexts[@]}"; do
    if [[ $ctx == "$target" ]]; then
      found=1
    fi
  done
  ((found)) || die "context not found: $target (see --list)"

  if [[ $target == "$current" ]]; then
    printf 'Already on context "%s"\n' "$target"
    exit 0
  fi

  kubectl config use-context "$target" >/dev/null
  printf 'Switched to context "%s"\n' "$target"
}

main "$@"
