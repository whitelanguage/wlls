// Test: NAMED_TYPE_DIAGNOSTICS
// File: tests/test_type_diagnostics.wl
// Focus: Diagnostics specific to named types, aliases, and conversion targets.

import "../internal/frontend/_pkg.wl" as source
import "../internal/compiler/_pkg.wl" as compiler

func has_error(text: String, category: String, message: String) -> Bool {
    let result: source.FrontendResult = source.check_source("types.wl", text);
    let i: Int = 0;
    while (i < result.diagnostics.length()) {
        let diagnostic: compiler.WhitelangExceptions.CompilerDiagnostic = result.diagnostics[i];
        if (diagnostic.category == category && diagnostic.message == message) { return true; }
        i += 1;
    }
    return false;
}

func main() -> Int {
    if (!has_error("type Code = UInt32;\ntype Code = UInt64;\n", "NameError", "Type 'Code' is already defined.")) { print("FAIL: duplicate named type"); return 1; }
    if (!has_error("type First = Second;\ntype Second = First;\n", "TypeError", "Type declaration for 'First' is recursive.")) { print("FAIL: recursive named type"); return 1; }
    if (!has_error("type Code = Missing;\n", "TypeError", "Unknown type: Missing")) { print("FAIL: unknown underlying type"); return 1; }
    if (!has_error("type Code = UInt32;\nlet code: Code = 1U;\n", "TypeError", "Type mismatch. Expected Code, got UInt32")) { print("FAIL: implicit named conversion"); return 1; }
    if (!has_error("type String as Text;\nclass Value {\n    type String { return \"one\"; }\n    type Text { return \"two\"; }\n}\n", "NameError", "class 'Value' already defines a conversion to String")) { print("FAIL: duplicate conversion target"); return 1; }
    print("PASS: named type diagnostics");
    return 0;
}
