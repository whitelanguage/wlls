// hover information for resolved symbols
import "../protocol/_pkg.wl" as protocol
import "../frontend/_pkg.wl" as source

func __hover_signature(definition: source.SymbolDefinition) -> String {
    if (definition is null) { return ""; }
    if (definition.signature.length() > 0) { return definition.signature; }
    if (definition.kind == source.SYMBOL_MODULE) { return "module " + definition.name; }
    if (definition.kind == source.SYMBOL_IMPORT) { return "import " + definition.name; }
    if (definition.type_name.length() > 0) { return definition.name + ": " + definition.type_name; }
    return definition.name;
}

func encode_hover(definition: source.SymbolDefinition) -> String {
    let signature: String = __hover_signature(definition);
    if (signature.length() == 0) { return "null"; }
    return "{\"contents\":{\"kind\":\"markdown\",\"value\":" + protocol.quote("```whitelang\n" + signature + "\n```") + "}}";
}
