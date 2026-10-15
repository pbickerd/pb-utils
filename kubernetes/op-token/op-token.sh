#!/usr/bin/env bash
#
# op-token.sh - create the onepassword-token secret used by the 1Password
# Kubernetes integration.

set -euo pipefail

readonly SECRET_NAME=onepassword-token

usage() {
  cat <<EOF
Usage: $(basename "$0") -n <namespace> [-t <token>] [options]

Create the Kubernetes secret "$SECRET_NAME" (key: token) used by the 1Password
Kubernetes integration. Equivalent to:

  kubectl -n <namespace> create secret generic $SECRET_NAME --from-literal=token=<token>

but the token is passed to kubectl on stdin, so it never shows in its
arguments (e.g. in ps output).

If -t is not given, the token is read from stdin when piped in, or prompted
for without echoing. Both keep it out of your shell history.

Options:
  -n, --namespace <ns>   namespace to create the secret in (required)
  -t, --token <token>    the 1Password token
  -u, --update           replace the token if the secret already exists
      --context <ctx>    kubectl context to use (default: current context)
      --dry-run          print the kubectl command(s) instead of running them
  -h, --help             show this help and exit

Examples:
  $(basename "$0") -n payments                     # prompts for the token
  $(basename "$0") -n payments -t "\$OP_TOKEN"
  op read op://vault/item/credential | $(basename "$0") -n payments -u
EOF
}

die() {
  printf 'op-token: %s\n' "$*" >&2
  exit 1
}

main() {
  local namespace='' context='' token='' have_token=0 update=0 dry_run=0

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
      -t | --token)
        (($# >= 2)) || die "$1 needs a value"
        token=$2
        have_token=1
        shift
        ;;
      -u | --update) update=1 ;;
      --context)
        (($# >= 2)) || die "$1 needs a value"
        context=$2
        shift
        ;;
      --dry-run) dry_run=1 ;;
      *) die "unknown argument: $1 (see --help)" ;;
    esac
    shift
  done

  [[ -n $namespace ]] || die "namespace is required: -n <namespace> (see --help)"

  if ((!have_token)); then
    if [[ -t 0 ]]; then
      IFS= read -rsp 'Token: ' token
      printf '\n' >&2
    else
      IFS= read -r token || true
    fi
  fi
  [[ -n $token ]] || die "token is empty"

  local kubectl=(kubectl)
  if [[ -n $context ]]; then
    kubectl+=(--context "$context")
  fi
  # /dev/stdin as the file source keeps the token out of kubectl's arguments.
  local create=("${kubectl[@]}" create secret generic "$SECRET_NAME"
    --namespace "$namespace" --from-file=token=/dev/stdin)
  # Server-side apply updates the secret in place without kubectl's
  # last-applied-configuration annotation, which would hold a second copy of
  # the token. --force-conflicts takes ownership of a secret first made by
  # kubectl create.
  local apply=("${kubectl[@]}" apply --server-side --force-conflicts
    --field-manager=op-token -f -)

  if ((dry_run)); then
    printf '# token (%d characters) is passed on stdin\n' "${#token}"
    if ((update)); then
      printf '%q ' "${create[@]}" --dry-run=client -o yaml
      printf '| '
      printf '%q ' "${apply[@]}"
    else
      printf '%q ' "${create[@]}"
    fi
    printf '\n'
    exit 0
  fi

  command -v kubectl >/dev/null || die "kubectl not found in PATH"

  # printf is a shell builtin, so the token isn't visible in ps here either.
  if ((update)); then
    printf '%s' "$token" | "${create[@]}" --dry-run=client -o yaml | "${apply[@]}"
  else
    printf '%s' "$token" | "${create[@]}" ||
      die "create failed; if the secret already exists, use -u to replace the token"
  fi
}

main "$@"
