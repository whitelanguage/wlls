// structured compiler diagnostics for protocol clients
import "../protocol/_pkg.wl" as protocol
import "../compiler/_pkg.wl" as compiler

func diagnostic_severity(value -> Int) -> Int {
    if (value == compiler.WhitelangExceptions.DIAGNOSTIC_WARNING) { return 2; }
    if (value == compiler.WhitelangExceptions.DIAGNOSTIC_INFO) { return 3; }
    if (value == compiler.WhitelangExceptions.DIAGNOSTIC_HINT) { return 4; }
    return 1;
}

func encode_diagnostics(items -> Vector(Struct)) -> String {
    let result -> String = "[";
    let i -> Int = 0;
    while (i < items.length()) {
        let item -> compiler.WhitelangExceptions.CompilerDiagnostic = items[i];
        let range -> compiler.WhitelangExceptions.SourceRange = item.range;
        if (i > 0) { result += ","; }
        result +=
            "{\"severity\":" + diagnostic_severity(item.severity) +
            ",\"code\":" + protocol.quote(item.code) +
            ",\"source\":\"wlls\"" +
            ",\"message\":" + protocol.quote(item.message) +
            ",\"range\":{\"start\":{\"line\":" + range.start.line +
            ",\"character\":" + range.start.utf16_column +
            "},\"end\":{\"line\":" + range.end.line +
            ",\"character\":" + range.end.utf16_column + "}}}";
        i += 1;
    }
    return result + "]";
}
