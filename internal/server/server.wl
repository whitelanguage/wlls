// standard LSP request loop
import "json"
import "../protocol/_pkg.wl" as protocol
import "../workspace/_pkg.wl" as workspace
import "../frontend/_pkg.wl" as source
import "../analysis/_pkg.wl" as analysis

class Server {
    let workspace: workspace.Workspace;
    let initialized: Bool;
    let shutdown_requested: Bool;
    let exit_received: Bool;
    let outgoing: Vector(String);
    let next_request_id: Int;
    let semantic_refresh_supported: Bool;
    let semantic_refresh_pending: Bool;
    let semantic_refresh_id: Int;
    let file_watch_supported: Bool;
    let file_watch_pending: Bool;
    let file_watch_id: Int;

    init() {
        self.workspace = workspace.Workspace();
        self.initialized = false;
        self.shutdown_requested = false;
        self.exit_received = false;
        self.outgoing = [];
        self.next_request_id = 1000000;
        self.semantic_refresh_supported = false;
        self.semantic_refresh_pending = false;
        self.semantic_refresh_id = -1;
        self.file_watch_supported = false;
        self.file_watch_pending = false;
        self.file_watch_id = -1;
    }

    func response(id: String, result: String) -> String {
        return "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"result\":" + result + "}";
    }

    func error_response(id: String, code: Int, message: String) -> String {
        return "{\"jsonrpc\":\"2.0\",\"id\":" + id + ",\"error\":{\"code\":" + code + ",\"message\":" + protocol.quote(message) + "}}";
    }

    func request_error(has_id: Bool, id: String, code: Int, message: String) -> String {
        if (!has_id) { return ""; }
        return self.error_response(id, code, message);
    }

    func publish_diagnostics(document: workspace.Document) -> String {
        let uri: String = protocol.path_to_uri(document.path);
        return "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":" + protocol.quote(uri) + ",\"version\":" + document.version + ",\"diagnostics\":" + analysis.encode_diagnostics(document.result.diagnostics) + "}}";
    }

    func take_outgoing() -> Vector(String) {
        let messages: Vector(String) = self.outgoing;
        self.outgoing = [];
        return messages;
    }

    func __allocate_request_id() -> Int {
        let id: Int = self.next_request_id;
        self.next_request_id += 1;
        return id;
    }

    func __queue_semantic_refresh() -> Void {
        if (!self.semantic_refresh_supported || self.semantic_refresh_pending) { return; }
        self.semantic_refresh_id = self.__allocate_request_id();
        self.semantic_refresh_pending = true;
        self.outgoing.append("{\"jsonrpc\":\"2.0\",\"id\":" + self.semantic_refresh_id + ",\"method\":\"workspace/semanticTokens/refresh\"}");
    }

    func __queue_file_watch() -> Void {
        if (!self.file_watch_supported || self.file_watch_pending) { return; }
        self.file_watch_id = self.__allocate_request_id();
        self.file_watch_pending = true;
        self.outgoing.append("{\"jsonrpc\":\"2.0\",\"id\":" + self.file_watch_id + ",\"method\":\"client/registerCapability\",\"params\":{\"registrations\":[{\"id\":\"wlls-watch-wl\",\"method\":\"workspace/didChangeWatchedFiles\",\"registerOptions\":{\"watchers\":[{\"globPattern\":\"**/*.wl\"}]}}]}}");
    }

    func __complete_request(request: protocol.Request) -> Void {
        let id: Int = request.int("id", -1);
        if (id == self.semantic_refresh_id) {
            self.semantic_refresh_pending = false;
            self.semantic_refresh_id = -1;
        }
        if (id == self.file_watch_id) {
            self.file_watch_pending = false;
            self.file_watch_id = -1;
            if (request.contains("error")) { self.file_watch_supported = false; }
        }
    }

    func __read_client_capabilities(params: protocol.Request) -> Void {
        if (params is null) { return; }
        let capabilities: protocol.Request = params.object("capabilities");
        if (capabilities is null) { return; }
        let workspace_capabilities: protocol.Request = capabilities.object("workspace");
        if (workspace_capabilities is null) { return; }
        let semantic_tokens: protocol.Request = workspace_capabilities.object("semanticTokens");
        if (semantic_tokens is !null) { self.semantic_refresh_supported = semantic_tokens.bool("refreshSupport", false); }
        let watched_files: protocol.Request = workspace_capabilities.object("didChangeWatchedFiles");
        if (watched_files is !null) { self.file_watch_supported = watched_files.bool("dynamicRegistration", false); }
    }

    func initialize_result() -> String {
        return "{\"capabilities\":{\"positionEncoding\":\"utf-16\",\"textDocumentSync\":{\"openClose\":true,\"change\":1},\"documentSymbolProvider\":true,\"definitionProvider\":true,\"hoverProvider\":true,\"completionProvider\":{\"resolveProvider\":false},\"semanticTokensProvider\":{\"legend\":{\"tokenTypes\":[\"keyword\",\"type\",\"class\",\"struct\",\"interface\",\"enum\",\"enumMember\",\"function\",\"method\",\"parameter\",\"variable\",\"property\",\"string\",\"number\",\"comment\",\"operator\",\"decorator\",\"namespace\",\"typeParameter\"],\"tokenModifiers\":[\"declaration\",\"definition\",\"readonly\",\"static\",\"defaultLibrary\"]},\"full\":true}},\"serverInfo\":{\"name\":\"wlls\"}}";
    }

    func handle(message: String) -> String {
        let root: json.Value = json.decode(message)?;
        catch(err) { return self.error_response("null", -32700, "Invalid JSON."); }
        if (root.kind() != json.Kind.Object) { return self.error_response("null", -32600, "Invalid JSON-RPC request."); }
        let request: protocol.Request = protocol.Request(root);
        if (!request.valid_id()) { return self.error_response("null", -32600, "Request id must be a string, number, or null."); }

        let id: String = request.raw("id", "null");
        let has_id: Bool = request.contains("id");
        let jsonrpc: String = request.string("jsonrpc");
        let method_name: String = request.string("method");
        if (jsonrpc != "2.0") { return self.error_response(id, -32600, "Invalid JSON-RPC request."); }
        if (method_name is null && has_id && (request.contains("result") || request.contains("error"))) {
            self.__complete_request(request);
            return "";
        }
        if (method_name is null) { return self.error_response(id, -32600, "Invalid JSON-RPC request."); }

        if (method_name == "initialize") {
            if (!has_id) { return ""; }
            if (self.initialized) { return self.request_error(has_id, id, -32600, "The server has already been initialized."); }
            self.__read_client_capabilities(request.object("params"));
            self.initialized = true;
            return self.response(id, self.initialize_result());
        }
        if (method_name == "exit") {
            self.exit_received = true;
            return "";
        }
        if (!self.initialized) { return self.request_error(has_id, id, -32002, "The server has not been initialized."); }
        if (method_name == "initialized") {
            self.__queue_file_watch();
            return "";
        }
        if (method_name == "shutdown") {
            if (!has_id) { return ""; }
            self.shutdown_requested = true;
            return self.response(id, "null");
        }
        if (self.shutdown_requested) { return self.request_error(has_id, id, -32600, "The server is shutting down."); }
        if (method_name == "workspace/didChangeWatchedFiles") {
            let params: protocol.Request = request.object("params");
            if (params is null) { return ""; }
            let changes: json.Value = params.array("changes");
            if (changes is null) { return ""; }
            let count: Int = changes.length()?;
            catch(err) { return ""; }
            let changed: Bool = false;
            let i: Int = 0;
            while (i < count) {
                let change_value: json.Value = changes.at(i)?;
                catch(err) { return ""; }
                let change: protocol.Request = protocol.Request(change_value);
                let changed_path: String = protocol.uri_to_path(change.string("uri"));
                if (changed_path is !null) {
                    if (!self.workspace.is_open(changed_path)) { self.workspace.invalidate(changed_path); }
                    changed = true;
                }
                i += 1;
            }
            if (changed) { self.__queue_semantic_refresh(); }
            return "";
        }
        let document_method: Bool = method_name == "textDocument/didOpen" || method_name == "textDocument/didChange" || method_name == "textDocument/didClose" || method_name == "textDocument/documentSymbol" || method_name == "textDocument/definition" || method_name == "textDocument/hover" || method_name == "textDocument/completion" || method_name == "textDocument/semanticTokens/full";
        if (!document_method) { return self.request_error(has_id, id, -32601, "Method not found: " + method_name); }

        let params: protocol.Request = request.object("params");
        if (params is null) { return self.request_error(has_id, id, -32602, "Request parameters are missing."); }
        let text_document: protocol.Request = params.object("textDocument");
        if (text_document is null) { return self.request_error(has_id, id, -32602, "textDocument is missing."); }
        let uri: String = text_document.string("uri");
        let path: String = protocol.uri_to_path(uri);
        if (path is null || path.length() == 0) { return self.request_error(has_id, id, -32602, "Document URI is missing."); }

        if (method_name == "textDocument/didOpen") {
            let text: String = text_document.string("text");
            let version: Int = text_document.int("version", 0);
            if (text is null) { return ""; }
            let current: workspace.Document = self.workspace.find(path);
            if (current is !null && version <= current.version) { return ""; }
            let was_indexed: Bool = self.workspace.is_indexed(path);
            let document: workspace.Document = self.workspace.open(path, version, text);
            if (was_indexed) { self.__queue_semantic_refresh(); }
            return self.publish_diagnostics(document);
        }
        if (method_name == "textDocument/didChange") {
            let changes: json.Value = params.array("contentChanges");
            if (changes is null) { return ""; }
            let count: Int = changes.length()?;
            catch(err) { return ""; }
            if (count == 0) { return ""; }
            let change_value: json.Value = changes.at(count - 1)?;
            catch(err) { return ""; }
            let change: protocol.Request = protocol.Request(change_value);
            let text: String = change.string("text");
            let version: Int = text_document.int("version", 0);
            let current: workspace.Document = self.workspace.find(path);
            if (text is null || (current is !null && version <= current.version)) { return ""; }
            let document: workspace.Document = self.workspace.open(path, version, text);
            return self.publish_diagnostics(document);
        }
        if (method_name == "textDocument/didClose") {
            self.workspace.close(path);
            self.__queue_semantic_refresh();
            return "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":" + protocol.quote(uri) + ",\"diagnostics\":[]}}";
        }

        let document: workspace.Document = self.workspace.find(path);
        if (document is null) { return self.request_error(has_id, id, -32602, "Document is not open."); }
        let checked: source.FrontendResult = document.result;
        if (!has_id) { return ""; }

        if (method_name == "textDocument/documentSymbol") {
            if (!checked.valid) { return self.response(id, "[]"); }
            return self.response(id, analysis.encode_symbols(checked.syntax.symbols));
        }
        if (method_name == "textDocument/definition") {
            let position: protocol.Request = params.object("position");
            if (position is null) { return self.request_error(has_id, id, -32602, "Position is missing."); }
            let line: Int = position.int("line", -1);
            let character: Int = position.int("character", -1);
            if (line < 0 || character < 0) { return self.request_error(has_id, id, -32602, "Position must be non-negative."); }
            let definition: source.SymbolDefinition = self.workspace.frontend.definition(document.path, line, character);
            return self.response(id, analysis.encode_definition(definition));
        }
        if (method_name == "textDocument/hover") {
            let position: protocol.Request = params.object("position");
            if (position is null) { return self.request_error(has_id, id, -32602, "Position is missing."); }
            let line: Int = position.int("line", -1);
            let character: Int = position.int("character", -1);
            if (line < 0 || character < 0) { return self.request_error(has_id, id, -32602, "Position must be non-negative."); }
            let definition: source.SymbolDefinition = self.workspace.frontend.definition(document.path, line, character);
            return self.response(id, analysis.encode_hover(definition));
        }
        if (method_name == "textDocument/completion") {
            let position: protocol.Request = params.object("position");
            if (position is null) { return self.request_error(has_id, id, -32602, "Position is missing."); }
            let line: Int = position.int("line", -1);
            let character: Int = position.int("character", -1);
            if (line < 0 || character < 0) { return self.request_error(has_id, id, -32602, "Position must be non-negative."); }
            return self.response(id, analysis.encode_completions(checked));
        }
        if (method_name == "textDocument/semanticTokens/full") {
            return self.response(id, analysis.encode_semantic_tokens(analysis.semantic_tokens(checked, self.workspace.frontend, document.path)));
        }
        return self.request_error(has_id, id, -32601, "Method not found: " + method_name);
    }
}

func run() -> Int? {
    let server: Server = Server();
    while (!server.exit_received) {
        let message: protocol.Message = protocol.read_message()?;
        if (message.closed) { return 0; }
        let response: String = server.handle(message.body);
        if (response.length() > 0) { protocol.write_message(response)?; }
        let outgoing: Vector(String) = server.take_outgoing();
        let i: Int = 0;
        while (i < outgoing.length()) {
            protocol.write_message(outgoing[i])?;
            i += 1;
        }
    }
    if (server.shutdown_requested) { return 0; }
    return 1;
}
