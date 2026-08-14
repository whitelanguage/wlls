# editor protocol

`wlls` implements the Language Server Protocol (LSP) over standard input and
standard output. An editor normally starts one server process for each
workspace:

```text
wlls --stdio
```

Messages use JSON-RPC 2.0 and the `Content-Length` framing defined by LSP.
Protocol messages are written only to stdout. Stderr is reserved for logs and
must be read separately by the client.

Use the editor's existing LSP client library when one is available. `wlls` does
not require a White Language-specific transport layer.

## Capabilities

The `initialize` response is the authoritative list of capabilities supported
by the running server. The current implementation provides:

```text
full-text document synchronization
syntax diagnostics
document symbols
go to definition
full semantic tokens
semantic-token refresh after project changes
```

Positions use UTF-16 code units, as required by most LSP clients. Incremental
document changes, semantic-token deltas, completion, hover, references, rename,
formatting, and request cancellation are not implemented yet.

## Starting a session

A client starts a session in the usual LSP order:

1. send `initialize`;
2. send the `initialized` notification;
3. synchronize open documents;
4. send language-feature requests as needed.

The server currently accepts these requests:

```text
initialize
shutdown
textDocument/documentSymbol
textDocument/definition
textDocument/semanticTokens/full
```

It also accepts these notifications:

```text
initialized
textDocument/didOpen
textDocument/didChange
textDocument/didClose
exit
```

Notifications do not receive responses. A clean shutdown consists of a
`shutdown` request followed by an `exit` notification.

## Documents

Documents are identified by standard `file` URIs. Local paths, Windows drive
paths, and UNC paths are supported.

`textDocument/didOpen` supplies the initial text and version. A change must
contain the complete new document because the server advertises full-text
synchronization. Document versions must increase; an old or duplicate update
is ignored rather than allowed to replace a newer in-memory copy.

An open document belongs to the editor. Changes found on disk do not overwrite
an unsaved buffer. After `textDocument/didClose`, the in-memory copy is removed
and a later query may load the file from disk again.

## Diagnostics

After a document is opened or changed, syntax errors are published with
`textDocument/publishDiagnostics`. Closing a document publishes an empty list
to clear its diagnostics.

Diagnostics use LSP ranges and UTF-16 columns. Parsing errors do not prevent
the server from producing lexer-backed semantic tokens for source which can
still be classified safely.

## Symbols and definitions

`textDocument/documentSymbol` returns standard `DocumentSymbol` values.
`kind` uses the numeric LSP `SymbolKind`, and every symbol contains both
`range` and `selectionRange`.

`textDocument/definition` returns standard LSP `Location` values. Definitions
may point into another project file or into the standard library. An unresolved
name returns no location rather than a fabricated result.

## Semantic tokens

`textDocument/semanticTokens/full` returns a standard `SemanticTokens` object.
The `data` field contains delta-encoded groups of five integers:

```text
deltaLine, deltaStart, length, tokenType, tokenModifiers
```

Lines, columns, and token lengths are measured in UTF-16 code units. Token type
indexes and modifier bits refer to the legend returned by `initialize`.

The current token types are:

```text
keyword       type          class         struct
interface     enum          enumMember    function
method        parameter     variable      property
string        number        comment       operator
decorator     namespace     typeParameter
```

Module names and module aliases use `namespace`. A named import uses the token
type of the symbol it resolves to. Generic parameter declarations and their
references use `typeParameter`.

If the client advertises `workspace.semanticTokens.refreshSupport`, `wlls`
sends `workspace/semanticTokens/refresh` after an indexed document or dependency
changes. A client which advertises dynamic watched-file registration also
receives a `client/registerCapability` request for `**/*.wl`. Both are server
requests and require normal JSON-RPC responses.

## Project files

Relative `.wl` imports and standard-library imports are loaded from disk when
an analysis request first needs them. Standard-library lookup follows `wlc`:

```text
WL_PATH/std/<name>/_pkg.wl
WL_PATH/std/<name>.wl
```

`WL_PATH` must point to the White Language installation used by the project.
The implicit `errors`, `builtin`, and `dict` prelude is indexed in the same way
as it is by `wlc`. Prelude symbols and symbols loaded from `std` receive the
`defaultLibrary` semantic-token modifier.

The server does not scan every White Language file below the workspace root.
It indexes open documents and files reachable through their imports. Watched
file changes invalidate unopened dependencies before semantic tokens are
refreshed.

## VS Code

The VS Code extension can start `wlls` through `vscode-languageclient`:

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

The language client registers diagnostics, symbols, definitions, and semantic
tokens from the capabilities returned by `initialize`. Registering separate VS
Code providers for the same features causes the two implementations to compete.

A TextMate grammar may provide immediate lexical colors while the server is
starting. Name resolution and all other semantic classification remain in
`wlls`; the extension does not need its own White Language parser.

## Limits worth remembering

Requests are processed synchronously. A client must serialize writes to stdin
so that frame headers and bodies cannot become interleaved.

A message body is limited to 64 MiB and the header block to 8 KiB. A malformed,
duplicate, or overflowing `Content-Length` field closes the session.

If the server process exits unexpectedly, outstanding requests can no longer
complete. The client should discard them, start a new process, and reopen the
documents which are still active in the editor.
