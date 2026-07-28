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

func encode_symbols(symbols -> Vector(Struct)) -> String {
    let result -> String = "[";
    let i -> Int = 0;
    while (i < symbols.length()) {
        let symbol -> source.DocumentSymbol = symbols[i];
        let span -> compiler.WhitelangExceptions.SourceRange = symbol.span;
        if (i > 0) { result += ","; }
        result +=
            "{\"name\":" + protocol.quote(symbol.name) +
            ",\"kind\":" + symbol_kind(symbol.kind) +
            ",\"range\":{\"start\":{\"line\":" + span.start.line +
            ",\"character\":" + span.start.utf16_column +
            "},\"end\":{\"line\":" + span.end.line +
            ",\"character\":" + span.end.utf16_column +
            "}},\"selectionRange\":{\"start\":{\"line\":" + span.start.line +
            ",\"character\":" + span.start.utf16_column +
            "},\"end\":{\"line\":" + span.end.line +
            ",\"character\":" + span.end.utf16_column +
            "}},\"children\":" + encode_symbols(symbol.children) + "}";
        i += 1;
    }
    return result + "]";
}
