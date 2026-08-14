// Test: FRONTEND_DIAGNOSTICS
// File: tests/test_diagnostics.wl
// Focus: Structured errors and parser recovery for in-memory source.

import "../internal/frontend/_pkg.wl" as source
import "../internal/compiler/_pkg.wl" as compiler

func main() -> Int {
    let result -> source.FrontendResult = source.check_source("memory.wl", "first;\nsecond;\nfunc main() -> Int { return 0; }\n");

    if (result.valid || result.diagnostics.length() != 2) {
        print("FAIL: parser diagnostic recovery");
        return 1;
    }

    let first -> compiler.WhitelangExceptions.CompilerDiagnostic = result.diagnostics[0];
    let second -> compiler.WhitelangExceptions.CompilerDiagnostic = result.diagnostics[1];
    if (first.code != "E1001" || first.range.start.line != 0 || first.range.start.utf16_column != 0 || second.code != "E1001" || second.range.start.line != 1 || second.range.start.utf16_column != 0) {
        print("FAIL: structured syntax diagnostics");
        return 1;
    }

    print("PASS: frontend diagnostics");
    return 0;
}
