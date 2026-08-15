// Test: GENERIC_SEMANTICS
// File: tests/test_generics.wl
// Focus: Generic declarations, type parameters, constraints, explicit arguments, and member calls.

import "../internal/frontend/_pkg.wl" as source
import "../internal/analysis/_pkg.wl" as analysis

func count_kind(definitions: Vector(Struct), kind: Int) -> Int {
    let count: Int = 0;
    let i: Int = 0;
    while (i < definitions.length()) {
        let definition: source.SymbolDefinition = definitions[i];
        if (definition.kind == kind) { count += 1; }
        i += 1;
    }
    return count;
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
    let text: String = "interface Reader<T> {\n" + "    func read() -> T;\n" + "}\n" + "class Box<T> with Reader(T) {\n" + "    let value: T;\n" + "    init(value: T) { self.value = value; }\n" + "    func read() -> T { return self.value; }\n" + "    func choose<U>(value: U) -> U { return value; }\n" + "}\n" + "func identity<T: Reader(Int)>(value: T) -> T { return value; }\n" + "func main() -> Int {\n" + "    let box: Box(Int) = Box<Int>(1);\n" + "    let value: Int = box.read();\n" + "    let other: String = box.choose<String>(\"white\");\n" + "    return value;\n" + "}\n";
    let workspace: source.FrontendWorkspace = source.FrontendWorkspace();
    let result: source.FrontendResult = workspace.update("generic.wl", 1, text);
    if (!result.valid || result.semantics is null) { print("FAIL: generic source did not parse"); return 1; }
    if (count_kind(result.semantics.definitions, source.SYMBOL_TYPE_PARAMETER) != 4) { print("FAIL: generic type parameter definitions"); return 1; }
    let reader_symbol: source.DocumentSymbol = result.syntax.symbols[0];
    let identity_symbol: source.DocumentSymbol = result.syntax.symbols[2];
    if (reader_symbol.children.length() < 2 || identity_symbol.children.length() < 2) { print("FAIL: generic document symbol children"); return 1; }
    let reader_type_param: source.DocumentSymbol = reader_symbol.children[0];
    let reader_method: source.DocumentSymbol = reader_symbol.children[1];
    let identity_type_param: source.DocumentSymbol = identity_symbol.children[0];
    if (reader_type_param.kind != source.SYMBOL_TYPE_PARAMETER || reader_method.kind != source.SYMBOL_METHOD || identity_type_param.kind != source.SYMBOL_TYPE_PARAMETER) { print("FAIL: generic document symbols"); return 1; }

    let tokens: Vector(Struct) = analysis.semantic_tokens(result, workspace, "generic.wl");
    if (!has_token(tokens, 0, 17, "typeParameter") || !has_token(tokens, 1, 19, "typeParameter") || !has_token(tokens, 3, 10, "typeParameter")) { print("FAIL: generic type parameter tokens"); return 1; }
    if (!has_token(tokens, 12, 25, "method") || !has_token(tokens, 13, 28, "method")) { print("FAIL: generic member calls"); return 1; }

    workspace.update("project/generic_dep.wl", 1, "class Item<T> {\n    let value: T;\n    func get() -> T { return self.value; }\n}\nclass Child<T>(Item(T)) {}\n");
    let imported: source.FrontendResult = workspace.update("project/generic_main.wl", 1, "import Child from \"generic_dep.wl\"\nfunc run(item: Child(String)) -> String {\n    return item.get();\n}\n");
    let imported_tokens: Vector(Struct) = analysis.semantic_tokens(imported, workspace, "project/generic_main.wl");
    if (!imported.valid || !has_token(imported_tokens, 2, 16, "method")) { print("FAIL: imported generic member call"); return 1; }
    print("PASS: generic semantics");
    return 0;
}
