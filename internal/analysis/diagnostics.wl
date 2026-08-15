// structured compiler diagnostics for protocol clients
import "../protocol/_pkg.wl" as protocol
import "../compiler/_pkg.wl" as compiler

func diagnostic_severity(value: Int) -> Int {
    if (value == compiler.WhitelangExceptions.DIAGNOSTIC_WARNING) { return 2; }
    if (value == compiler.WhitelangExceptions.DIAGNOSTIC_INFO) { return 3; }
    if (value == compiler.WhitelangExceptions.DIAGNOSTIC_HINT) { return 4; }
    return 1;
}

func encode_diagnostics(items: Vector(Struct)) -> String {
    let initial_capacity: Int = 16;
    if (items.length() <= (protocol.MAX_BUFFER_CAPACITY - 16) / 160) { initial_capacity = items.length() * 160 + 16; }
    let output: protocol.ByteBuffer = protocol.ByteBuffer(initial_capacity);
    if (!output.write("[")) { return "[]"; }
    let i: Int = 0;
    while (i < items.length()) {
        let item: compiler.WhitelangExceptions.CompilerDiagnostic = items[i];
        let range: compiler.WhitelangExceptions.SourceRange = item.range;
        if (i > 0 && !output.write_byte(Byte(44))) { return "[]"; }
        if (!output.write("{\"severity\":") || !output.write_uint(diagnostic_severity(item.severity)) || !output.write(",\"code\":") || !output.write(protocol.quote(item.code)) || !output.write(",\"source\":\"wlls\",\"message\":") || !output.write(protocol.quote(item.message)) || !output.write(",\"range\":{\"start\":{\"line\":") || !output.write_uint(range.start.line) || !output.write(",\"character\":") || !output.write_uint(range.start.utf16_column) || !output.write("},\"end\":{\"line\":") || !output.write_uint(range.end.line) || !output.write(",\"character\":") || !output.write_uint(range.end.utf16_column) || !output.write("}}}")) { return "[]"; }
        i += 1;
    }
    if (!output.write("]")) { return "[]"; }
    let result: String = output.finish();
    if (result is null) { return "[]"; }
    return result;
}
