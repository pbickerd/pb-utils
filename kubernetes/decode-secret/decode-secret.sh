#!/usr/bin/env bash
#
# decode-secret.sh - print the decoded values of a Kubernetes secret.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") -n <namespace> <secret> [key...]

Print the base64-decoded values of a Kubernetes secret. With keys given, only
those keys are shown.

Single-line values print as "key: value". Multi-line values (certificates,
config files) print verbatim under a "key:" line. Binary values are shown as
"<binary, N bytes>"; use --raw to get them.

Options:
  -n, --namespace <ns>   namespace of the secret (required)
  -r, --raw              print one key's exact decoded bytes with no
                         formatting, e.g. to redirect to a file
      --context <ctx>    kubectl context to use (default: current context)
  -h, --help             show this help and exit

Examples:
  $(basename "$0") -n payments db-credentials
  $(basename "$0") -n payments db-credentials password
  $(basename "$0") -n payments app-tls -r tls.crt > tls.crt
EOF
}

die() {
  printf 'decode-secret: %s\n' "$*" >&2
  exit 1
}

decode() {
  printf '%s' "$1" | base64 --decode
}

# Print one key in the display format.
show() {
  local key=$1 b64=$2 controls value

  # Control characters other than tab, newline and CR mean binary data.
  # Bytes 128-255 are allowed so UTF-8 text still counts as text.
  controls=$(decode "$b64" | LC_ALL=C tr -d '\011\012\015\040-\377' | wc -c)
  if ((controls > 0)); then
    printf '%s: <binary, %d bytes>\n' "$key" "$(decode "$b64" | wc -c)"
    return
  fi

  # The trailing x stops $( ) from stripping trailing newlines from the value.
  value=$(
    decode "$b64"
    printf x
  )
  value=${value%x}

  if [[ $value == *$'\n'* ]]; then
    printf '%s:\n%s' "$key" "$value"
    if [[ $value != *$'\n' ]]; then
      printf '\n'
    fi
  else
    printf '%s: %s\n' "$key" "$value"
  fi
}

main() {
  local namespace='' context='' raw=0 secret='' keys=()

  while (($#)); do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -n | --namespace)
        (($# >= 2)) || die "$1 needs a value"
        namespace=$2
        shift
        ;;
      -r | --raw) raw=1 ;;
      --context)
        (($# >= 2)) || die "$1 needs a value"
        context=$2
        shift
        ;;
      -*) die "unknown option: $1 (see --help)" ;;
      *)
        if [[ -z $secret ]]; then
          secret=$1
        else
          keys+=("$1")
        fi
        ;;
    esac
    shift
  done

  [[ -n $namespace ]] || die "namespace is required: -n <namespace> (see --help)"
  [[ -n $secret ]] || die "no secret name given (see --help)"
  if ((raw)) && ((${#keys[@]} != 1)); then
    die "--raw needs exactly one key"
  fi

  command -v kubectl >/dev/null || die "kubectl not found in PATH"

  local kubectl=(kubectl)
  if [[ -n $context ]]; then
    kubectl+=(--context "$context")
  fi

  # One line per key: "<key><tab><base64 value>", sorted by key. Keys can't
  # contain tabs or newlines, and base64 has neither, so this splits safely.
  local listing
  listing=$("${kubectl[@]}" get secret "$secret" --namespace "$namespace" \
    -o go-template='{{range $k, $v := .data}}{{$k}}{{"\t"}}{{$v}}{{"\n"}}{{end}}')
  [[ -n $listing ]] || die "secret $secret has no data"

  local key b64 wanted found=0
  while IFS=$'\t' read -r key b64; do
    if ((${#keys[@]})); then
      found=0
      for wanted in "${keys[@]}"; do
        if [[ $key == "$wanted" ]]; then
          found=1
        fi
      done
      ((found)) || continue
    fi

    if ((raw)); then
      decode "$b64"
      exit 0
    fi
    show "$key" "$b64"
  done <<<"$listing"

  # Report any requested keys that weren't in the secret.
  local missing=0
  for wanted in ${keys[@]+"${keys[@]}"}; do
    if [[ $'\n'$listing != *$'\n'$wanted$'\t'* ]]; then
      printf 'decode-secret: key not found: %s\n' "$wanted" >&2
      missing=1
    fi
  done
  exit "$missing"
}

main "$@"
