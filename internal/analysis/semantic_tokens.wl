// semantic token collection and protocol encoding
import Dict from "dict"
import "../frontend/_pkg.wl" as source
import "../compiler/_pkg.wl" as compiler
import "../protocol/_pkg.wl" as protocol

class SemanticToken {
    let line: Int;
    let character: Int;
    let length: Int;
    let token_type: String;
    let modifiers: Vector(String);

    init(line: Int, character: Int, length: Int, token_type: String, modifiers: Vector(String)) {
        self.line = line;
        self.character = character;
        self.length = length;
        self.token_type = token_type;
        self.modifiers = modifiers;
    }
}

class __TokenBinding {
    let kind: Int;
    let readonly: Bool;
    let top_level: Bool;
    let declaration: Bool;
    let default_library: Bool;

    init(kind: Int, readonly: Bool, top_level: Bool, declaration: Bool, default_library: Bool) {
        self.kind = kind;
        self.readonly = readonly;
        self.top_level = top_level;
        self.declaration = declaration;
        self.default_library = default_library;
    }
}

func __token_key(line: Int, character: Int) -> String {
    return line + ":" + character;
}

func __index_document_symbols(symbols: Vector(Struct), bindings: Dict, top_level: Bool) -> Void {
    let i: Int = 0;
    while (i < symbols.length()) {
        let symbol: source.DocumentSymbol = symbols[i];
        let position: compiler.WhitelangExceptions.SourcePosition = symbol.span.start;
        bindings.put(__token_key(position.line, position.utf16_column), __TokenBinding(symbol.kind, symbol.kind == source.SYMBOL_CONSTANT, top_level, true, false));
        __index_document_symbols(symbol.children, bindings, false);
        i += 1;
    }
}

func __binding_from_definition(definition: source.SymbolDefinition, declaration: Bool, default_library: Bool) -> __TokenBinding {
    if (definition is null) { return null; }
    return __TokenBinding(definition.kind, definition.kind == source.SYMBOL_CONSTANT, definition.top_level, declaration, default_library);
}

func __build_bindings(result: source.FrontendResult, workspace: source.FrontendWorkspace, path: String) -> Dict {
    let bindings: Dict = Dict(64);
    __index_document_symbols(result.syntax.symbols, bindings, true);
    if (result.semantics is null) { return bindings; }

    let i: Int = 0;
    while (i < result.semantics.definitions.length()) {
        let definition: source.SymbolDefinition = result.semantics.definitions[i];
        let binding_definition: source.SymbolDefinition = definition;
        if (definition.kind == source.SYMBOL_IMPORT) {
            let imported: source.SymbolDefinition = workspace.resolve_import(path, definition);
            if (imported is !null) { binding_definition = imported; }
        }
        bindings.put(__token_key(definition.range.start.line, definition.range.start.utf16_column), __binding_from_definition(binding_definition, true, workspace.is_default_library(path, binding_definition)));
        i += 1;
    }

    i = 0;
    while (i < result.semantics.references.length()) {
        let reference: source.SymbolReference = result.semantics.references[i];
        let definition: source.SymbolDefinition = reference.definition;
        if (definition is null || definition.kind == source.SYMBOL_IMPORT || definition.kind == source.SYMBOL_MODULE) {
            definition = workspace.resolve_reference(path, reference);
        }
        if (definition is !null) {
            bindings.put(__token_key(reference.range.start.line, reference.range.start.utf16_column), __binding_from_definition(definition, false, workspace.is_default_library(path, definition)));
        }
        i += 1;
    }
    return bindings;
}

func __semantic_type(kind: Int) -> String {
    if (kind == source.SYMBOL_FUNCTION) { return "function"; }
    if (kind == source.SYMBOL_METHOD) { return "method"; }
    if (kind == source.SYMBOL_CONVERSION) { return "keyword"; }
    if (kind == source.SYMBOL_PARAMETER) { return "parameter"; }
    if (kind == source.SYMBOL_TYPE_PARAMETER) { return "typeParameter"; }
    if (kind == source.SYMBOL_TYPE) { return "type"; }
    if (kind == source.SYMBOL_FIELD) { return "property"; }
    if (kind == source.SYMBOL_CLASS) { return "class"; }
    if (kind == source.SYMBOL_STRUCT) { return "struct"; }
    if (kind == source.SYMBOL_INTERFACE) { return "interface"; }
    if (kind == source.SYMBOL_ENUM || kind == source.SYMBOL_ERROR) {
        return "enum";
    }
    if (kind == source.SYMBOL_ENUM_CASE || kind == source.SYMBOL_ERROR_CASE) {
        return "enumMember";
    }
    if (kind == source.SYMBOL_MODULE) { return "namespace"; }
    if (kind == source.SYMBOL_IMPORT) { return "variable"; }
    return "variable";
}

func __binding_modifiers(binding: __TokenBinding) -> Vector(String) {
    let modifiers: Vector(String) = [];
    if (binding is null) { return modifiers; }
    if (binding.declaration) { modifiers.append("declaration"); }
    if (binding.readonly) { modifiers.append("readonly"); }
    if (binding.default_library) { modifiers.append("defaultLibrary"); }
    return modifiers;
}

func __is_builtin_type(token_type: Int) -> Bool {
    return token_type == compiler.WhitelangTokens.TOK_T_INT ||
           token_type == compiler.WhitelangTokens.TOK_T_FLOAT ||
           token_type == compiler.WhitelangTokens.TOK_T_STRING ||
           token_type == compiler.WhitelangTokens.TOK_T_BOOL ||
           token_type == compiler.WhitelangTokens.TOK_T_CHAR ||
           token_type == compiler.WhitelangTokens.TOK_T_VOID;
}

func __is_builtin_type_name(name: String) -> Bool {
    return name == "Int" || name == "Int32" || name == "Long" || name == "Int64" || name == "Float" || name == "Float64" || name == "Byte" || name == "UInt8" || name == "Int8" || name == "Int16" || name == "Int128" || name == "UInt16" || name == "UInt32" || name == "UInt64" || name == "UInt128" || name == "Float32" || name == "IntSize" || name == "UIntSize" || name == "Bool" || name == "Char" || name == "String" || name == "Void" || name == "Struct" || name == "Function" || name == "Class" || name == "Method" || name == "Enum" || name == "Auto" || name == "AnyPtr" || name == "Vector" || name == "Array";
}

func __is_space(value: Char) -> Bool {
    return value == ' ' || value == '\t' || value == '\r' || value == '\n';
}

func __is_named_argument(result: source.FrontendResult, token: compiler.WhitelangTokens.Token) -> Bool {
    let text: String = result.syntax.source;
    let start: Int = result.syntax.source_map.line_start(token.line) + token.col;
    let left: Int = start - 1;
    while (left >= 0 && __is_space(text[left])) { left -= 1; }
    let right: Int = start + token.value.length();
    while (right < text.length() && __is_space(text[right])) { right += 1; }
    return left >= 0 && right < text.length() && (text[left] == '(' || text[left] == ',') && text[right] == '=';
}

func __is_callable_label(result: source.FrontendResult, token: compiler.WhitelangTokens.Token) -> Bool {
    let text: String = result.syntax.source;
    let start: Int = result.syntax.source_map.line_start(token.line) + token.col;
    let right: Int = start + token.value.length();
    while (right < text.length() && __is_space(text[right])) { right += 1; }
    if (right >= text.length() || text[right] != ':') { return false; }
    let cursor: Int = start - 1;
    let depth: Int = 0;
    while (cursor >= 0) {
        if (text[cursor] == ')') { depth += 1; }
        else if (text[cursor] == '(') {
            if (depth > 0) { depth -= 1; }
            else {
                let word_start: Int = cursor - 1;
                while (word_start >= 0 && __is_space(text[word_start])) { word_start -= 1; }
                let end: Int = word_start + 1;
                while (word_start >= 0 && ((text[word_start] >= 'a' && text[word_start] <= 'z') || (text[word_start] >= 'A' && text[word_start] <= 'Z'))) { word_start -= 1; }
                let name: String = text.slice(word_start + 1, end);
                return name == "Function" || name == "Method";
            }
        }
        cursor -= 1;
    }
    return false;
}

func __is_operator(token_type: Int) -> Bool {
    return token_type == compiler.WhitelangTokens.TOK_PLUS ||
           token_type == compiler.WhitelangTokens.TOK_SUB ||
           token_type == compiler.WhitelangTokens.TOK_MUL ||
           token_type == compiler.WhitelangTokens.TOK_DIV ||
           token_type == compiler.WhitelangTokens.TOK_MOD ||
           token_type == compiler.WhitelangTokens.TOK_POW ||
           token_type == compiler.WhitelangTokens.TOK_INC ||
           token_type == compiler.WhitelangTokens.TOK_DEC ||
           token_type == compiler.WhitelangTokens.TOK_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_COLON ||
           token_type == compiler.WhitelangTokens.TOK_TYPE_ARROW ||
           token_type == compiler.WhitelangTokens.TOK_ELLIPSIS ||
           token_type == compiler.WhitelangTokens.TOK_EE ||
           token_type == compiler.WhitelangTokens.TOK_NE ||
           token_type == compiler.WhitelangTokens.TOK_GT ||
           token_type == compiler.WhitelangTokens.TOK_LT ||
           token_type == compiler.WhitelangTokens.TOK_GTE ||
           token_type == compiler.WhitelangTokens.TOK_LTE ||
           token_type == compiler.WhitelangTokens.TOK_AND ||
           token_type == compiler.WhitelangTokens.TOK_OR ||
           token_type == compiler.WhitelangTokens.TOK_NOT ||
           token_type == compiler.WhitelangTokens.TOK_PLUS_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_SUB_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_MUL_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_DIV_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_MOD_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_POW_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_BIT_AND ||
           token_type == compiler.WhitelangTokens.TOK_BIT_OR ||
           token_type == compiler.WhitelangTokens.TOK_BIT_XOR ||
           token_type == compiler.WhitelangTokens.TOK_BIT_NOT ||
           token_type == compiler.WhitelangTokens.TOK_LSHIFT ||
           token_type == compiler.WhitelangTokens.TOK_RSHIFT ||
           token_type == compiler.WhitelangTokens.TOK_BIT_AND_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_BIT_OR_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_BIT_XOR_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_LSHIFT_ASSIGN ||
           token_type == compiler.WhitelangTokens.TOK_RSHIFT_ASSIGN;
}

func __is_keyword(token_type: Int) -> Bool {
    return token_type == compiler.WhitelangTokens.TOK_LET || token_type == compiler.WhitelangTokens.TOK_TRUE || token_type == compiler.WhitelangTokens.TOK_FALSE || token_type == compiler.WhitelangTokens.TOK_IF || token_type == compiler.WhitelangTokens.TOK_ELSE || token_type == compiler.WhitelangTokens.TOK_WHILE || token_type == compiler.WhitelangTokens.TOK_BREAK || token_type == compiler.WhitelangTokens.TOK_CONTINUE || token_type == compiler.WhitelangTokens.TOK_FOR || token_type == compiler.WhitelangTokens.TOK_FUNC || token_type == compiler.WhitelangTokens.TOK_RETURN || token_type == compiler.WhitelangTokens.TOK_STRUCT || token_type == compiler.WhitelangTokens.TOK_THIS || token_type == compiler.WhitelangTokens.TOK_PTR || token_type == compiler.WhitelangTokens.TOK_REF || token_type == compiler.WhitelangTokens.TOK_DEREF || token_type == compiler.WhitelangTokens.TOK_NULLPTR || token_type == compiler.WhitelangTokens.TOK_NULL || token_type == compiler.WhitelangTokens.TOK_IS || token_type == compiler.WhitelangTokens.TOK_EXTERN || token_type == compiler.WhitelangTokens.TOK_FROM || token_type == compiler.WhitelangTokens.TOK_IMPORT || token_type == compiler.WhitelangTokens.TOK_CONST || token_type == compiler.WhitelangTokens.TOK_AS || token_type == compiler.WhitelangTokens.TOK_CLASS || token_type == compiler.WhitelangTokens.TOK_METHOD || token_type == compiler.WhitelangTokens.TOK_SELF || token_type == compiler.WhitelangTokens.TOK_SUPER || token_type == compiler.WhitelangTokens.TOK_ENUM || token_type == compiler.WhitelangTokens.TOK_INTERFACE || token_type == compiler.WhitelangTokens.TOK_WITH || token_type == compiler.WhitelangTokens.TOK_CATCH || token_type == compiler.WhitelangTokens.TOK_THROW || token_type == compiler.WhitelangTokens.TOK_IN || token_type == compiler.WhitelangTokens.TOK_ERROR;
}

func __append_span(tokens: Vector(Struct), source_map: source.SourceMap, start_line: Int, start_col: Int, end_line: Int, end_col: Int, token_type: String, modifiers: Vector(String)) -> Void {
    let line: Int = start_line;
    while (line <= end_line) {
        let line_start: Int = source_map.line_start(line);
        let byte_start: Int = 0;
        if (line == start_line) { byte_start = start_col; }

        let byte_end: Int = source_map.line_end(line) - line_start;
        if (line == end_line) { byte_end = end_col; }

        if (byte_end > byte_start) {
            let start: compiler.WhitelangExceptions.SourcePosition = source_map.position(line, byte_start);
            let end: compiler.WhitelangExceptions.SourcePosition = source_map.position(line, byte_end);
            let length: Int = end.utf16_column - start.utf16_column;
            if (length > 0) {
                tokens.append(SemanticToken(line, start.utf16_column, length, token_type, modifiers));
            }
        }
        line += 1;
    }
}

func __append_trivia(tokens: Vector(Struct), source_map: source.SourceMap, trivia: compiler.WhitelangLexer.LexerTrivia) -> Void {
    __append_span(tokens, source_map, trivia.start_line, trivia.start_col, trivia.end_line, trivia.end_col, "comment", []);
}

func semantic_tokens(result: source.FrontendResult, workspace: source.FrontendWorkspace, path: String) -> Vector(Struct) {
    // lexical tokens come from wlc; the semantic index only refines identifiers
    let tokens: Vector(Struct) = [];
    if (result is null || result.syntax is null || result.syntax.source_map is null) { return tokens; }

    let bindings: Dict = __build_bindings(result, workspace, path);
    let source_map: source.SourceMap = result.syntax.source_map;
    let lexer: compiler.WhitelangLexer.Lexer = compiler.WhitelangLexer.new_lexer_trivia( result.syntax.path, result.syntax.source );
    let trivia_index: Int = 0;
    let annotation_name: Bool = false;
    compiler.WhitelangExceptions.begin_error_collection();

    while true {
        let token: compiler.WhitelangTokens.Token = compiler.WhitelangLexer.get_next_token(lexer);

        while (trivia_index < lexer.trivia.length()) {
            __append_trivia(tokens, source_map, lexer.trivia[trivia_index]);
            trivia_index += 1;
        }

        if (token.type == compiler.WhitelangTokens.TOK_EOF) { break; }

        let start: compiler.WhitelangExceptions.SourcePosition = source_map.position(token.line, token.col);
        let token_type: String = "";
        let modifiers: Vector(String) = [];

        if (token.type == compiler.WhitelangTokens.TOK_AT) {
            token_type = "annotation";
            annotation_name = true;
        } else if (annotation_name) {
            token_type = "annotation";
            annotation_name = false;
        } else if (__is_builtin_type(token.type)) {
            token_type = "type";
            modifiers.append("defaultLibrary");
        } else if (token.type == compiler.WhitelangTokens.TOK_STR_LIT || token.type == compiler.WhitelangTokens.TOK_CHAR_LIT) {
            token_type = "string";
        } else if (token.type == compiler.WhitelangTokens.TOK_INT || token.type == compiler.WhitelangTokens.TOK_FLOAT) {
            token_type = "number";
        } else if (__is_operator(token.type)) {
            token_type = "operator";
        } else if (token.type == compiler.WhitelangTokens.TOK_IDENTIFIER || token.type == compiler.WhitelangTokens.TOK_TYPE) {
            let binding: __TokenBinding = bindings[__token_key(token.line, start.utf16_column)];
            if (binding is !null) {
                token_type = __semantic_type(binding.kind);
                modifiers = __binding_modifiers(binding);
            } else if (token.value == "Self") {
                token_type = "type";
            } else if (__is_builtin_type_name(token.value)) {
                token_type = "type";
                modifiers.append("defaultLibrary");
            } else if (__is_callable_label(result, token)) {
                token_type = "parameter";
            } else if (__is_named_argument(result, token)) {
                token_type = "parameter";
            } else if (token.type == compiler.WhitelangTokens.TOK_TYPE) {
                token_type = "keyword";
            } else {
                token_type = "variable";
            }
        } else if (__is_keyword(token.type)) {
            token_type = "keyword";
        }

        if (token_type.length() > 0) {
            __append_span(tokens, source_map, token.line, token.col, lexer.pos.ln, lexer.pos.col, token_type, modifiers);
        }
    }
    compiler.WhitelangExceptions.end_error_collection();
    compiler.WhitelangExceptions.reset_errors();
    return tokens;
}

func __token_type_index(token_type: String) -> Int {
    if (token_type == "keyword") { return 0; }
    if (token_type == "type") { return 1; }
    if (token_type == "class") { return 2; }
    if (token_type == "struct") { return 3; }
    if (token_type == "interface") { return 4; }
    if (token_type == "enum") { return 5; }
    if (token_type == "enumMember") { return 6; }
    if (token_type == "function") { return 7; }
    if (token_type == "method") { return 8; }
    if (token_type == "parameter") { return 9; }
    if (token_type == "variable") { return 10; }
    if (token_type == "property") { return 11; }
    if (token_type == "string") { return 12; }
    if (token_type == "number") { return 13; }
    if (token_type == "comment") { return 14; }
    if (token_type == "operator") { return 15; }
    if (token_type == "annotation") { return 16; }
    if (token_type == "namespace") { return 17; }
    if (token_type == "typeParameter") { return 18; }
    return 10;
}

func __modifier_bits(modifiers: Vector(String)) -> Int {
    let result: Int = 0;
    let i: Int = 0;
    while (i < modifiers.length()) {
        if (modifiers[i] == "declaration") { result |= 1; }
        else if (modifiers[i] == "definition") { result |= 2; }
        else if (modifiers[i] == "readonly") { result |= 4; }
        else if (modifiers[i] == "static") { result |= 8; }
        else if (modifiers[i] == "defaultLibrary") { result |= 16; }
        i += 1;
    }
    return result;
}

func encode_semantic_tokens(tokens: Vector(Struct)) -> String {
    let initial_capacity: Int = 16;
    if (tokens.length() <= (protocol.MAX_BUFFER_CAPACITY - 16) / 12) { initial_capacity = tokens.length() * 12 + 16; }
    let output: protocol.ByteBuffer = protocol.ByteBuffer(initial_capacity);
    if (!output.write("{\"data\":[")) { return "{\"data\":[]}"; }
    let i: Int = 0;
    let previous_line: Int = 0;
    let previous_character: Int = 0;
    while (i < tokens.length()) {
        let token: SemanticToken = tokens[i];
        let delta_line: Int = token.line - previous_line;
        let delta_start: Int = token.character;
        if (delta_line == 0) { delta_start -= previous_character; }
        if (i > 0 && !output.write_byte(Byte(44))) { return "{\"data\":[]}"; }
        if (!output.write_uint(delta_line) || !output.write_byte(Byte(44)) || !output.write_uint(delta_start) || !output.write_byte(Byte(44)) || !output.write_uint(token.length) || !output.write_byte(Byte(44)) || !output.write_uint(__token_type_index(token.token_type)) || !output.write_byte(Byte(44)) || !output.write_uint(__modifier_bits(token.modifiers))) { return "{\"data\":[]}"; }
        previous_line = token.line;
        previous_character = token.character;
        i += 1;
    }
    if (!output.write("]}")) { return "{\"data\":[]}"; }
    let result: String = output.finish();
    if (result is null) { return "{\"data\":[]}"; }
    return result;
}
