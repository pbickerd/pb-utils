# op-token

Create the `onepassword-token` secret used by the [1Password Kubernetes integration](https://developer.1password.com/docs/k8s/), without retyping the kubectl command each time.

## Requirements

- Bash 3.2+
- `kubectl` on your `PATH`, with permission to create (and for `-u`, update) secrets in the target namespace

## Install

None.

## Usage

```
op-token.sh -n <namespace> [-t <token>] [options]

  -n, --namespace <ns>   namespace to create the secret in (required)
  -t, --token <token>    the 1Password token
  -u, --update           replace the token if the secret already exists
      --context <ctx>    kubectl context to use (default: current context)
      --dry-run          print the kubectl command(s) instead of running them
  -h, --help             show help and exit
```

It creates the same secret as:

```bash
kubectl -n <namespace> create secret generic onepassword-token --from-literal=token=<token>
```

Examples:

```bash
# Prompt for the token (not echoed, not saved in shell history)
op-token.sh -n payments

# Pass the token directly
op-token.sh -n payments -t "$OP_TOKEN"

# Pipe it in, e.g. from the 1Password CLI, and replace an existing token
op read op://vault/item/credential | op-token.sh -n payments -u
```

## Keeping the token private

- **`-t <token>`** puts the token in your shell history. Prompting (no `-t`) or piping it in avoids that. Passing a variable such as `-t "$OP_TOKEN"` records only the variable name.
- The token is passed to kubectl on stdin (`--from-file=token=/dev/stdin`), not as `--from-literal`. So it never appears in kubectl's arguments, where any user on the machine could see it with `ps`.
- `-u` updates with server-side apply. Unlike a plain `kubectl apply`, that doesn't add a `last-applied-configuration` annotation holding a second copy of the token.

## Notes

- Without `-u`, the script fails if the secret already exists, so a token is never replaced by accident.
- `--dry-run` prints the commands and the token's length, never the token itself.
- Pods that already read the token won't see a new value until they restart. For example, restart the 1Password Connect / operator deployment after `-u`.
