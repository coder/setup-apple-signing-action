# setup-apple-signing-action

Actions that set up the tools for signing Apple software with
[rcodesign](https://github.com/indygreg/apple-platform-rs) and a key in Google
Cloud KMS. They run on Linux x86_64 runners.

| Action                                       | What it does                                                                             |
|----------------------------------------------|------------------------------------------------------------------------------------------|
| `coder/setup-apple-signing-action/rcodesign` | Builds and installs `rcodesign` with PKCS#11 support.                                    |
| `coder/setup-apple-signing-action`           | Installs the Cloud KMS PKCS#11 library and writes its configuration and the certificate. |

## Usage

```yaml
jobs:
  sign:
    runs-on: ubuntu-22.04
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Install rcodesign
        uses: coder/setup-apple-signing-action/rcodesign@<commit> # v1.0.0

      - name: Set up Apple signing
        id: apple_signing
        uses: coder/setup-apple-signing-action@<commit> # v1.0.0
        with:
          certificate-pem: ${{ secrets.AC_CERTIFICATE_PEM }}
          key-ring: ${{ secrets.AC_KMS_KEY_RING }}

      - name: Authenticate to Google Cloud
        id: gcloud_auth
        uses: google-github-actions/auth@<commit>
        with:
          workload_identity_provider: ${{ secrets.WORKLOAD_ID_PROVIDER }}
          service_account: ${{ secrets.SERVICE_ACCOUNT }}

      - name: Sign
        env:
          KMS_PKCS11_CONFIG: ${{ steps.apple_signing.outputs.pkcs11-config }}
          PKCS11_LIBRARY: ${{ steps.apple_signing.outputs.pkcs11-library }}
          CERTIFICATE_FILE: ${{ steps.apple_signing.outputs.certificate-file }}
          KEY_LABEL: ${{ secrets.AC_KMS_KEY }}
          GOOGLE_APPLICATION_CREDENTIALS: ${{ steps.gcloud_auth.outputs.credentials_file_path }}
        run: |
          rcodesign sign \
            --pkcs11-library "$PKCS11_LIBRARY" \
            --pkcs11-key-label "$KEY_LABEL" \
            --pkcs11-certificate-file "$CERTIFICATE_FILE" \
            --code-signature-flags runtime \
            path/to/binary

      - name: Delete signing files
        if: always()
        run: rm -rf "$RUNNER_TEMP/apple-signing"
```

To build `rcodesign` in one job and sign in another, upload the file at the
`path` output as an artifact and pass the `sha256` output to the signing job.

## `rcodesign`

Builds `rcodesign` from source at a pinned revision of
`indygreg/apple-platform-rs` with `pkcs11-single-init.patch` applied, and
installs it to `/usr/bin/rcodesign`.

| Input       | Default         | Description                                            |
|-------------|-----------------|--------------------------------------------------------|
| `rev`       | Pinned revision | Git revision of `indygreg/apple-platform-rs` to build. |
| `toolchain` | Pinned version  | Rust toolchain version to build with.                  |

| Output   | Description                           |
|----------|---------------------------------------|
| `path`   | Path of the built `rcodesign` binary. |
| `sha256` | SHA-256 checksum of the built binary. |

## Setup

Installs the Cloud KMS PKCS#11 library to `/usr/local/lib/libkmsp11.so`, and
writes its configuration and the certificate to `$RUNNER_TEMP/apple-signing`.

| Input             | Description                                                         |
|-------------------|---------------------------------------------------------------------|
| `certificate-pem` | Signing certificate in PEM format.                                  |
| `key-ring`        | Resource name of the Cloud KMS key ring that holds the signing key. |

| Output             | Description                                                       |
|--------------------|-------------------------------------------------------------------|
| `certificate-file` | Path of the signing certificate.                                  |
| `pkcs11-library`   | Path of the PKCS#11 library.                                      |
| `pkcs11-config`    | Path of the library configuration. Set `KMS_PKCS11_CONFIG` to it. |

## Development

`.github/workflows/ci.yml` runs both actions and lints the scripts and
workflows.

```sh
shellcheck scripts/*.sh rcodesign/*.sh
actionlint
```
