// Test: PARAMETER_FEATURES
// File: tests/test_params.wl
// Focus: Variadic parameters, defaults, spread calls, named arguments, hover, and completion.

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

func has_token(tokens: Vector(Struct), line: Int, character: Int, length: Int, token_type: String) -> Bool {
    let i: Int = 0;
    while (i < tokens.length()) {
        let token: analysis.SemanticToken = tokens[i];
        if (token.line == line && token.character == character && token.length == length && token.token_type == token_type) { return true; }
        i += 1;
    }
    return false;
}

func contains_text(text: String, part: String) -> Bool {
    if (part.length() == 0) { return true; }
    let i: Int = 0;
    while (i + part.length() <= text.length()) {
        if (text.slice(i, i + part.length()) == part) { return true; }
        i += 1;
    }
    return false;
}

func main() -> Int {
    let text: String = "func join(parts: String..., sep: String = \"-\") -> String {\n" +
        "    return parts[0] + sep;\n" +
        "}\n" +
        "func main() -> String {\n" +
        "    let parts: Vector(String) = [\"white\", \"language\"];\n" +
        "    return join(parts..., sep=\" \");\n" +
        "}\n";
    let workspace: source.FrontendWorkspace = source.FrontendWorkspace();
    let result: source.FrontendResult = workspace.update("params.wl", 1, text);
    if (!result.valid || result.semantics is null) { print("FAIL: parameter syntax"); return 1; }

    let join: source.SymbolDefinition = find_top_level(result, "join");
    if (join is null || join.signature != "func join(parts: String..., sep: String = \"-\") -> String") { print("FAIL: callable signature"); return 1; }
    if (analysis.encode_hover(join) != "{\"contents\":{\"kind\":\"markdown\",\"value\":\"```whitelang\\nfunc join(parts: String..., sep: String = \\\"-\\\") -> String\\n```\"}}") { print("FAIL: parameter hover"); return 1; }
    let parts: source.SymbolDefinition = workspace.definition("params.wl", 1, 11);
    if (parts is null || parts.type_name != "Array(String)" || parts.signature != "parts: String...") { print("FAIL: variadic parameter type"); return 1; }
    let separator: source.SymbolDefinition = workspace.definition("params.wl", 1, 22);
    if (separator is null || separator.signature != "sep: String = \"-\"") { print("FAIL: default parameter definition"); return 1; }

    let tokens: Vector(Struct) = analysis.semantic_tokens(result, workspace, "params.wl");
    if (!has_token(tokens, 0, 23, 3, "operator") || !has_token(tokens, 5, 21, 3, "operator")) { print("FAIL: variadic tokens"); return 1; }
    if (!has_token(tokens, 5, 26, 3, "parameter")) { print("FAIL: named argument token"); return 1; }

    let completion: String = analysis.encode_completions(result);
    if (!contains_text(completion, "\"label\":\"func variadic\"") || !contains_text(completion, "\"label\":\"func defaults\"")) { print("FAIL: parameter snippets"); return 1; }
    print("PASS: parameter features");
    return 0;
}
