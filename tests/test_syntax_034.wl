// Test: SYNTAX_034
// File: tests/test_syntax_034.wl
// Focus: New declaration syntax, inferred types, func methods, callable types, and tooling indexes.

import "../internal/frontend/_pkg.wl" as source
import "../internal/analysis/_pkg.wl" as analysis

func find_top_level(result: source.FrontendResult, name: String) -> source.SymbolDefinition {
    let i: Int = 0;
    while (i < result.semantics.definitions.length()) {
        let definition: source.SymbolDefinition = result.semantics.definitions[i];
        if (definition.top_level && definition.name == name) { return definition; }
        i += 1;
    }
    return null;
}

func has_token(tokens: Vector(Struct), line: Int, character: Int, token_type: String) -> Bool {
    let i: Int = 0;
    while (i < tokens.length()) {
        let token: analysis.SemanticToken = tokens[i];
        if (token.line == line && token.character == character && token.token_type == token_type) { return true; }
        i += 1;
    }
    return false;
}

func main() -> Int {
    let text = "let count: Int = 10;\n" +
        "let inferred = 10;\n" +
        "let explicit: Auto = 5;\n" +
        "const VERSION = 34;\n" +
        "func increment(value: Int) -> Int { return value + 1; }\n" +
        "interface Named {\n" +
        "    func display(prefix: String) -> String;\n" +
        "}\n" +
        "class User with Named {\n" +
        "    let name: String;\n" +
        "    let active = true;\n" +
        "    init(name: String) { self.name = name; }\n" +
        "    func display(prefix: String) -> String { return prefix + self.name; }\n" +
        "}\n" +
        "let user: User = User(\"white\");\n" +
        "let callback: Function(Int) -> Int = increment;\n" +
        "let bound: Method(String) -> String = user.display;\n";

    let workspace: source.FrontendWorkspace = source.FrontendWorkspace();
    let result: source.FrontendResult = workspace.update("syntax_034.wl", 1, text);
    if (!result.valid || result.semantics is null) { print("FAIL: 0.3.4 source did not parse"); return 1; }

    let inferred = find_top_level(result, "inferred");
    let explicit = find_top_level(result, "explicit");
    let callback = find_top_level(result, "callback");
    let bound = find_top_level(result, "bound");
    if (inferred is null || explicit is null || inferred.type_name != "Int" || explicit.type_name != "Int") { print("FAIL: Auto inference"); return 1; }
    if (callback is null || callback.type_name != "Function(Int) -> Int") { print("FAIL: Function type syntax"); return 1; }
    if (bound is null || bound.type_name != "Method(String) -> String") { print("FAIL: Method type syntax"); return 1; }
    if (analysis.encode_hover(inferred) != "{\"contents\":{\"kind\":\"markdown\",\"value\":\"```whitelang\\nlet inferred: Int\\n```\"}}") { print("FAIL: inferred hover"); return 1; }
    if (analysis.encode_hover(explicit) != "{\"contents\":{\"kind\":\"markdown\",\"value\":\"```whitelang\\nlet explicit: Int\\n```\"}}") { print("FAIL: explicit Auto hover"); return 1; }
    if (analysis.encode_hover(callback) != "{\"contents\":{\"kind\":\"markdown\",\"value\":\"```whitelang\\nlet callback: Function(Int) -> Int\\n```\"}}") { print("FAIL: callable hover"); return 1; }

    let method_def: source.SymbolDefinition = workspace.definition("syntax_034.wl", 12, 10);
    if (method_def is null || method_def.kind != source.SYMBOL_METHOD || analysis.encode_hover(method_def) != "{\"contents\":{\"kind\":\"markdown\",\"value\":\"```whitelang\\nfunc display(prefix: String) -> String\\n```\"}}") { print("FAIL: func method hover"); return 1; }

    let tokens = analysis.semantic_tokens(result, workspace, "syntax_034.wl");
    if (!has_token(tokens, 0, 9, "operator") || !has_token(tokens, 6, 9, "method") || !has_token(tokens, 12, 9, "method")) { print("FAIL: declaration semantic tokens"); return 1; }

    let field: source.SymbolDefinition = workspace.definition("syntax_034.wl", 12, 67);
    if (field is null || field.name != "name" || field.kind != source.SYMBOL_FIELD) { print("FAIL: func method field definition"); return 1; }

    let symbols = result.syntax.symbols;
    let found_method: Bool = false;
    let i: Int = 0;
    while (i < symbols.length()) {
        let symbol: source.DocumentSymbol = symbols[i];
        if (symbol.name == "User") {
            let j: Int = 0;
            while (j < symbol.children.length()) {
                let child: source.DocumentSymbol = symbol.children[j];
                if (child.name == "display" && child.kind == source.SYMBOL_METHOD) { found_method = true; }
                j += 1;
            }
        }
        i += 1;
    }
    if (!found_method) { print("FAIL: func method document symbol"); return 1; }

    print("PASS: 0.3.4 syntax");
    return 0;
}
