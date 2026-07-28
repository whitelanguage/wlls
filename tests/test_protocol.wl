// Test: LSP_PROTOCOL
// File: tests/test_protocol.wl
// Focus: JSON-RPC lifecycle, document synchronization, and language requests.
import "builtin"
import "../internal/server/_pkg.wl" as server

func main() -> Int {
    let service -> server.Server = server.Server();
    let response -> String = service.handle("{");
    if (response != "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32700,\"message\":\"Invalid JSON.\"}}") {
        builtin.print("FAIL: malformed JSON");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"capabilities\":{}}}");
    if (!response.starts_with("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"capabilities\":")) {
        builtin.print("FAIL: initialize");
        return 1;
    }
    response = service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}");
    if (response != "") {
        builtin.print("FAIL: initialized notification");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///memory.wl\",\"languageId\":\"whitelang\",\"version\":1,\"text\":\"func alpha() -> Int { return 1; }\"}}}");
    if (!response.starts_with("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///memory.wl\",\"version\":1,\"diagnostics\":[]")) {
        builtin.print("FAIL: didOpen");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/documentSymbol\",\"params\":{\"textDocument\":{\"uri\":\"file:///memory.wl\"}}}");
    if (!response.starts_with("{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":[{\"name\":\"alpha\",\"kind\":12,\"range\":")) {
        builtin.print("FAIL: document symbols");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///memory.wl\",\"version\":2},\"contentChanges\":[{\"text\":\"func broken( -> Int {\"}]}}");
    if (!response.starts_with("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"file:///memory.wl\",\"version\":2,\"diagnostics\":[{\"severity\":1")) {
        builtin.print("FAIL: diagnostics");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///memory.wl\",\"version\":3},\"contentChanges\":[{\"text\":\"const BASE -> Int = 1; func main() -> Int { return BASE; }\"}]}}");
    if (!response.ends_with("\"diagnostics\":[]}}")) {
        builtin.print("FAIL: diagnostic recovery");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"file:///memory.wl\"},\"position\":{\"line\":0,\"character\":51}}}");
    if (!response.starts_with("{\"jsonrpc\":\"2.0\",\"id\":3,\"result\":{\"uri\":\"file:///memory.wl\",\"range\":")) {
        builtin.print("FAIL: definition");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"textDocument/semanticTokens/full\",\"params\":{\"textDocument\":{\"uri\":\"file:///memory.wl\"}}}");
    if (!response.starts_with("{\"jsonrpc\":\"2.0\",\"id\":4,\"result\":{\"data\":[")) {
        builtin.print("FAIL: semantic tokens");
        return 1;
    }

    response = service.handle("{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"shutdown\",\"params\":null}");
    if (!service.shutdown_requested || response != "{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":null}") {
        builtin.print("FAIL: shutdown");
        return 1;
    }
    response = service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"exit\"}");
    if (!service.exit_received || response != "") {
        builtin.print("FAIL: exit");
        return 1;
    }

    builtin.print("PASS: LSP protocol");
    return 0;
}
