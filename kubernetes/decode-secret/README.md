# decode-secret

Print the decoded values of a Kubernetes secret, instead of copying each base64 value out of `kubectl get secret` and decoding it by hand.

## Requirements

- Bash 3.2+
- `kubectl` on your `PATH`, with permission to get secrets in the target namespace
- `base64` (standard on macOS and Linux)

## Install

None.

## Usage

```
decode-secret.sh -n <namespace> <secret> [key...]

  -n, --namespace <ns>   namespace of the secret (required)
  -r, --raw              print one key's exact decoded bytes with no formatting
      --context <ctx>    kubectl context to use (default: current context)
  -h, --help             show help and exit
```

Show every key:

```
$ decode-secret.sh -n payments app-secret
ca.p12: <binary, 2048 bytes>
password: s3cr3t
tls.crt:
-----BEGIN CERTIFICATE-----
MIIBszCCAVmgAwIBAgIUJ...
-----END CERTIFICATE-----
username: admin
```

Show only some keys:

```bash
decode-secret.sh -n payments app-secret username password
```

Save one value to a file, byte for byte (works for binary values too):

```bash
decode-secret.sh -n payments app-secret -r ca.p12 > ca.p12
```

## Output format

- Keys are sorted alphabetically.
- Single-line values: `key: value`.
- Multi-line values (certificates, config files): a `key:` line, then the value exactly as stored, so it can be copied cleanly.
- Binary values: `<binary, N bytes>`, so they don't fill the terminal with junk. Use `--raw` to get them.

## Notes

- Values are printed in plain text. Mind who can see your screen, and terminal logging or scrollback.
- Reads `.data` in a single `kubectl get` call using a go-template, so `jq` isn't needed.
- Exits 1 if the secret doesn't exist, has no data, or any requested key is missing (the keys that were found are still shown).
