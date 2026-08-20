// Test: NAMED_TYPE_TOOLING
// File: tests/test_named_types.wl
// Focus: Named types, transparent aliases, conversions, definitions, hover, and semantic tokens.

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

func has_token(tokens: Vector(Struct), line: Int, character: Int, token_type: String, declaration: Bool) -> Bool {
    let i: Int = 0;
    while (i < tokens.length()) {
        let token: analysis.SemanticToken = tokens[i];
        if (token.line == line && token.character == character && token.token_type == token_type) {
            if (!declaration) { return true; }
            let j: Int = 0;
            while (j < token.modifiers.length()) {
                if (token.modifiers[j] == "declaration") { return true; }
                j += 1;
            }
        }
        i += 1;
    }
    return false;
}

func main() -> Int {
    let text: String = "type UserID = UInt32;\n" +
        "type Vector(Int) as IntVector;\n" +
        "type Label = String;\n" +
        "class Value {\n" +
        "    type Label { return \"value\"; }\n" +
        "}\n" +
        "let id: UserID = UserID(1U);\n" +
        "let values: IntVector = [1, 2, 3];\n" +
        "let inferred = UserID(2U);\n";
    let workspace: source.FrontendWorkspace = source.FrontendWorkspace();
    let result: source.FrontendResult = workspace.update("named_types.wl", 1, text);
    if (!result.valid || result.semantics is null) { print("FAIL: named type syntax"); return 1; }

    let user_id: source.SymbolDefinition = find_top_level(result, "UserID");
    let int_vector: source.SymbolDefinition = find_top_level(result, "IntVector");
    let inferred: source.SymbolDefinition = find_top_level(result, "inferred");
    if (user_id is null || user_id.signature != "type UserID = UInt32" || user_id.transparent_alias) { print("FAIL: named type definition"); return 1; }
    if (int_vector is null || int_vector.signature != "type IntVector = Vector(Int) (alias)" || !int_vector.transparent_alias) { print("FAIL: transparent alias definition"); return 1; }
    if (inferred is null || inferred.type_name != "UserID") { print("FAIL: named type inference"); return 1; }
    if (analysis.encode_hover(user_id) != "{\"contents\":{\"kind\":\"markdown\",\"value\":\"```whitelang\\ntype UserID = UInt32\\n```\"}}") { print("FAIL: named type hover"); return 1; }
    if (analysis.encode_hover(int_vector) != "{\"contents\":{\"kind\":\"markdown\",\"value\":\"```whitelang\\ntype IntVector = Vector(Int) (alias)\\n```\"}}") { print("FAIL: alias hover"); return 1; }

    let id_type: source.SymbolDefinition = workspace.definition("named_types.wl", 6, 9);
    let alias_type: source.SymbolDefinition = workspace.definition("named_types.wl", 7, 13);
    let conversion_type: source.SymbolDefinition = workspace.definition("named_types.wl", 4, 9);
    if (id_type is null || id_type.range.start.line != 0 || alias_type is null || alias_type.range.start.line != 1) { print("FAIL: type definition navigation"); return 1; }
    if (conversion_type is null || conversion_type.name != "Label" || conversion_type.range.start.line != 2) { print("FAIL: conversion target navigation"); return 1; }
    let alias_result: source.FrontendResult = workspace.update("alias_target.wl", 1, "type Code = UInt32;\ntype Code as CodeAlias;\n");
    let alias_target: source.SymbolDefinition = workspace.definition("alias_target.wl", 1, 5);
    if (!alias_result.valid || alias_target is null || alias_target.name != "Code" || alias_target.range.start.line != 0) { print("FAIL: alias target navigation"); return 1; }

    let member_result: source.FrontendResult = workspace.update("alias_member.wl", 1, "class Box<T> { func value() -> Int { return 1; } }\ntype Box(Int) as IntBox;\nfunc read(box: IntBox) -> Int { return box.value(); }\n");
    let alias_member: source.SymbolDefinition = null;
    let reference_index: Int = 0;
    while (member_result.valid && reference_index < member_result.semantics.references.length()) {
        let reference: source.SymbolReference = member_result.semantics.references[reference_index];
        if (reference.name == "value" && reference.range.start.line == 2) { alias_member = workspace.definition("alias_member.wl", reference.range.start.line, reference.range.start.utf16_column); }
        reference_index += 1;
    }
    if (alias_member is null || alias_member.kind != source.SYMBOL_METHOD || alias_member.owner_type != "Box") { print("FAIL: alias member resolution"); return 1; }

    let tokens: Vector(Struct) = analysis.semantic_tokens(result, workspace, "named_types.wl");
    if (!has_token(tokens, 0, 5, "type", true) || !has_token(tokens, 1, 20, "type", true) || !has_token(tokens, 4, 9, "type", false) || !has_token(tokens, 6, 8, "type", false)) { print("FAIL: named type semantic tokens"); return 1; }

    let symbols: Vector(Struct) = result.syntax.symbols;
    if (symbols.length() < 3) { print("FAIL: named type document symbols"); return 1; }
    let first: source.DocumentSymbol = symbols[0];
    let second: source.DocumentSymbol = symbols[1];
    if (first.kind != source.SYMBOL_TYPE || first.name != "UserID" || second.kind != source.SYMBOL_TYPE || second.name != "IntVector") { print("FAIL: named type symbol kinds"); return 1; }

    print("PASS: named type tooling");
    return 0;
}
