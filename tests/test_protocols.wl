// Test: PROTOCOL_SEMANTICS
// File: tests/test_protocols.wl
// Focus: Self types, interface inheritance, inherited members, and protocol signatures.

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
    let text: String = "interface Equal {\n" +
        "    func equals(other: Self) -> Bool;\n" +
        "}\n" +
        "interface Hash with Equal {\n" +
        "    func hash() -> Int;\n" +
        "}\n" +
        "interface Display {\n" +
        "    func display() -> String;\n" +
        "}\n" +
        "interface Key with Hash, Display {\n" +
        "}\n" +
        "func same(value: Key, other: Key) -> Bool {\n" +
        "    return value.equals(other);\n" +
        "}\n";
    let workspace: source.FrontendWorkspace = source.FrontendWorkspace();
    let result: source.FrontendResult = workspace.update("protocols.wl", 1, text);
    if (!result.valid || result.semantics is null) { print("FAIL: protocol syntax"); return 1; }

    let hash: source.SymbolDefinition = find_top_level(result, "Hash");
    let key: source.SymbolDefinition = find_top_level(result, "Key");
    if (hash is null || hash.signature != "interface Hash with Equal") { print("FAIL: interface parent signature"); return 1; }
    if (key is null || key.signature != "interface Key with Hash, Display") { print("FAIL: multiple interface parents"); return 1; }

    let inherited: source.SymbolDefinition = workspace.definition("protocols.wl", 12, 18);
    if (inherited is null || inherited.name != "equals" || inherited.owner_type != "Equal") { print("FAIL: inherited protocol member"); return 1; }

    let tokens: Vector(Struct) = analysis.semantic_tokens(result, workspace, "protocols.wl");
    if (!has_token(tokens, 1, 23, "type") || !has_token(tokens, 12, 17, "method")) { print("FAIL: protocol semantic tokens"); return 1; }

    workspace.update("project/base.wl", 1, "interface Named {\n    func name() -> String;\n}\ninterface Tagged with Named {\n    func tag() -> String;\n}\n");
    let imported: source.FrontendResult = workspace.update("project/main.wl", 1, "import Tagged from \"base.wl\"\nfunc read(value: Tagged) -> String { return value.name(); }\n");
    let imported_member: source.SymbolDefinition = workspace.definition("project/main.wl", 1, 52);
    if (!imported.valid || imported_member is null || imported_member.name != "name" || imported_member.range.file != "project/base.wl") { print("FAIL: imported protocol member"); return 1; }

    print("PASS: protocol semantics");
    return 0;
}
