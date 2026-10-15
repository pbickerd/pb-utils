#!/usr/bin/env bash
#
# es-refresh.sh - force External Secrets Operator to resync an ExternalSecret
# or re-validate a SecretStore, by setting a force-sync annotation.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") -n <namespace> <type> <name>...

Force External Secrets Operator to reconcile the named resources now, by
setting the annotation force-sync=<unix time>.

Types:
  es, externalsecret   re-fetch the secret from the provider and update the
                       Kubernetes Secret
  ss, secretstore      re-validate the store's connection to the provider

Options:
  -n, --namespace <ns>   namespace of the resources (required)
      --context <ctx>    kubectl context to use (default: current context)
      --dry-run          print the kubectl command instead of running it
  -h, --help             show this help and exit

Examples:
  $(basename "$0") -n payments es db-credentials
  $(basename "$0") -n payments es db-credentials api-keys
  $(basename "$0") -n payments ss vault-backend
EOF
}

die() {
  printf 'es-refresh: %s\n' "$*" >&2
  exit 1
}

main() {
  local namespace='' context='' dry_run=0 type='' names=()

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
      --context)
        (($# >= 2)) || die "$1 needs a value"
        context=$2
        shift
        ;;
      --dry-run) dry_run=1 ;;
      -*) die "unknown option: $1 (see --help)" ;;
      *)
        if [[ -z $type ]]; then
          type=$1
        else
          names+=("$1")
        fi
        ;;
    esac
    shift
  done

  [[ -n $namespace ]] || die "namespace is required: -n <namespace> (see --help)"
  [[ -n $type ]] || die "no type given: es or ss (see --help)"
  ((${#names[@]})) || die "no $type name given (see --help)"

  # Fully qualified names, so a short name from another CRD can't be picked up.
  local resource kind
  case $type in
    es | externalsecret | externalsecrets)
      resource=externalsecrets.external-secrets.io
      kind=es
      ;;
    ss | secretstore | secretstores)
      resource=secretstores.external-secrets.io
      kind=ss
      ;;
    *) die "unknown type: $type (expected es or ss)" ;;
  esac

  local cmd=(kubectl)
  if [[ -n $context ]]; then
    cmd+=(--context "$context")
  fi
  # A new value on every run, so the annotation always changes and triggers a
  # reconcile; --overwrite allows replacing the value from a previous run.
  cmd+=(annotate --namespace "$namespace" "$resource" "${names[@]}"
    "force-sync=$(date +%s)" --overwrite)

  if ((dry_run)); then
    printf '%q ' "${cmd[@]}"
    printf '\n'
    exit 0
  fi

  command -v kubectl >/dev/null || die "kubectl not found in PATH"
  "${cmd[@]}"

  printf '\nCheck status with:\n  kubectl %sget %s -n %s %s\n' \
    "${context:+--context $context }" "$kind" "$namespace" "${names[*]}"
}

main "$@"
