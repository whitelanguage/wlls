// standard LSP request loop
import "json"
import "../protocol/_pkg.wl" as protocol
import "../workspace/_pkg.wl" as workspace
import "../frontend/_pkg.wl" as source
import "../analysis/_pkg.wl" as analysis

class Server {
    let workspace -> workspace.Workspace;
    let initialized -> Bool;
    let shutdown_requested -> Bool;
    let exit_received -> Bool;

    init() {
        self.workspace = workspace.Workspace();
        self.initialized = false;
        self.shutdown_requested = false;
        self.exit_received = false;
    }

    method response(id -> String, result -> String) -> String {
        return "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"result\":" + result + "}";
    }

    method error_response(id -> String, code -> Int, message -> String) -> String {
        return "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"error\":{\"code\":" + code + ",\"message\":" + protocol.quote(message) + "}}";
    }

    method request_error(has_id -> Bool, id -> String, code -> Int, message -> String) -> String {
        if (!has_id) { return ""; }
        return self.error_response(id, code, message);
    }

    method publish_diagnostics(document -> workspace.Document) -> String {
        let uri -> String = protocol.path_to_uri(document.path);
        return "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":" + protocol.quote(uri) + ",\"version\":" + document.version + ",\"diagnostics\":" + analysis.encode_diagnostics(document.result.diagnostics) + "}}";
    }

    method initialize_result() -> String {
        return "{\"capabilities\":{\"positionEncoding\":\"utf-16\",\"textDocumentSync\":{\"openClose\":true,\"change\":1},\"documentSymbolProvider\":true,\"definitionProvider\":true,\"semanticTokensProvider\":{\"legend\":{\"tokenTypes\":[\"keyword\",\"type\",\"class\",\"struct\",\"interface\",\"enum\",\"enumMember\",\"function\",\"method\",\"parameter\",\"variable\",\"property\",\"string\",\"number\",\"comment\",\"operator\",\"decorator\"],\"tokenModifiers\":[\"declaration\",\"definition\",\"readonly\",\"static\",\"defaultLibrary\"]},\"full\":true}},\"serverInfo\":{\"name\":\"wlls\"}}";
    }

    method handle(message -> String) -> String {
        let request -> protocol.Request = protocol.decode_request(message)?;
        catch(err) { return self.error_response("null", -32700, "Invalid JSON."); }

        let id -> String = request.raw("id", "null");
        let has_id -> Bool = request.contains("id");
        let jsonrpc -> String = request.string("jsonrpc");
        let method_name -> String = request.string("method");
        if (jsonrpc != "2.0" || method_name is null) { return self.error_response(id, -32600, "Invalid JSON-RPC request."); }

        if (method_name == "initialize") {
            if (!has_id) { return ""; }
            if (self.initialized) { return self.request_error(has_id, id, -32600, "The server has already been initialized."); }
            self.initialized = true;
            return self.response(id, self.initialize_result());
        }
        if (method_name == "exit") {
            self.exit_received = true;
            return "";
        }
        if (!self.initialized) { return self.request_error(has_id, id, -32002, "The server has not been initialized."); }
        if (method_name == "initialized") { return ""; }
        if (method_name == "shutdown") {
            if (!has_id) { return ""; }
            self.shutdown_requested = true;
            return self.response(id, "null");
        }
        if (self.shutdown_requested) { return self.request_error(has_id, id, -32600, "The server is shutting down."); }

        let params -> protocol.Request = request.object("params");
        if (params is null) { return self.request_error(has_id, id, -32602, "Request parameters are missing."); }
        let text_document -> protocol.Request = params.object("textDocument");
        if (text_document is null) { return self.request_error(has_id, id, -32602, "textDocument is missing."); }
        let uri -> String = text_document.string("uri");
        let path -> String = protocol.uri_to_path(uri);
        if (path is null || path.length() == 0) { return self.request_error(has_id, id, -32602, "Document URI is missing."); }

        if (method_name == "textDocument/didOpen") {
            let text -> String = text_document.string("text");
            let version -> Int = text_document.int("version", 0);
            if (text is null) { return ""; }
            let document -> workspace.Document = self.workspace.open(path, version, text);
            return self.publish_diagnostics(document);
        }
        if (method_name == "textDocument/didChange") {
            let changes -> json.Value = params.array("contentChanges");
            if (changes is null) { return ""; }
            let count -> Int = changes.length()?;
            catch(err) { return ""; }
            if (count == 0) { return ""; }
            let change_value -> json.Value = changes.at(count - 1)?;
            catch(err) { return ""; }
            let change -> protocol.Request = protocol.Request(change_value);
            let text -> String = change.string("text");
            let version -> Int = text_document.int("version", 0);
            let current -> workspace.Document = self.workspace.find(path);
            if (text is null || (current is !null && version < current.version)) { return ""; }
            let document -> workspace.Document = self.workspace.open(path, version, text);
            return self.publish_diagnostics(document);
        }
        if (method_name == "textDocument/didClose") {
            self.workspace.close(path);
            return "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":" + protocol.quote(uri) + ",\"diagnostics\":[]}}";
        }

        let document -> workspace.Document = self.workspace.find(path);
        if (document is null) { return self.request_error(has_id, id, -32602, "Document is not open."); }
        let checked -> source.FrontendResult = document.result;

        if (method_name == "textDocument/documentSymbol") {
            if (!checked.valid) { return self.response(id, "[]"); }
            return self.response(id, analysis.encode_symbols(checked.syntax.symbols));
        }
        if (method_name == "textDocument/definition") {
            let position -> protocol.Request = params.object("position");
            if (position is null) { return self.request_error(has_id, id, -32602, "Position is missing."); }
            let line -> Int = position.int("line", -1);
            let character -> Int = position.int("character", -1);
            if (line < 0 || character < 0) { return self.request_error(has_id, id, -32602, "Position must be non-negative."); }
            let definition -> source.SymbolDefinition = self.workspace.frontend.definition(document.path, line, character);
            return self.response(id, analysis.encode_definition(definition));
        }
        if (method_name == "textDocument/semanticTokens/full") {
            if (!checked.valid) { return self.response(id, "{\"data\":[]}"); }
            return self.response(id, analysis.encode_semantic_tokens(analysis.semantic_tokens(checked, self.workspace.frontend, document.path)));
        }
        return self.request_error(has_id, id, -32601, "Method not found: " + method_name);
    }
}

func run() -> Int? {
    let server -> Server = Server();
    while (!server.exit_received) {
        let message -> String = protocol.read_message()?;
        if (message.length() == 0) { return 0; }
        let response -> String = server.handle(message);
        if (response.length() > 0) { protocol.write_message(response)?; }
    }
    if (server.shutdown_requested) { return 0; }
    return 1;
}
