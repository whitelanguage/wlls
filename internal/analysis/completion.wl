// completion items emitted by the language server
import Dict from "dict"
import "../protocol/_pkg.wl" as protocol
import "../frontend/_pkg.wl" as source

func __completion_kind(kind: Int) -> Int {
    if (kind == source.SYMBOL_METHOD || kind == source.SYMBOL_CONVERSION) { return 2; }
    if (kind == source.SYMBOL_FUNCTION) { return 3; }
    if (kind == source.SYMBOL_FIELD) { return 5; }
    if (kind == source.SYMBOL_VARIABLE || kind == source.SYMBOL_PARAMETER) { return 6; }
    if (kind == source.SYMBOL_CLASS) { return 7; }
    if (kind == source.SYMBOL_INTERFACE) { return 8; }
    if (kind == source.SYMBOL_MODULE) { return 9; }
    if (kind == source.SYMBOL_ENUM || kind == source.SYMBOL_ERROR) { return 13; }
    if (kind == source.SYMBOL_ENUM_CASE || kind == source.SYMBOL_ERROR_CASE) { return 20; }
    if (kind == source.SYMBOL_CONSTANT) { return 21; }
    if (kind == source.SYMBOL_STRUCT) { return 22; }
    if (kind == source.SYMBOL_TYPE_PARAMETER) { return 25; }
    return 6;
}

func __write_completion_item(output: protocol.ByteBuffer, first: Bool, label: String, kind: Int, insert_text: String, detail: String, snippet: Bool) -> Bool {
    if (!first && !output.write_byte(Byte(44))) { return false; }
    if (!output.write("{\"label\":") || !output.write(protocol.quote(label)) || !output.write(",\"kind\":") || !output.write_uint(kind)) { return false; }
    if (insert_text.length() > 0 && (!output.write(",\"insertText\":") || !output.write(protocol.quote(insert_text)))) { return false; }
    if (snippet && !output.write(",\"insertTextFormat\":2")) { return false; }
    if (detail.length() > 0 && (!output.write(",\"detail\":") || !output.write(protocol.quote(detail)))) { return false; }
    return output.write("}");
}

func __write_snippets(output: protocol.ByteBuffer, seen: Dict) -> Bool {
    let labels: Vector(String) = ["let", "let inferred", "let Auto", "const", "func", "func variadic", "func defaults", "func declaration", "init", "class", "interface", "struct", "Function type", "Method type"];
    let inserts: Vector(String) = [
        "let ${1:name}: ${2:Type} = ${3:value};",
        "let ${1:name} = ${2:value};",
        "let ${1:name}: Auto = ${2:value};",
        "const ${1:NAME} = ${2:value};",
        "func ${1:name}(${2}) -> ${3:Void} {\n    ${0}\n}",
        "func ${1:name}(${2:values}: ${3:Type}...) -> ${4:Void} {\n    ${0}\n}",
        "func ${1:name}(${2:value}: ${3:Type} = ${4:default}) -> ${5:Void} {\n    ${0}\n}",
        "func ${1:name}(${2}) -> ${3:Void};",
        "init(${1}) {\n    ${0}\n}",
        "class ${1:Name} {\n    ${0}\n}",
        "interface ${1:Name} {\n    func ${2:name}(${3}) -> ${4:Void};\n}",
        "struct ${1:Name}(${2:field}: ${3:Type})",
        "Function(${1:Args}) -> ${2:Return}",
        "Method(${1:Args}) -> ${2:Return}"
    ];
    let i: Int = 0;
    while (i < labels.length()) {
        if (!__write_completion_item(output, i == 0, labels[i], 15, inserts[i], "White Language snippet", true)) { return false; }
        seen.put(labels[i], true);
        i += 1;
    }
    return true;
}

func encode_completions(result: source.FrontendResult) -> String {
    let output: protocol.ByteBuffer = protocol.ByteBuffer(2048);
    if (!output.write("{\"isIncomplete\":false,\"items\":[")) { return "{\"isIncomplete\":false,\"items\":[]}"; }
    let seen: Dict = Dict(32);
    if (!__write_snippets(output, seen)) { return "{\"isIncomplete\":false,\"items\":[]}"; }

    if (result is !null && result.valid && result.semantics is !null) {
        let i: Int = 0;
        while (i < result.semantics.definitions.length()) {
            let definition: source.SymbolDefinition = result.semantics.definitions[i];
            if (definition.top_level && !seen.contains_key(definition.name)) {
                if (!__write_completion_item(output, false, definition.name, __completion_kind(definition.kind), definition.name, definition.signature, false)) { return "{\"isIncomplete\":false,\"items\":[]}"; }
                seen.put(definition.name, true);
            }
            i += 1;
        }
    }

    if (!output.write("]}")) { return "{\"isIncomplete\":false,\"items\":[]}"; }
    let encoded: String = output.finish();
    if (encoded is null) { return "{\"isIncomplete\":false,\"items\":[]}"; }
    return encoded;
}
