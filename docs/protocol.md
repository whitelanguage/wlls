# Connecting an editor to wlls

`wlls` uses the Language Server Protocol(LSP) over stdin and stdout. Start one process for each editor workspace:

```text
wlls --stdio
```

Messages use JSON-RPC 2.0 and the standard `Content-Length` framing defined by LSP. Protocol traffic is written only to stdout. Treat stderr as a separate log
stream.

Use an existing LSP client library whenever the editor has one. The server does not require a White Language-specific transport adapter.

## What's actually working

Check the `initialize` result to see what's currently supported:

- UTF-16 positions
- full document synchronization
- open and close notifications
- push diagnostics
- document symbols
- go to definition
- full semantic tokens

Incremental document changes, semantic-token deltas, completion, hover, references, rename, formatting, and cancellation are not implemented yet. Don't assume they exist—check the advertised capabilities first.

## Session lifecycle

A client follows the standard LSP flow:

1. send the `initialize` request;
2. send the `initialized` notification;
3. synchronize documents with `textDocument/didOpen`,
   `textDocument/didChange`, and `textDocument/didClose`;
4. send language-feature requests as needed;
5. send the `shutdown` request;
6. send the `exit` notification.

`textDocument/didOpen`, `didChange`, `didClose`, `initialized`, and `exit` are notifications and don't expect responses. Syntax diagnostics are published via `textDocument/publishDiagnostics` after an open or accepted full-text change. Closing a document clears the diagnostics out.

Document identifiers are standard `file` URIs. Versions must bump up as the document changes. The server will ignore an older full-text update rather than overwrite a newer in-memory document.

## Supported requests

The server only implements these requests right now:

```text
initialize
shutdown
textDocument/documentSymbol
textDocument/definition
textDocument/semanticTokens/full
```

Definitions come back as standard LSP `Location` values. Document symbols use numeric `SymbolKind` values and include both `range` and `selectionRange`.

Semantic tokens use the legend returned by `initialize`. The response is a standard `SemanticTokens` object where the `data` field contains delta-encoded five-integer token records:

```text
deltaLine, deltaStart, length, tokenType, tokenModifiers
```

Token positions and lengths use UTF-16 code units, matching what the server advertised.

## VS Code

A VS Code extension should just boot up `wlls` using `vscode-languageclient`:

```ts
const serverOptions = {
    command: wllsPath,
    args: ["--stdio"],
};

const clientOptions = {
    documentSelector: [{ scheme: "file", language: "whitelang" }],
};

const client = new LanguageClient(
    "whitelanguage",
    "White Language",
    serverOptions,
    clientOptions,
);

await client.start();
```

Don't go registering separate VS Code providers for diagnostics, symbols, definitions, or semantic tokens while the client is active. Those get handled automatically by the capabilities returned from `initialize`.

Feel free to throw in a TextMate grammar for immediate lexical colors while the server spins up, but keep all semantic logic inside `wlls`. Don't build another White Language parser into the plugin.

## Workspace quirks & gotchas

Imported definitions won't resolve until the relevant source documents have been pushed into the same server workspace. Project-wide file discovery is pretty limited right now, so if you're opening an existing project, make sure to sync its White Language documents first if you want cross-file navigation to work.

Requests are handled synchronously. Queue your writes to stdin so message bodies don't get interleaved. If the process crashes, drop pending requests, spin up a fresh server, and reopen whatever documents the user currently has open.
