// document symbol response encoding
import "../protocol/_pkg.wl" as protocol
import "../frontend/_pkg.wl" as source
import "../compiler/_pkg.wl" as compiler

func symbol_kind(kind -> Int) -> Int {
    if (kind == source.SYMBOL_FUNCTION) { return 12; }
    if (kind == source.SYMBOL_VARIABLE || kind == source.SYMBOL_PARAMETER) { return 13; }
    if (kind == source.SYMBOL_CONSTANT) { return 14; }
    if (kind == source.SYMBOL_STRUCT) { return 23; }
    if (kind == source.SYMBOL_CLASS) { return 5; }
    if (kind == source.SYMBOL_METHOD || kind == source.SYMBOL_CONVERSION) { return 6; }
    if (kind == source.SYMBOL_FIELD) { return 8; }
    if (kind == source.SYMBOL_ENUM || kind == source.SYMBOL_ERROR) { return 10; }
    if (kind == source.SYMBOL_ENUM_CASE || kind == source.SYMBOL_ERROR_CASE) { return 22; }
    if (kind == source.SYMBOL_INTERFACE) { return 11; }
    return 13;
}

func __write_symbols(output -> protocol.ByteBuffer, symbols -> Vector(Struct)) -> Bool {
    if (!output.write("[")) { return false; }
    let i -> Int = 0;
    while (i < symbols.length()) {
        let symbol -> source.DocumentSymbol = symbols[i];
        let span -> compiler.WhitelangExceptions.SourceRange = symbol.span;
        if (i > 0 && !output.write_byte(Byte(44))) { return false; }
        if (!output.write("{\"name\":") || !output.write(protocol.quote(symbol.name)) || !output.write(",\"kind\":") || !output.write_uint(symbol_kind(symbol.kind)) || !output.write(",\"range\":{\"start\":{\"line\":") || !output.write_uint(span.start.line) || !output.write(",\"character\":") || !output.write_uint(span.start.utf16_column) || !output.write("},\"end\":{\"line\":") || !output.write_uint(span.end.line) || !output.write(",\"character\":") || !output.write_uint(span.end.utf16_column) || !output.write("}},\"selectionRange\":{\"start\":{\"line\":") || !output.write_uint(span.start.line) || !output.write(",\"character\":") || !output.write_uint(span.start.utf16_column) || !output.write("},\"end\":{\"line\":") || !output.write_uint(span.end.line) || !output.write(",\"character\":") || !output.write_uint(span.end.utf16_column) || !output.write("}},\"children\":") || !__write_symbols(output, symbol.children) || !output.write("}")) { return false; }
        i += 1;
    }
    return output.write("]");
}

func encode_symbols(symbols -> Vector(Struct)) -> String {
    let output -> protocol.ByteBuffer = protocol.ByteBuffer(1024);
    if (!__write_symbols(output, symbols)) { return "[]"; }
    let result -> String = output.finish();
    if (result is null) { return "[]"; }
    return result;
}
