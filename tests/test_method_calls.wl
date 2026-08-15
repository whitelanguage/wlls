// Test: WLLS_METHOD_CALLS
// File: tests/test_method_calls.wl
// Focus: Semantic indexing of member calls on parameters and local variables.

import "../internal/frontend/_pkg.wl" as source
import "../internal/analysis/_pkg.wl" as analysis

func token_at(tokens: Vector(Struct), line: Int, character: Int) -> analysis.SemanticToken {
    let i: Int = 0;
    while (i < tokens.length()) {
        let token: analysis.SemanticToken = tokens[i];
        if (token.line == line && token.character == character) {
            return token;
        }
        i += 1;
    }
    return null;
}

func main() -> Int {
    let text: String =
        "class Value {\n" +
        "    func text() -> String {\n" +
        "        return \"ok\";\n" +
        "    }\n" +
        "    func checked() -> String? {\n" +
        "        return \"ok\";\n" +
        "    }\n" +
        "}\n" +
        "\n" +
        "func string(value: Value) -> String {\n" +
        "    let local: Value = value;\n" +
        "    let first: String = value.text();\n" +
        "    let second: String = local.text();\n" +
        "    let third: String = local.checked()?;\n" +
        "    catch(err) { return \"\"; }\n" +
        "    return first + second + third;\n" +
        "}\n" +
        "\n" +
        "class Output {\n" +
        "    func write() -> Void { return; }\n" +
        "}\n" +
        "class Compiler {\n" +
        "    let output_file: Output = null;\n" +
        "}\n" +
        "func emit(c: Compiler) -> Void {\n" +
        "    c.output_file.write();\n" +
        "}\n" +
        "class Leaf {\n" +
        "    func flush() -> Void { return; }\n" +
        "}\n" +
        "class Branch {\n" +
        "    let leaf: Leaf = null;\n" +
        "}\n" +
        "class Root {\n" +
        "    let branch: Branch = null;\n" +
        "}\n" +
        "func flush(root: Root) -> Void {\n" +
        "    root.branch.leaf.flush();\n" +
        "    if (root.branch.leaf is !null) { return; }\n" +
        "}\n" +
        "const LIMIT: Int = 1;\n" +
        "@Trace(LIMIT)\n" +
        "struct Item(value: Int) {\n" +
        "    this.value = 0;\n" +
        "}\n" +
        "class Base {\n" +
        "    func ping() -> Void { return; }\n" +
        "}\n" +
        "class Child(Base) {\n" +
        "    func inspect(items: Vector(Item)) -> Void {\n" +
        "        let local: Item = items[0];\n" +
        "        let copies: Vector(Item) = [local];\n" +
        "        if (items[0].value > 0) { super.ping(); }\n" +
        "    }\n" +
        "}\n";

    let workspace: source.FrontendWorkspace = source.FrontendWorkspace();
    let result: source.FrontendResult = workspace.update("memory.wl", 1, text);
    if (!result.valid) {
        print("FAIL: member call source did not parse");
        return 1;
    }

    let tokens: Vector(Struct) = analysis.semantic_tokens(result, workspace, "memory.wl");
    if (tokens.length() == 0) {
        print("FAIL: member calls produced no semantic tokens");
        return 1;
    }

    let parameter_call: analysis.SemanticToken = token_at(tokens, 11, 30);
    let local_call: analysis.SemanticToken = token_at(tokens, 12, 31);
    let fallible_call: analysis.SemanticToken = token_at(tokens, 13, 30);
    if (parameter_call is null ||
        local_call is null ||
        fallible_call is null ||
        parameter_call.token_type != "method" ||
        local_call.token_type != "method" ||
        fallible_call.token_type != "method") {
        print("FAIL: member calls were not classified as methods");
        return 1;
    }

    let chained_field: analysis.SemanticToken = token_at(tokens, 25, 6);
    let chained_call: analysis.SemanticToken = token_at(tokens, 25, 18);
    if (chained_field is null ||
        chained_call is null ||
        chained_field.token_type != "property" ||
        chained_call.token_type != "method") {
        print("FAIL: chained member call");
        return 1;
    }

    let deep_branch: analysis.SemanticToken = token_at(tokens, 37, 9);
    let deep_leaf: analysis.SemanticToken = token_at(tokens, 37, 16);
    let deep_call: analysis.SemanticToken = token_at(tokens, 37, 21);
    if (deep_branch is null ||
        deep_leaf is null ||
        deep_call is null ||
        deep_branch.token_type != "property" ||
        deep_leaf.token_type != "property" ||
        deep_call.token_type != "method") {
        print("FAIL: deep member chain");
        return 1;
    }

    let condition_branch: analysis.SemanticToken = token_at(tokens, 38, 13);
    let condition_leaf: analysis.SemanticToken = token_at(tokens, 38, 20);
    if (condition_branch is null || condition_leaf is null || condition_branch.token_type != "property" || condition_leaf.token_type != "property") {
        print("FAIL: member chain in is condition");
        return 1;
    }

    let annotation_arg: analysis.SemanticToken = token_at(tokens, 41, 7);
    let struct_field: analysis.SemanticToken = token_at(tokens, 43, 9);
    let vector_element: analysis.SemanticToken = token_at(tokens, 51, 36);
    let indexed_field: analysis.SemanticToken = token_at(tokens, 52, 21);
    let super_method: analysis.SemanticToken = token_at(tokens, 52, 40);
    if (annotation_arg is null || annotation_arg.token_type != "variable" || struct_field is null || struct_field.token_type != "property" || vector_element is null || vector_element.token_type != "variable" || indexed_field is null || indexed_field.token_type != "property" || super_method is null || super_method.token_type != "method") {
        print("FAIL: semantic expression coverage");
        return 1;
    }

    let external_path: String = "project/main.wl";
    let external: source.FrontendResult = workspace.update(
        external_path,
        1,
        "import Driver from \"driver.wl\"\n" +
        "func run(driver: Driver) -> Void {\n" +
        "    driver.output.write();\n" +
        "}\n"
    );
    workspace.update(
        "project/driver.wl",
        1,
        "import Sink from \"output.wl\"\n" +
        "class Driver {\n" +
        "    let output: Sink = null;\n" +
        "}\n"
    );
    workspace.update(
        "project/output.wl",
        1,
        "class Sink {\n" +
        "    func write() -> Void { return; }\n" +
        "}\n"
    );
    let external_tokens: Vector(Struct) =
        analysis.semantic_tokens(external, workspace, external_path);
    let external_field: analysis.SemanticToken =
        token_at(external_tokens, 2, 11);
    let external_call: analysis.SemanticToken =
        token_at(external_tokens, 2, 18);
    if (external_field is null ||
        external_call is null ||
        external_field.token_type != "property" ||
        external_call.token_type != "method") {
        print("FAIL: cross-document member call");
        return 1;
    }

    let inherited_path: String = "project/use.wl";
    let inherited: source.FrontendResult = workspace.update(inherited_path, 1, "import Child from \"child.wl\"\nfunc use(value: Child) -> Void {\n    value.ping();\n}\n");
    workspace.update("project/child.wl", 1, "import Base from \"base.wl\"\nclass Child(Base) {\n}\n");
    workspace.update("project/base.wl", 1, "class Base {\n    func ping() -> Void { return; }\n}\n");
    let inherited_tokens: Vector(Struct) = analysis.semantic_tokens(inherited, workspace, inherited_path);
    let inherited_call: analysis.SemanticToken = token_at(inherited_tokens, 2, 10);
    if (inherited_call is null || inherited_call.token_type != "method") {
        print("FAIL: inherited cross-document member call");
        return 1;
    }

    let compound_path: String = "project/compound.wl";
    let compound: source.FrontendResult = workspace.update(compound_path, 1, "import Box from \"box.wl\"\nfunc use_box(box: Box) -> Void {\n    box.items[0].flush();\n    box.make().flush();\n}\n");
    workspace.update("project/box.wl", 1, "import Item from \"item.wl\"\nclass Box {\n    let items: Vector(Item) = [];\n    func make() -> Item { return null; }\n}\n");
    workspace.update("project/item.wl", 1, "class Item {\n    func flush() -> Void { return; }\n}\n");
    if (workspace.resolve_member("project/box.wl", "Item", "flush") is null) {
        print("FAIL: imported member resolution context");
        return 1;
    }
    let compound_tokens: Vector(Struct) = analysis.semantic_tokens(compound, workspace, compound_path);
    let indexed_call: analysis.SemanticToken = token_at(compound_tokens, 2, 17);
    let returned_call: analysis.SemanticToken = token_at(compound_tokens, 3, 15);
    if (indexed_call is null || indexed_call.token_type != "method") {
        print("FAIL: late-bound indexed member chain");
        return 1;
    }
    if (returned_call is null || returned_call.token_type != "method") {
        print("FAIL: late-bound call result member chain");
        return 1;
    }

    workspace.remove("project/output.wl");
    let closed_tokens: Vector(Struct) = analysis.semantic_tokens(external, workspace, external_path);
    let closed_call: analysis.SemanticToken = token_at(closed_tokens, 2, 18);
    if (closed_call is null || closed_call.token_type != "variable") {
        print("FAIL: closed document member remained indexed");
        return 1;
    }

    let standard_path: String = "standard.wl";
    let standard: source.FrontendResult = workspace.update(standard_path, 1, "import \"file\"\nclass Compiler {\n    let output_file: file.File = null;\n}\nfunc emit(c: Compiler) -> Void {\n    c.output_file.write(\"x\")?;\n    catch(err) { return; }\n}\n");
    let standard_tokens: Vector(Struct) = analysis.semantic_tokens(standard, workspace, standard_path);
    let standard_field: analysis.SemanticToken = token_at(standard_tokens, 5, 6);
    let standard_method: analysis.SemanticToken = token_at(standard_tokens, 5, 18);
    if (standard_field is null || standard_method is null || standard_field.token_type != "property" || standard_method.token_type != "method") {
        print("FAIL: standard library member call");
        return 1;
    }

    let package_path: String = "packages.wl";
    let package_result: source.FrontendResult = workspace.update(package_path, 1, "import \"io\"\nimport \"json\"\nimport \"sys\"\nfunc inspect(value: json.Value) -> Void {\n    io.stderr.write_line(\"x\")?;\n    catch(err) { return; }\n    let field: json.Value = value.find(\"x\");\n    let path: String = sys.env.get_env(\"WL_PATH\");\n}\n");
    let package_tokens: Vector(Struct) = analysis.semantic_tokens(package_result, workspace, package_path);
    let io_module: analysis.SemanticToken = token_at(package_tokens, 4, 4);
    let stderr_module: analysis.SemanticToken = token_at(package_tokens, 4, 7);
    let io_write: analysis.SemanticToken = token_at(package_tokens, 4, 14);
    let json_find: analysis.SemanticToken = token_at(package_tokens, 6, 34);
    let env_get: analysis.SemanticToken = token_at(package_tokens, 7, 31);
    if (io_module is null || stderr_module is null || io_write is null || json_find is null || env_get is null || io_module.token_type != "namespace" || stderr_module.token_type != "namespace" || io_module.modifiers.length() != 1 || io_module.modifiers[0] != "defaultLibrary" || io_write.token_type != "function" || json_find.token_type != "method" || env_get.token_type != "function") {
        print("FAIL: standard library package members");
        return 1;
    }

    print("PASS: wlls member calls");
    return 0;
}
