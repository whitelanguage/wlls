// Test: MODULE_NAVIGATION
// File: tests/test_modules.wl
// Focus: Package entries, file modules, named imports, and qualified package members.

import "../internal/frontend/_pkg.wl" as source

func ends_in(definition: source.SymbolDefinition, suffix: String) -> Bool {
    return definition is !null && definition.range is !null && definition.range.file.ends_with(suffix);
}

func main() -> Int {
    let workspace: source.FrontendWorkspace = source.FrontendWorkspace();
    let text: String = "import \"builtin\"\n" +
        "import Equal from \"protocol\"\n" +
        "import \"dict\"\n" +
        "func probe() -> Byte { return builtin.string.string_at(\"x\", 0); }\n";
    let result: source.FrontendResult = workspace.update("module_nav.wl", 1, text);
    if (!result.valid) { print("FAIL: module source"); return 1; }

    let builtin_path: source.SymbolDefinition = workspace.definition("module_nav.wl", 0, 9);
    let protocol_path: source.SymbolDefinition = workspace.definition("module_nav.wl", 1, 20);
    let dict_path: source.SymbolDefinition = workspace.definition("module_nav.wl", 2, 9);
    if (!ends_in(builtin_path, "/std/builtin/_pkg.wl") || !ends_in(protocol_path, "/std/protocol/_pkg.wl") || !ends_in(dict_path, "/std/dict.wl")) { print("FAIL: import path navigation"); return 1; }

    let equal: source.SymbolDefinition = workspace.definition("module_nav.wl", 1, 8);
    if (!ends_in(equal, "/std/protocol/comparison.wl") || equal.name != "Equal") { print("FAIL: named import navigation"); return 1; }

    let package: source.SymbolDefinition = workspace.definition("module_nav.wl", 3, 31);
    let module: source.SymbolDefinition = workspace.definition("module_nav.wl", 3, 39);
    let member: source.SymbolDefinition = workspace.definition("module_nav.wl", 3, 46);
    if (!ends_in(package, "/std/builtin/_pkg.wl")) { print("FAIL: package navigation"); return 1; }
    if (!ends_in(module, "/std/builtin/_pkg.wl") || module.range.start.line != 0) { print("FAIL: package module navigation"); return 1; }
    if (!ends_in(member, "/std/builtin/string.wl") || member.name != "string_at") { print("FAIL: package member navigation"); return 1; }

    print("PASS: module navigation");
    return 0;
}
