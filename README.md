# wlls

`wlls` is the White Language language server.

Currently, it supports:

- syntax diagnostics
- document symbols
- go to definition
- semantic highlighting
- full-text document synchronization

For the current method matrix and capability scope, see [docs/protocol.md](docs/protocol.md).

## Running

Launch via your LSP client over stdio:

```sh
wlls --stdio
```

## Building

Build from this repository with a White Language toolchain:

```sh
wlc wlls.wl -o wlls
```

On Windows:

```powershell
wlc wlls.wl -o wlls.exe
```

The compiler frontend snapshot used by the server is kept in `vendor/wlc-frontend`. Its source revision is recorded in `vendor/wlc-frontend/REVISION`. Syntax changes belong in the White Language compiler repository and are copied here after they have landed there.

## License

`wlls` is licensed under the [Apache License 2.0](LICENSE), the same license as
White Language.
