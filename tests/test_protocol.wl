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
    response = service.handle("[]");
    if (response != "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Invalid JSON-RPC request.\"}}") {
        builtin.print("FAIL: invalid request root");
        return 1;
    }
    response = service.handle("{\"jsonrpc\":\"2.0\",\"id\":true,\"method\":\"initialize\",\"params\":{}}");
    if (response != "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32600,\"message\":\"Request id must be a string, number, or null.\"}}") {
        builtin.print("FAIL: invalid request id");
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
    response = service.handle("{\"jsonrpc\":\"2.0\",\"id\":99,\"method\":\"workspace/unknown\"}");
    if (response != "{\"jsonrpc\":\"2.0\",\"id\":99,\"error\":{\"code\":-32601,\"message\":\"Method not found: workspace/unknown\"}}") {
        builtin.print("FAIL: unknown method");
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
    response = service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///memory.wl\",\"version\":3},\"contentChanges\":[{\"text\":\"func stale( -> Int {\"}]}}");
    if (response != "" || service.workspace.find("/memory.wl").text.starts_with("func stale")) {
        builtin.print("FAIL: stale document version");
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

    let refresh_service -> server.Server = server.Server();
    response = refresh_service.handle("{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"initialize\",\"params\":{\"capabilities\":{\"workspace\":{\"semanticTokens\":{\"refreshSupport\":true},\"didChangeWatchedFiles\":{\"dynamicRegistration\":true}}}}}");
    refresh_service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}");
    let outgoing -> Vector(String) = refresh_service.take_outgoing();
    if (outgoing.length() != 1 || !outgoing[0].starts_with("{\"jsonrpc\":\"2.0\",\"id\":1000000,\"method\":\"client/registerCapability\"") || !outgoing[0].ends_with("{\"globPattern\":\"**/*.wl\"}]}}]}}")) {
        builtin.print("FAIL: watched file registration");
        return 1;
    }
    refresh_service.handle("{\"jsonrpc\":\"2.0\",\"id\":1000000,\"result\":null}");
    refresh_service.workspace.frontend.update("/refresh.wl", -1, "func main() -> Int { return 1; }");
    refresh_service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///refresh.wl\",\"languageId\":\"whitelang\",\"version\":1,\"text\":\"func main() -> Int { return 0; }\"}}}");
    outgoing = refresh_service.take_outgoing();
    if (outgoing.length() != 1 || outgoing[0] != "{\"jsonrpc\":\"2.0\",\"id\":1000001,\"method\":\"workspace/semanticTokens/refresh\"}") {
        builtin.print("FAIL: semantic token refresh");
        return 1;
    }
    refresh_service.handle("{\"jsonrpc\":\"2.0\",\"id\":1000001,\"result\":null}");
    refresh_service.handle("{\"jsonrpc\":\"2.0\",\"method\":\"workspace/didChangeWatchedFiles\",\"params\":{\"changes\":[{\"uri\":\"file:///dependency.wl\",\"type\":2}]}}");
    outgoing = refresh_service.take_outgoing();
    if (outgoing.length() != 1 || outgoing[0] != "{\"jsonrpc\":\"2.0\",\"id\":1000002,\"method\":\"workspace/semanticTokens/refresh\"}") {
        builtin.print("FAIL: dependency refresh");
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
