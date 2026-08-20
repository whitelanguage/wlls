import Dict from "dict"
import * from "WhitelangFrontend.wl"
import * from "../../vendor/wlc-frontend/ast.wl"
import "../../vendor/wlc-frontend/tokens.wl" as WhitelangTokens
import Token from "../../vendor/wlc-frontend/tokens.wl"
import "../../vendor/wlc-frontend/diagnostics.wl" as WhitelangExceptions

class SymbolDefinition {
    let name: String;
    let kind: Int;
    let range: WhitelangExceptions.SourceRange;
    let type_name: String;
    let signature: String;
    let import_path: String;
    let import_name: String;
    let owner_type: String;
    let top_level: Bool;
    let underlying_type: String;
    let transparent_alias: Bool;

    init(name: String, kind: Int, range: WhitelangExceptions.SourceRange) {
        self.name = name;
        self.kind = kind;
        self.range = range;
        self.type_name = "";
        self.signature = "";
        self.import_path = "";
        self.import_name = "";
        self.owner_type = "";
        self.top_level = false;
        self.underlying_type = "";
        self.transparent_alias = false;
    }
}

class SymbolReference {
    let name: String;
    let range: WhitelangExceptions.SourceRange;
    let definition: SymbolDefinition;
    let qualifier: String;
    let owner_type: String;
    let receiver_index: Int;
    let receiver_steps: String;

    init(name: String, range: WhitelangExceptions.SourceRange, definition: SymbolDefinition) {
        self.name = name;
        self.range = range;
        self.definition = definition;
        self.qualifier = "";
        self.owner_type = "";
        self.receiver_index = -1;
        self.receiver_steps = "";
    }
}

struct __TypeSource(reference_index: Int, steps: String)

class SemanticDocument {
    let syntax: FrontendDocument;
    let definitions: Vector(Struct) = null;
    let references: Vector(Struct) = null;
    let members: Dict;
    let parent_types: Dict;
    let type_declarations: Dict;

    init(syntax: FrontendDocument) {
        self.syntax = syntax;
        self.definitions = [];
        self.references = [];
        self.members = Dict(32);
        self.parent_types = Dict(16);
        self.type_declarations = Dict(16);
    }
}

func __is_type_symbol(kind: Int) -> Bool {
    return kind == SYMBOL_STRUCT ||
           kind == SYMBOL_CLASS ||
           kind == SYMBOL_INTERFACE ||
           kind == SYMBOL_ENUM ||
           kind == SYMBOL_ERROR ||
           kind == SYMBOL_TYPE;
}

func __index_member_symbols(document: SemanticDocument) -> Void {
    let symbols: Vector(Struct) = document.syntax.symbols;
    let i: Int = 0;
    while (i < symbols.length()) {
        let owner: DocumentSymbol = symbols[i];
        if (__is_type_symbol(owner.kind)) {
            let j: Int = 0;
            while (j < owner.children.length()) {
                let member: DocumentSymbol = owner.children[j];
                let definition: SymbolDefinition = SymbolDefinition(member.name, member.kind, member.span);
                definition.owner_type = owner.name;
                document.members.put(owner.name + "." + member.name, definition);
                j += 1;
            }
        }
        i += 1;
    }
}

func __register_member(document: SemanticDocument, owner: String, definition: SymbolDefinition) -> Void {
    definition.owner_type = owner;
    document.members.put(owner + "." + definition.name, definition);
}

func __member_type(document: SemanticDocument, type_name: String) -> String {
    let current: String = type_name;
    let seen: Dict = Dict(8);
    while (current.length() > 0 && seen[current] is null) {
        seen.put(current, true);
        let declaration: SymbolDefinition = document.type_declarations[current];
        if (declaration is null || declaration.underlying_type.length() == 0) { break; }
        current = declaration.underlying_type;
    }
    return current;
}

func __builtin_type_name(name: String) -> Bool {
    return name == "Int" || name == "Int32" || name == "Long" || name == "Int64" || name == "Float" || name == "Float64" || name == "Byte" || name == "UInt8" || name == "Int8" || name == "Int16" || name == "Int128" || name == "UInt16" || name == "UInt32" || name == "UInt64" || name == "UInt128" || name == "Float32" || name == "IntSize" || name == "UIntSize" || name == "Bool" || name == "Char" || name == "AnyPtr" || name == "String" || name == "Void" || name == "Auto" || name == "Struct" || name == "Class" || name == "Function" || name == "Method" || name == "Enum" || name == "Vector" || name == "Array" || name == "Dict" || name == "Error";
}

func __canonical_type(document: SemanticDocument, type_name: String) -> String {
    let current: String = type_name;
    if (current.ends_with("?")) { current = current.slice(0, current.length() - 1); }
    let seen: Dict = Dict(8);
    while (current.length() > 0 && seen[current] is null) {
        seen.put(current, true);
        let declaration: SymbolDefinition = document.type_declarations[current];
        if (declaration is null || !declaration.transparent_alias || declaration.underlying_type.length() == 0) { break; }
        current = declaration.underlying_type;
        if (current.ends_with("?")) { current = current.slice(0, current.length() - 1); }
    }
    return current;
}

func __find_member(document: SemanticDocument, owner: String, name: String) -> SymbolDefinition {
    if (owner is null || owner.length() == 0) { return null; }
    let pending: Vector(String) = [owner];
    let seen: Dict = Dict(8);
    let index: Int = 0;
    while (index < pending.length()) {
        let current: String = pending[index];
        index += 1;
        while (current.starts_with("ptr ")) { current = current.slice(4, current.length()); }
        if (current.ends_with("?")) { current = current.slice(0, current.length() - 1); }
        let generic_start: Int = 0;
        while (generic_start < current.length() && current[generic_start] != '(') { generic_start += 1; }
        if (generic_start < current.length()) { current = current.slice(0, generic_start); }
        current = __member_type(document, current);
        while (current.starts_with("ptr ")) { current = current.slice(4, current.length()); }
        if (current.ends_with("?")) { current = current.slice(0, current.length() - 1); }
        generic_start = 0;
        while (generic_start < current.length() && current[generic_start] != '(') { generic_start += 1; }
        if (generic_start < current.length()) { current = current.slice(0, generic_start); }
        if (current.length() == 0 || seen[current] is !null) { continue; }
        seen.put(current, true);
        let member: SymbolDefinition = document.members[current + "." + name];
        if (member is !null) { return member; }
        let parents: Vector(String) = document.parent_types[current];
        let i: Int = 0;
        while (parents is !null && i < parents.length()) { pending.append(parents[i]); i += 1; }
    }
    return null;
}

class __Scope {
    let parent: __Scope;
    let symbols: Dict;

    init(parent: __Scope) {
        self.parent = parent;
        self.symbols = Dict(16);
    }

    func define(definition: SymbolDefinition) -> Void {
        self.symbols.put(definition.name, definition);
    }

    func find(name: String) -> SymbolDefinition {
        let current: __Scope = self;
        while (current is !null) {
            let definition: SymbolDefinition = current.symbols[name];
            if (definition is !null) { return definition; }
            current = current.parent;
        }
        return null;
    }
}

func __definition(document: SemanticDocument, scope: __Scope, token: Token, kind: Int) -> SymbolDefinition {
    let definition: SymbolDefinition = SymbolDefinition(token.value, kind, token_span(document.syntax.path, document.syntax.source_map, token));
    document.definitions.append(definition);
    scope.define(definition);
    return definition;
}

func type_text(node: Struct) -> String {
    if (node is null) { return "Void"; }
    let base: Int = node_kind(node);
    if (base == NODE_VAR_ACCESS) {
        let access: VarAccessNode = node;
        return access.name_tok.value;
    }
    if (base == NODE_FIELD_ACCESS) {
        let access: FieldAccessNode = node;
        return access.field_name;
    }
    if (base == NODE_GENERIC_TYPE) {
        let generic: GenericTypeNode = node;
        let result: String = type_text(generic.base_type) + "(";
        let i: Int = 0;
        while (generic.type_args is !null && i < generic.type_args.length()) {
            if (i > 0) { result += ", "; }
            result += type_text(generic.type_args[i]);
            i += 1;
        }
        return result + ")";
    }
    if (base == NODE_PTR_TYPE) {
        let pointer: PointerTypeNode = node;
        let result: String = type_text(pointer.base_type);
        let i: Int = 0;
        while (i < pointer.level) {
            result = "ptr " + result;
            i += 1;
        }
        return result;
    }
    if (base == NODE_VECTOR_TYPE) {
        let vector: VectorTypeNode = node;
        return "Vector(" + type_text(vector.element_type) + ")";
    }
    if (base == NODE_ARRAY_TYPE) {
        let array: ArrayTypeNode = node;
        return "Array(" + type_text(array.base_type) + ", " + array.size_tok.value + ")";
    }
    if (base == NODE_SLICE_TYPE) {
        let slice: SliceTypeNode = node;
        return "Array(" + type_text(slice.element_type) + ")";
    }
    if (base == NODE_FALLIBLE_TYPE) {
        let fallible: FallibleTypeNode = node;
        return type_text(fallible.base_type) + "?";
    }
    if (base == NODE_FUNCTION_TYPE) {
        let callable: FunctionTypeNode = node;
        let result: String = "Function(";
        let i: Int = 0;
        while (callable.arg_types is !null && i < callable.arg_types.length()) {
            if (i > 0) { result += ", "; }
            if (callable.arg_names is !null && callable.arg_names[i].length() > 0) { result += callable.arg_names[i] + ": "; }
            result += type_text(callable.arg_types[i]);
            if (callable.variadic_param == i + 1) { result += "..."; }
            i += 1;
        }
        return result + ") -> " + type_text(callable.return_type);
    }
    if (base == NODE_METHOD_TYPE) {
        let callable: MethodTypeNode = node;
        let result: String = "Method(";
        let i: Int = 0;
        while (callable.arg_types is !null && i < callable.arg_types.length()) {
            if (i > 0) { result += ", "; }
            if (callable.arg_names is !null && callable.arg_names[i].length() > 0) { result += callable.arg_names[i] + ": "; }
            result += type_text(callable.arg_types[i]);
            if (callable.variadic_param == i + 1) { result += "..."; }
            i += 1;
        }
        return result + ") -> " + type_text(callable.return_type);
    }
    return "";
}

func __type_params_text(params: Vector(Struct)) -> String {
    if (params is null || params.length() == 0) { return ""; }
    let result: String = "<";
    let i: Int = 0;
    while (i < params.length()) {
        let param: GenericParamNode = params[i];
        if (i > 0) { result += ", "; }
        result += param.name_tok.value;
        if (param.constraints is !null && param.constraints.length() > 0) {
            result += ": ";
            let j: Int = 0;
            while (j < param.constraints.length()) {
                if (j > 0) { result += " + "; }
                result += type_text(param.constraints[j]);
                j += 1;
            }
        }
        i += 1;
    }
    return result + ">";
}

func __quote_default_string(value: String) -> String {
    let result: String = "\"";
    let i: Int = 0;
    while (i < value.length()) {
        let ch: Char = value[i];
        if (ch == '"') { result += "\\\""; }
        else if (ch == '\\') { result += "\\\\"; }
        else if (ch == '\n') { result += "\\n"; }
        else if (ch == '\r') { result += "\\r"; }
        else if (ch == '\t') { result += "\\t"; }
        else { result += value.slice(i, i + 1); }
        i += 1;
    }
    return result + "\"";
}

func __default_value_text(node: Struct) -> String {
    if (node is null) { return ""; }
    let base: Int = node_kind(node);
    if (base == NODE_INT) { let value: IntNode = node; return value.tok.value; }
    if (base == NODE_FLOAT) { let value: FloatNode = node; return value.tok.value; }
    if (base == NODE_STRING) { let value: StringNode = node; return __quote_default_string(value.tok.value); }
    if (base == NODE_CHAR) { let value: CharNode = node; return "Char(" + value.tok.value + ")"; }
    if (base == NODE_BOOL) { let value: BooleanNode = node; if (value.value == 1) { return "true"; } return "false"; }
    if (base == NODE_NULL) { return "null"; }
    if (base == NODE_NULLPTR) { return "nullptr"; }
    if (base == NODE_UNARYOP) { let value: UnaryOpNode = node; return value.op_tok.value + __default_value_text(value.node); }
    if (base == NODE_BINOP) { let value: BinOpNode = node; return "(" + __default_value_text(value.left) + " " + value.op_tok.value + " " + __default_value_text(value.right) + ")"; }
    return "<expression>";
}

func __params_text(params: Vector(Struct)) -> String {
    let result: String = "(";
    let i: Int = 0;
    while (params is !null && i < params.length()) {
        let param: ParamNode = params[i];
        if (i > 0) { result += ", "; }
        result += param.name_tok.value + ": " + type_text(param.type_tok);
        if (param.is_variadic) { result += "..."; }
        if (param.default_val is !null) { result += " = " + __default_value_text(param.default_val); }
        i += 1;
    }
    return result + ")";
}

func __callable_signature(prefix: String, name: String, type_params: Vector(Struct), params: Vector(Struct), return_type: Struct) -> String {
    return prefix + name + __type_params_text(type_params) + __params_text(params) + " -> " + type_text(return_type);
}

func __type_list_text(types: Vector(Struct)) -> String {
    let result: String = "";
    let i: Int = 0;
    while (types is !null && i < types.length()) {
        if (i > 0) { result += ", "; }
        result += type_text(types[i]);
        i += 1;
    }
    return result;
}

func __type_names(types: Vector(Struct)) -> Vector(String) {
    let result: Vector(String) = [];
    let i: Int = 0;
    while (types is !null && i < types.length()) {
        result.append(type_text(types[i]));
        i += 1;
    }
    return result;
}

func __element_type(type_name: String) -> String {
    if (type_name is null || type_name.length() == 0) { return ""; }
    if (type_name == "String") { return "Byte"; }
    if (type_name.starts_with("ptr ")) { return type_name.slice(4, type_name.length()); }
    let start: Int = 0;
    if (type_name.starts_with("Vector(")) { start = 7; }
    else if (type_name.starts_with("Array(")) { start = 6; }
    else { return ""; }
    let depth: Int = 0;
    let i: Int = start;
    while (i < type_name.length()) {
        let ch: Char = type_name[i];
        if (ch == '(') { depth += 1; }
        else if (ch == ')') {
            if (depth == 0) { return type_name.slice(start, i); }
            depth -= 1;
        } else if (ch == ',' && depth == 0) {
            return type_name.slice(start, i);
        }
        i += 1;
    }
    return "";
}

func __expression_type(document: SemanticDocument, scope: __Scope, node: Struct) -> String {
    if (node is null) { return ""; }
    let base: Int = node_kind(node);
    if (base == NODE_INT) {
        let value: IntNode = node;
        if (value.tok.value.ends_with("ULL") || value.tok.value.ends_with("ull")) { return "UInt128"; }
        if (value.tok.value.ends_with("LL") || value.tok.value.ends_with("ll")) { return "Int128"; }
        if (value.tok.value.ends_with("UL") || value.tok.value.ends_with("ul")) { return "UInt64"; }
        if (value.tok.value.ends_with("U") || value.tok.value.ends_with("u")) { return "UInt32"; }
        if (value.tok.value.ends_with("L") || value.tok.value.ends_with("l")) {
            return "Long";
        }
        return "Int";
    }
    if (base == NODE_FLOAT) { let value: FloatNode = node; if (value.tok.value.ends_with("f") || value.tok.value.ends_with("F")) { return "Float32"; } return "Float"; }
    if (base == NODE_BOOL) { return "Bool"; }
    if (base == NODE_STRING) { return "String"; }
    if (base == NODE_CHAR) { return "Char"; }
    if (base == NODE_NULL) { return "Null"; }
    if (base == NODE_NULLPTR) { return "AnyPtr"; }
    if (base == NODE_VAR_ACCESS) {
        let access: VarAccessNode = node;
        let definition: SymbolDefinition = scope.find(access.name_tok.value);
        if (definition is !null) { return definition.type_name; }
        return access.name_tok.value;
    }
    if (base == NODE_GENERIC_TYPE) {
        let generic: GenericTypeNode = node;
        return __expression_type(document, scope, generic.base_type);
    }
    if (base == NODE_FIELD_ACCESS) {
        let access: FieldAccessNode = node;
        let owner_type: String = __expression_type(document, scope, access.obj);
        let member: SymbolDefinition = __find_member(document, owner_type, access.field_name);
        if (member is !null) { return member.type_name; }
        return "";
    }
    if (base == NODE_BINOP || base == NODE_IS || base == NODE_IS_NOT) {
        let binary: BinOpNode = node;
        if (base == NODE_IS || base == NODE_IS_NOT) { return "Bool"; }
        let op: Int = binary.op_tok.type;
        if (op == WhitelangTokens.TOK_EE || op == WhitelangTokens.TOK_NE || op == WhitelangTokens.TOK_GT || op == WhitelangTokens.TOK_LT || op == WhitelangTokens.TOK_GTE || op == WhitelangTokens.TOK_LTE || op == WhitelangTokens.TOK_AND || op == WhitelangTokens.TOK_OR || op == WhitelangTokens.TOK_IS) {
            return "Bool";
        }
        let left: String = __expression_type(document, scope, binary.left);
        let right: String = __expression_type(document, scope, binary.right);
        if (left == "String" || right == "String") { return "String"; }
        if (left == "Float" || right == "Float") { return "Float"; }
        if (left == "Long" || right == "Long") { return "Long"; }
        return left;
    }
    if (base == NODE_UNARYOP) {
        let unary: UnaryOpNode = node;
        if (unary.op_tok.type == WhitelangTokens.TOK_NOT) { return "Bool"; }
        return __expression_type(document, scope, unary.node);
    }
    if (base == NODE_CALL) {
        let call: CallNode = node;
        return __expression_type(document, scope, call.callee);
    }
    if (base == NODE_POSTFIX) {
        let postfix: PostfixOpNode = node;
        return __expression_type(document, scope, postfix.node);
    }
    if (base == NODE_VECTOR_LIT) {
        let vector: VectorLitNode = node;
        if (vector.elements is null || vector.elements.length() == 0) { return "Vector"; }
        let first: ArgNode = vector.elements[0];
        return "Vector(" + __expression_type(document, scope, first.val) + ")";
    }
    if (base == NODE_MAP_LIT) { return "Dict"; }
    if (base == NODE_INDEX_ACCESS) {
        let access: IndexAccessNode = node;
        return __element_type(__expression_type(document, scope, access.target));
    }
    if (base == NODE_SLICE_ACCESS) {
        let slice: SliceAccessNode = node;
        let target_type: String = __expression_type(document, scope, slice.target);
        if (target_type == "String") { return "String"; }
        let element_type: String = __element_type(target_type);
        if (element_type.length() > 0) { return "Array(" + element_type + ")"; }
        return target_type;
    }
    if (base == NODE_DEREF) {
        let dereference: DerefNode = node;
        let result: String = __expression_type(document, scope, dereference.node);
        let i: Int = 0;
        while (i < dereference.level && result.starts_with("ptr ")) {
            result = result.slice(4, result.length());
            i += 1;
        }
        return result;
    }
    if (base == NODE_TRY_UNWRAP) {
        let unwrap: TryUnwrapNode = node;
        let wrapped: String = __expression_type(document, scope, unwrap.expr);
        if (wrapped.ends_with("?")) {
            return wrapped.slice(0, wrapped.length() - 1);
        }
        return wrapped;
    }
    if (base == NODE_SUPER) {
        let definition: SymbolDefinition = scope.find("$super");
        if (definition is !null) { return definition.type_name; }
        return "";
    }
    if (base == NODE_REF) { return "AnyPtr"; }
    return "";
}

func __validate_named_initializer(document: SemanticDocument, scope: __Scope, declaration: VarDeclareNode) -> Void {
    let expected: String = type_text(declaration.type_node);
    let named: SymbolDefinition = document.type_declarations[expected];
    if (named is null || named.transparent_alias || declaration.value is null) { return; }
    let actual: String = __expression_type(document, scope, declaration.value);
    if (actual.length() == 0 || actual == expected) { return; }
    if (__canonical_type(document, named.underlying_type) == __canonical_type(document, actual)) { WhitelangExceptions.throw_type_error(declaration.pos, "Type mismatch. Expected " + expected + ", got " + actual); }
}

func __reference(document: SemanticDocument, scope: __Scope, token: Token) -> SymbolReference {
    let definition: SymbolDefinition = scope.find(token.value);
    let reference: SymbolReference = SymbolReference(token.value, token_span(document.syntax.path, document.syntax.source_map, token), null);
    reference.definition = definition;
    document.references.append(reference);
    return reference;
}

func __record_reference(document: SemanticDocument, scope: __Scope, token: Token) -> Void {
    let definition: SymbolDefinition = scope.find(token.value);
    let reference: SymbolReference = SymbolReference(token.value, token_span(document.syntax.path, document.syntax.source_map, token), null);
    reference.definition = definition;
    document.references.append(reference);
}

func __field_token(access: FieldAccessNode) -> Token {
    return Token(type=WhitelangTokens.TOK_IDENTIFIER, value=access.field_name, line=access.pos.ln, col=access.pos.col);
}

func __field_assign_token(document: SemanticDocument, assignment: FieldAssignNode) -> Token {
    let line_start: Int = document.syntax.source_map.line_start(assignment.pos.ln);
    let cursor: Int = line_start + assignment.pos.col - 1;
    while (cursor >= line_start && (document.syntax.source[cursor] == ' ' || document.syntax.source[cursor] == '\t')) {
        cursor -= 1;
    }
    let column: Int = cursor - line_start - assignment.field_name.length() + 1;
    if (column < 0) { column = assignment.pos.col; }
    return Token(type=WhitelangTokens.TOK_IDENTIFIER, value=assignment.field_name, line=assignment.pos.ln, col=column);
}

func __reference_index_for_token(document: SemanticDocument, token: Token) -> Int {
    let i: Int = document.references.length() - 1;
    while (i >= 0) {
        let reference: SymbolReference = document.references[i];
        if (reference.name == token.value && reference.range.start.line == token.line && reference.range.start.byte_column == token.col) { return i; }
        i -= 1;
    }
    return -1;
}

func __type_source(document: SemanticDocument, node: Struct) -> __TypeSource {
    if (node is null) { return __TypeSource(-1, ""); }
    let base: Int = node_kind(node);
    if (base == NODE_VAR_ACCESS) {
        let access: VarAccessNode = node;
        return __TypeSource(__reference_index_for_token(document, access.name_tok), "");
    }
    if (base == NODE_FIELD_ACCESS) {
        let access: FieldAccessNode = node;
        return __TypeSource(__reference_index_for_token(document, __field_token(access)), "");
    }
    if (base == NODE_CALL) {
        let call: CallNode = node;
        return __type_source(document, call.callee);
    }
    if (base == NODE_TRY_UNWRAP) {
        let unwrap: TryUnwrapNode = node;
        return __type_source(document, unwrap.expr);
    }
    if (base == NODE_POSTFIX) {
        let postfix: PostfixOpNode = node;
        return __type_source(document, postfix.node);
    }
    if (base == NODE_INDEX_ACCESS) {
        let access: IndexAccessNode = node;
        let source: __TypeSource = __type_source(document, access.target);
        source.steps += "index;";
        return source;
    }
    if (base == NODE_SLICE_ACCESS) {
        let slice: SliceAccessNode = node;
        let source: __TypeSource = __type_source(document, slice.target);
        source.steps += "slice;";
        return source;
    }
    if (base == NODE_DEREF) {
        let dereference: DerefNode = node;
        let source: __TypeSource = __type_source(document, dereference.node);
        let i: Int = 0;
        while (i < dereference.level) {
            source.steps += "deref;";
            i += 1;
        }
        return source;
    }
    return __TypeSource(-1, "");
}

func __walk_type(document: SemanticDocument, scope: __Scope, node: Struct) -> Void {
    if (node is null) { return; }
    let base: Int = node_kind(node);
    if (base == NODE_VAR_ACCESS) {
        let access: VarAccessNode = node;
        if (access.name_tok.type == WhitelangTokens.TOK_IDENTIFIER || access.name_tok.type == WhitelangTokens.TOK_TYPE) {
            __record_reference(document, scope, access.name_tok);
        }
    } else if (base == NODE_GENERIC_TYPE) {
        let generic: GenericTypeNode = node;
        __walk_type(document, scope, generic.base_type);
        let i: Int = 0;
        while (generic.type_args is !null && i < generic.type_args.length()) {
            __walk_type(document, scope, generic.type_args[i]);
            i += 1;
        }
    } else if (base == NODE_FIELD_ACCESS) {
        let access: FieldAccessNode = node;
        __walk_type(document, scope, access.obj);
        let field_reference: SymbolReference = __reference(document, scope, __field_token(access));
        field_reference.owner_type = __expression_type(document, scope, access.obj);
        field_reference.definition = __find_member(document, field_reference.owner_type, access.field_name);
        let object_base: Int = node_kind(access.obj);
        if (object_base == NODE_VAR_ACCESS) {
            let object: VarAccessNode = access.obj;
            field_reference.qualifier = object.name_tok.value;
        }
    } else if (base == NODE_PTR_TYPE) {
        let pointer: PointerTypeNode = node;
        __walk_type(document, scope, pointer.base_type);
    } else if (base == NODE_VECTOR_TYPE) {
        let vector: VectorTypeNode = node;
        __walk_type(document, scope, vector.element_type);
    } else if (base == NODE_ARRAY_TYPE) {
        let array: ArrayTypeNode = node;
        __walk_type(document, scope, array.base_type);
    } else if (base == NODE_SLICE_TYPE) {
        let slice: SliceTypeNode = node;
        __walk_type(document, scope, slice.element_type);
    } else if (base == NODE_FALLIBLE_TYPE) {
        let fallible: FallibleTypeNode = node;
        __walk_type(document, scope, fallible.base_type);
    } else if (base == NODE_FUNCTION_TYPE) {
        let function_type: FunctionTypeNode = node;
        let i: Int = 0;
        let count: Int = 0;
        if (function_type.arg_types is !null) {
            count = function_type.arg_types.length();
        }
        while (i < count) {
            __walk_type(document, scope, function_type.arg_types[i]);
            i += 1;
        }
        __walk_type(document, scope, function_type.return_type);
    } else if (base == NODE_METHOD_TYPE) {
        let method_type: MethodTypeNode = node;
        let i: Int = 0;
        let count: Int = 0;
        if (method_type.arg_types is !null) {
            count = method_type.arg_types.length();
        }
        while (i < count) {
            __walk_type(document, scope, method_type.arg_types[i]);
            i += 1;
        }
        __walk_type(document, scope, method_type.return_type);
    }
}

func __walk_annotations(document: SemanticDocument, scope: __Scope, annotations: Vector(Struct)) -> Void {
    if (annotations is null) { return; }
    let i: Int = 0;
    while (i < annotations.length()) {
        let annotation: AnnotationNode = annotations[i];
        let j: Int = 0;
        if (annotation.args is !null) {
            while (j < annotation.args.length()) {
                let arg: ArgNode = annotation.args[j];
                __walk_node(document, scope, arg.val);
                j += 1;
            }
        }
        i += 1;
    }
}

func __walk_node(document: SemanticDocument, scope: __Scope, node: Struct) -> Void {
    if (node is null) { return; }
    let base: Int = node_kind(node);

    if (base == NODE_BLOCK) {
        let block: BlockNode = node;
        let block_scope: __Scope = __Scope(scope);
        let i: Int = 0;
        let count: Int = 0;
        if (block.stmts is !null) { count = block.stmts.length(); }
        while (i < count) {
            __walk_node(document, block_scope, block.stmts[i]);
            i += 1;
        }
    } else if (base == NODE_VAR_DECL) {
        let declaration: VarDeclareNode = node;
        __walk_annotations(document, scope, declaration.annotations);
        __walk_type(document, scope, declaration.type_node);
        __walk_node(document, scope, declaration.value);
        __validate_named_initializer(document, scope, declaration);
        let kind: Int = SYMBOL_VARIABLE;
        if (declaration.is_const) { kind = SYMBOL_CONSTANT; }
        let definition: SymbolDefinition = __definition(document, scope, declaration.name_tok, kind);
        definition.type_name = type_text(declaration.type_node);
        if (definition.type_name == "Auto") {
            definition.type_name = __expression_type(document, scope, declaration.value);
        }
        let declaration_kind: String = "let ";
        if (declaration.is_const) { declaration_kind = "const "; }
        definition.signature = declaration_kind + definition.name + ": " + definition.type_name;
    } else if (base == NODE_VAR_ACCESS) {
        let access: VarAccessNode = node;
        __record_reference(document, scope, access.name_tok);
    } else if (base == NODE_VAR_ASSIGN) {
        let assignment: VarAssignNode = node;
        __record_reference(document, scope, assignment.name_tok);
        __walk_node(document, scope, assignment.value);
    } else if (base == NODE_BINOP || base == NODE_IS || base == NODE_IS_NOT) {
        let binary: BinOpNode = node;
        __walk_node(document, scope, binary.left);
        __walk_node(document, scope, binary.right);
    } else if (base == NODE_UNARYOP) {
        let unary: UnaryOpNode = node;
        __walk_node(document, scope, unary.node);
    } else if (base == NODE_POSTFIX) {
        let postfix: PostfixOpNode = node;
        __walk_node(document, scope, postfix.node);
    } else if (base == NODE_IF) {
        let conditional: IfNode = node;
        __walk_node(document, scope, conditional.condition);
        __walk_node(document, scope, conditional.body);
        __walk_node(document, scope, conditional.else_body);
    } else if (base == NODE_WHILE) {
        let loop: WhileNode = node;
        __walk_node(document, scope, loop.condition);
        __walk_node(document, scope, loop.body);
    } else if (base == NODE_FOR) {
        let loop: ForNode = node;
        let loop_scope: __Scope = __Scope(scope);
        __walk_node(document, loop_scope, loop.init);
        __walk_node(document, loop_scope, loop.cond);
        __walk_node(document, loop_scope, loop.step);
        __walk_node(document, loop_scope, loop.body);
    } else if (base == NODE_CALL) {
        let call: CallNode = node;
        __walk_node(document, scope, call.callee);
        let i: Int = 0;
        let count: Int = 0;
        if (call.args is !null) { count = call.args.length(); }
        while (i < count) {
            let arg: ArgNode = call.args[i];
            __walk_node(document, scope, arg.val);
            i += 1;
        }
    } else if (base == NODE_GENERIC_TYPE) {
        __walk_type(document, scope, node);
    } else if (base == NODE_RETURN) {
        let return_node: ReturnNode = node;
        __walk_node(document, scope, return_node.value);
    } else if (base == NODE_FIELD_ACCESS) {
        let access: FieldAccessNode = node;
        __walk_node(document, scope, access.obj);
        let object_base: Int = node_kind(access.obj);
        let type_source: __TypeSource = __type_source(document, access.obj);
        let owner_type: String = __expression_type(document, scope, access.obj);
        let field_reference: SymbolReference = __reference(document, scope, __field_token(access));
        field_reference.owner_type = owner_type;
        field_reference.receiver_index = type_source.reference_index;
        field_reference.receiver_steps = type_source.steps;
        field_reference.definition = __find_member(document, owner_type, access.field_name);
        if (object_base == NODE_VAR_ACCESS) {
            let object: VarAccessNode = access.obj;
            field_reference.qualifier = object.name_tok.value;
        }
    } else if (base == NODE_FIELD_ASSIGN) {
        let assignment: FieldAssignNode = node;
        __walk_node(document, scope, assignment.obj);
        let object_base: Int = node_kind(assignment.obj);
        let type_source: __TypeSource = __type_source(document, assignment.obj);
        let owner_type: String = __expression_type(document, scope, assignment.obj);
        let field_token: Token = __field_assign_token(document, assignment);
        let field_reference: SymbolReference = __reference(document, scope, field_token);
        field_reference.owner_type = owner_type;
        field_reference.receiver_index = type_source.reference_index;
        field_reference.receiver_steps = type_source.steps;
        field_reference.definition = __find_member(document, owner_type, assignment.field_name);
        if (object_base == NODE_VAR_ACCESS) {
            let object: VarAccessNode = assignment.obj;
            field_reference.qualifier = object.name_tok.value;
        }
        __walk_node(document, scope, assignment.value);
    } else if (base == NODE_REF) {
        let reference: RefNode = node;
        __walk_node(document, scope, reference.node);
    } else if (base == NODE_DEREF) {
        let dereference: DerefNode = node;
        __walk_node(document, scope, dereference.node);
    } else if (base == NODE_PTR_ASSIGN) {
        let assignment: PtrAssignNode = node;
        __walk_node(document, scope, assignment.pointer);
        __walk_node(document, scope, assignment.value);
    } else if (base == NODE_VECTOR_LIT) {
        let vector: VectorLitNode = node;
        let i: Int = 0;
        let count: Int = 0;
        if (vector.elements is !null) { count = vector.elements.length(); }
        while (i < count) {
            let element: ArgNode = vector.elements[i];
            __walk_node(document, scope, element.val);
            i += 1;
        }
    } else if (base == NODE_INDEX_ACCESS) {
        let access: IndexAccessNode = node;
        __walk_node(document, scope, access.target);
        __walk_node(document, scope, access.index_node);
    } else if (base == NODE_INDEX_ASSIGN) {
        let assignment: IndexAssignNode = node;
        __walk_node(document, scope, assignment.target);
        __walk_node(document, scope, assignment.index_node);
        __walk_node(document, scope, assignment.value);
    } else if (base == NODE_SLICE_ACCESS) {
        let slice: SliceAccessNode = node;
        __walk_node(document, scope, slice.target);
        __walk_node(document, scope, slice.start_idx);
        __walk_node(document, scope, slice.end_idx);
    } else if (base == NODE_MAP_LIT) {
        let map: MapLitNode = node;
        let i: Int = 0;
        let count: Int = 0;
        if (map.pairs is !null) { count = map.pairs.length(); }
        while (i < count) {
            let pair: MapPairNode = map.pairs[i];
            __walk_node(document, scope, pair.key);
            __walk_node(document, scope, pair.value);
            i += 1;
        }
    } else if (base == NODE_TRY_UNWRAP) {
        let unwrap: TryUnwrapNode = node;
        __walk_node(document, scope, unwrap.expr);
    } else if (base == NODE_CATCH) {
        let catch_node: CatchNode = node;
        __walk_node(document, scope, catch_node.stmt);
        let catch_scope: __Scope = __Scope(scope);
        let catch_definition: SymbolDefinition = __definition(document, catch_scope, catch_node.err_name, SYMBOL_VARIABLE);
        catch_definition.type_name = "Error";
        catch_definition.signature = catch_definition.name + ": Error";
        __walk_node(document, catch_scope, catch_node.body);
    } else if (base == NODE_THROW) {
        let throw_node: ThrowNode = node;
        __walk_node(document, scope, throw_node.value);
    }
}

func __declare_params(document: SemanticDocument, scope: __Scope, params: Vector(Struct)) -> Void {
    if (params is null) { return; }
    let i: Int = 0;
    while (i < params.length()) {
        let param: ParamNode = params[i];
        __walk_type(document, scope, param.type_tok);
        let definition: SymbolDefinition = __definition(document, scope, param.name_tok, SYMBOL_PARAMETER);
        let declared_type: String = type_text(param.type_tok);
        definition.type_name = declared_type;
        definition.signature = definition.name + ": " + declared_type;
        if (param.is_variadic) {
            definition.type_name = "Array(" + declared_type + ")";
            definition.signature += "...";
        }
        if (param.default_val is !null) { definition.signature += " = " + __default_value_text(param.default_val); }
        i += 1;
    }
}

func __declare_type_params(document: SemanticDocument, scope: __Scope, params: Vector(Struct)) -> Void {
    if (params is null) { return; }
    let i: Int = 0;
    while (i < params.length()) {
        let param: GenericParamNode = params[i];
        let definition: SymbolDefinition = __definition(document, scope, param.name_tok, SYMBOL_TYPE_PARAMETER);
        definition.type_name = param.name_tok.value;
        definition.signature = param.name_tok.value;
        i += 1;
    }
    i = 0;
    while (i < params.length()) {
        let param: GenericParamNode = params[i];
        let j: Int = 0;
        while (param.constraints is !null && j < param.constraints.length()) {
            __walk_type(document, scope, param.constraints[j]);
            j += 1;
        }
        i += 1;
    }
}

func __walk_function(document: SemanticDocument, parent: __Scope, type_params: Vector(Struct), params: Vector(Struct), return_type: Struct, body: Struct) -> Void {
    let scope: __Scope = __Scope(parent);
    __declare_type_params(document, scope, type_params);
    __declare_params(document, scope, params);
    __walk_type(document, scope, return_type);
    __walk_node(document, scope, body);
}

func __import_module_token(node: ImportNode) -> Token {
    if (node.alias_tok is !null) { return node.alias_tok; }
    let path: String = node.path_tok.value;
    let start: Int = 0;
    let i: Int = 0;
    while (i < path.length()) {
        if (path[i] == '/' || path[i] == '\\') { start = i + 1; }
        i += 1;
    }
    let end: Int = path.length();
    if (path.ends_with(".wl")) { end -= 3; }
    return Token(type=WhitelangTokens.TOK_IDENTIFIER, value=path.slice(start, end), line=node.path_tok.line, col=node.path_tok.col + start + 1);
}

func __import_path_definition(document: SemanticDocument, node: ImportNode) -> SymbolDefinition {
    let module_token: Token = __import_module_token(node);
    let path_token: Token = Token(type=WhitelangTokens.TOK_STR_LIT, value=node.path_tok.value, line=node.path_tok.line, col=node.path_tok.col + 1);
    let definition: SymbolDefinition = SymbolDefinition(module_token.value, SYMBOL_MODULE, token_span(document.syntax.path, document.syntax.source_map, path_token));
    definition.import_path = node.path_tok.value;
    document.definitions.append(definition);
    return definition;
}

func __type_decl_name(node: Struct) -> String {
    let kind: Int = node_kind(node);
    if (kind == NODE_TYPE_DECL) { let declaration: TypeDeclNode = node; return declaration.name_tok.value; }
    if (kind == NODE_STRUCT_DEF) { let declaration: StructDefNode = node; return declaration.name_tok.value; }
    if (kind == NODE_CLASS_DEF) { let declaration: ClassDefNode = node; return declaration.name_tok.value; }
    if (kind == NODE_INTERFACE_DEF) { let declaration: InterfaceDefNode = node; return declaration.name_tok.value; }
    if (kind == NODE_ENUM_DEF) { let declaration: EnumDefNode = node; return declaration.name_tok.value; }
    return "";
}

func __validate_type_node(node: Struct, known: Dict, allow_external: Bool) -> Void {
    if (node is null) { return; }
    let kind: Int = node_kind(node);
    if (kind == NODE_VAR_ACCESS) {
        let access: VarAccessNode = node;
        let name: String = access.name_tok.value;
        if (!allow_external && !__builtin_type_name(name) && !known.contains_key(name)) { WhitelangExceptions.throw_type_error(access.pos, "Unknown type: " + name); }
    } else if (kind == NODE_GENERIC_TYPE) {
        let generic: GenericTypeNode = node;
        __validate_type_node(generic.base_type, known, allow_external);
        let i: Int = 0;
        while (generic.type_args is !null && i < generic.type_args.length()) { __validate_type_node(generic.type_args[i], known, allow_external); i += 1; }
    } else if (kind == NODE_PTR_TYPE) {
        let pointer: PointerTypeNode = node;
        __validate_type_node(pointer.base_type, known, allow_external);
    } else if (kind == NODE_VECTOR_TYPE) {
        let vector: VectorTypeNode = node;
        __validate_type_node(vector.element_type, known, allow_external);
    } else if (kind == NODE_ARRAY_TYPE) {
        let array: ArrayTypeNode = node;
        __validate_type_node(array.base_type, known, allow_external);
    } else if (kind == NODE_SLICE_TYPE) {
        let slice: SliceTypeNode = node;
        __validate_type_node(slice.element_type, known, allow_external);
    } else if (kind == NODE_FALLIBLE_TYPE) {
        let fallible: FallibleTypeNode = node;
        __validate_type_node(fallible.base_type, known, allow_external);
    } else if (kind == NODE_FUNCTION_TYPE) {
        let callable: FunctionTypeNode = node;
        let i: Int = 0;
        while (callable.arg_types is !null && i < callable.arg_types.length()) { __validate_type_node(callable.arg_types[i], known, allow_external); i += 1; }
        __validate_type_node(callable.return_type, known, allow_external);
    } else if (kind == NODE_METHOD_TYPE) {
        let callable: MethodTypeNode = node;
        let i: Int = 0;
        while (callable.arg_types is !null && i < callable.arg_types.length()) { __validate_type_node(callable.arg_types[i], known, allow_external); i += 1; }
        __validate_type_node(callable.return_type, known, allow_external);
    }
}

func __type_reaches(node: Struct, target: String, declarations: Dict, visiting: Dict) -> Bool {
    if (node is null) { return false; }
    let kind: Int = node_kind(node);
    if (kind == NODE_VAR_ACCESS) {
        let access: VarAccessNode = node;
        let name: String = access.name_tok.value;
        if (name == target) { return true; }
        let declaration: TypeDeclNode = declarations[name];
        if (declaration is null || visiting.contains_key(name)) { return false; }
        visiting.put(name, true);
        let reaches: Bool = __type_reaches(declaration.target_type, target, declarations, visiting);
        visiting.remove(name);
        return reaches;
    }
    if (kind == NODE_GENERIC_TYPE) {
        let generic: GenericTypeNode = node;
        if (__type_reaches(generic.base_type, target, declarations, visiting)) { return true; }
        let i: Int = 0;
        while (generic.type_args is !null && i < generic.type_args.length()) { if (__type_reaches(generic.type_args[i], target, declarations, visiting)) { return true; } i += 1; }
    } else if (kind == NODE_PTR_TYPE) {
        let pointer: PointerTypeNode = node;
        return __type_reaches(pointer.base_type, target, declarations, visiting);
    } else if (kind == NODE_VECTOR_TYPE) {
        let vector: VectorTypeNode = node;
        return __type_reaches(vector.element_type, target, declarations, visiting);
    } else if (kind == NODE_ARRAY_TYPE) {
        let array: ArrayTypeNode = node;
        return __type_reaches(array.base_type, target, declarations, visiting);
    } else if (kind == NODE_SLICE_TYPE) {
        let slice: SliceTypeNode = node;
        return __type_reaches(slice.element_type, target, declarations, visiting);
    } else if (kind == NODE_FALLIBLE_TYPE) {
        let fallible: FallibleTypeNode = node;
        return __type_reaches(fallible.base_type, target, declarations, visiting);
    } else if (kind == NODE_FUNCTION_TYPE) {
        let callable: FunctionTypeNode = node;
        let i: Int = 0;
        while (callable.arg_types is !null && i < callable.arg_types.length()) { if (__type_reaches(callable.arg_types[i], target, declarations, visiting)) { return true; } i += 1; }
        return __type_reaches(callable.return_type, target, declarations, visiting);
    } else if (kind == NODE_METHOD_TYPE) {
        let callable: MethodTypeNode = node;
        let i: Int = 0;
        while (callable.arg_types is !null && i < callable.arg_types.length()) { if (__type_reaches(callable.arg_types[i], target, declarations, visiting)) { return true; } i += 1; }
        return __type_reaches(callable.return_type, target, declarations, visiting);
    }
    return false;
}

func __validate_named_types(document: SemanticDocument) -> Void {
    let block: BlockNode = document.syntax.ast;
    let known: Dict = Dict(32);
    let declarations: Dict = Dict(16);
    let allow_external: Bool = false;
    let i: Int = 0;
    while (block.stmts is !null && i < block.stmts.length()) {
        let node: Struct = block.stmts[i];
        let name: String = __type_decl_name(node);
        if (node_kind(node) == NODE_IMPORT) {
            let imported: ImportNode = node;
            let import_index: Int = 0;
            while (imported.symbols is !null && import_index < imported.symbols.length()) {
                let symbol: ImportSymbolNode = imported.symbols[import_index];
                if (symbol.name_tok.type == WhitelangTokens.TOK_MUL) { allow_external = true; }
                else if (symbol.alias_tok is !null) { known.put(symbol.alias_tok.value, true); }
                else { known.put(symbol.name_tok.value, true); }
                import_index += 1;
            }
        }
        if (name.length() > 0 && node_kind(node) != NODE_TYPE_DECL) { known.put(name, true); }
        i += 1;
    }
    i = 0;
    while (block.stmts is !null && i < block.stmts.length()) {
        if (node_kind(block.stmts[i]) == NODE_TYPE_DECL) {
            let declaration: TypeDeclNode = block.stmts[i];
            let name: String = declaration.name_tok.value;
            if (__builtin_type_name(name) || known.contains_key(name) || declarations.contains_key(name)) { WhitelangExceptions.throw_name_error(declaration.pos, "Type '" + name + "' is already defined."); }
            else { declarations.put(name, declaration); known.put(name, true); }
        }
        i += 1;
    }
    i = 0;
    while (block.stmts is !null && i < block.stmts.length()) {
        if (node_kind(block.stmts[i]) == NODE_TYPE_DECL) {
            let declaration: TypeDeclNode = block.stmts[i];
            __validate_type_node(declaration.target_type, known, allow_external);
            let visiting: Dict = Dict(8);
            visiting.put(declaration.name_tok.value, true);
            if (__type_reaches(declaration.target_type, declaration.name_tok.value, declarations, visiting)) { WhitelangExceptions.throw_type_error(declaration.pos, "Type declaration for '" + declaration.name_tok.value + "' is recursive."); }
        }
        i += 1;
    }
}

func __declare_types(document: SemanticDocument, scope: __Scope) -> Void {
    let block: BlockNode = document.syntax.ast;
    let i: Int = 0;
    while (block.stmts is !null && i < block.stmts.length()) {
        if (node_kind(block.stmts[i]) == NODE_TYPE_DECL) {
            let declaration: TypeDeclNode = block.stmts[i];
            if (document.type_declarations.contains_key(declaration.name_tok.value)) { i += 1; continue; }
            let definition: SymbolDefinition = __definition(document, scope, declaration.name_tok, SYMBOL_TYPE);
            definition.top_level = true;
            definition.type_name = declaration.name_tok.value;
            definition.underlying_type = type_text(declaration.target_type);
            definition.transparent_alias = declaration.is_alias;
            if (declaration.is_alias) { definition.signature = "type " + definition.name + " = " + definition.underlying_type + " (alias)"; }
            else { definition.signature = "type " + definition.name + " = " + definition.underlying_type; }
            document.type_declarations.put(definition.name, definition);
        }
        i += 1;
    }
}

func __declare_top_level(document: SemanticDocument, scope: __Scope) -> Void {
    let block: BlockNode = document.syntax.ast;
    let i: Int = 0;
    let count: Int = 0;
    if (block.stmts is !null) { count = block.stmts.length(); }
    while (i < count) {
        let node: Struct = block.stmts[i];
        let base: Int = node_kind(node);
        if (base == NODE_TYPE_DECL) {
        } else if (base == NODE_FUNC_DEF) {
            let function_node: FunctionDefNode = node;
            let definition: SymbolDefinition = __definition(document, scope, function_node.name_tok, SYMBOL_FUNCTION);
            definition.top_level = true;
            definition.type_name = type_text(function_node.ret_type_tok);
            definition.signature = __callable_signature("func ", definition.name, function_node.type_params, function_node.params, function_node.ret_type_tok);
        } else if (base == NODE_EXTERN_FUNC) {
            let extern_node: ExternFuncNode = node;
            let definition: SymbolDefinition = __definition(document, scope, extern_node.name_tok, SYMBOL_FUNCTION);
            definition.top_level = true;
            definition.type_name = type_text(extern_node.ret_type_tok);
            definition.signature = __callable_signature("extern func ", definition.name, null, extern_node.params, extern_node.ret_type_tok);
        } else if (base == NODE_EXTERN_BLOCK) {
            let extern_block: ExternBlockNode = node;
            let j: Int = 0;
            let count: Int = 0;
            if (extern_block.funcs is !null) {
                count = extern_block.funcs.length();
            }
            while (j < count) {
                let extern_node: ExternFuncNode = extern_block.funcs[j];
                let definition: SymbolDefinition = __definition(document, scope, extern_node.name_tok, SYMBOL_FUNCTION);
                definition.top_level = true;
                definition.type_name = type_text(extern_node.ret_type_tok);
                definition.signature = __callable_signature("extern func ", definition.name, null, extern_node.params, extern_node.ret_type_tok);
                j += 1;
            }
        } else if (base == NODE_VAR_DECL) {
            let declaration: VarDeclareNode = node;
            let kind: Int = SYMBOL_VARIABLE;
            if (declaration.is_const) { kind = SYMBOL_CONSTANT; }
            let definition: SymbolDefinition = __definition(document, scope, declaration.name_tok, kind);
            definition.top_level = true;
            definition.type_name = type_text(declaration.type_node);
            if (definition.type_name == "Auto") {
                definition.type_name = __expression_type(document, scope, declaration.value);
            }
            let declaration_kind: String = "let ";
            if (declaration.is_const) { declaration_kind = "const "; }
            definition.signature = declaration_kind + definition.name + ": " + definition.type_name;
        } else if (base == NODE_STRUCT_DEF) {
            let struct_node: StructDefNode = node;
            let definition: SymbolDefinition = __definition(document, scope, struct_node.name_tok, SYMBOL_STRUCT);
            definition.top_level = true;
            definition.type_name = struct_node.name_tok.value;
            definition.signature = "struct " + definition.name + __type_params_text(struct_node.type_params);
        } else if (base == NODE_CLASS_DEF) {
            let class_node: ClassDefNode = node;
            let definition: SymbolDefinition = __definition(document, scope, class_node.name_tok, SYMBOL_CLASS);
            definition.top_level = true;
            definition.type_name = class_node.name_tok.value;
            definition.signature = "class " + definition.name + __type_params_text(class_node.type_params);
            if (class_node.parent_tok is !null) { document.parent_types.put(class_node.name_tok.value, [type_text(class_node.parent_tok)]); }
        } else if (base == NODE_ENUM_DEF) {
            let enum_node: EnumDefNode = node;
            let kind: Int = SYMBOL_ENUM;
            if (enum_node.is_error) { kind = SYMBOL_ERROR; }
            let definition: SymbolDefinition = __definition(document, scope, enum_node.name_tok, kind);
            definition.top_level = true;
            definition.type_name = enum_node.name_tok.value;
            if (enum_node.is_error) { definition.signature = "error " + definition.name; }
            else { definition.signature = "enum " + definition.name; }
        } else if (base == NODE_INTERFACE_DEF) {
            let interface_node: InterfaceDefNode = node;
            let definition: SymbolDefinition = __definition(document, scope, interface_node.name_tok, SYMBOL_INTERFACE);
            definition.top_level = true;
            definition.type_name = interface_node.name_tok.value;
            definition.signature = "interface " + definition.name + __type_params_text(interface_node.type_params);
            if (interface_node.interfaces is !null && interface_node.interfaces.length() > 0) {
                definition.signature += " with " + __type_list_text(interface_node.interfaces);
                document.parent_types.put(interface_node.name_tok.value, __type_names(interface_node.interfaces));
            }
        } else if (base == NODE_IMPORT) {
            let import_node: ImportNode = node;
            let path_definition: SymbolDefinition = __import_path_definition(document, import_node);
            if (import_node.symbols is null) {
                let module: SymbolDefinition = path_definition;
                if (import_node.alias_tok is !null) {
                    module = __definition(document, scope, import_node.alias_tok, SYMBOL_MODULE);
                    module.import_path = import_node.path_tok.value;
                } else {
                    scope.define(module);
                }
                module.top_level = true;
            } else {
                let j: Int = 0;
                while (j < import_node.symbols.length()) {
                    let imported: ImportSymbolNode = import_node.symbols[j];
                    let token: Token = imported.name_tok;
                    if (imported.alias_tok is !null) { token = imported.alias_tok; }
                    let definition: SymbolDefinition = __definition(document, scope, token, SYMBOL_IMPORT);
                    definition.top_level = true;
                    definition.import_path = import_node.path_tok.value;
                    definition.import_name = imported.name_tok.value;
                    if (imported.alias_tok is !null) {
                        document.references.append(SymbolReference(imported.name_tok.value, token_span(document.syntax.path, document.syntax.source_map, imported.name_tok), definition));
                    }
                    j += 1;
                }
            }
        }
        i += 1;
    }
}

func __walk_top_level(document: SemanticDocument, scope: __Scope) -> Void {
    let block: BlockNode = document.syntax.ast;
    let i: Int = 0;
    let statement_count: Int = 0;
    if (block.stmts is !null) {
        statement_count = block.stmts.length();
    }
    while (i < statement_count) {
        let node: Struct = block.stmts[i];
        let base: Int = node_kind(node);
        if (base == NODE_TYPE_DECL) {
            let declaration: TypeDeclNode = node;
            __walk_type(document, scope, declaration.target_type);
        } else if (base == NODE_FUNC_DEF) {
            let function_node: FunctionDefNode = node;
            __walk_annotations(document, scope, function_node.annotations);
            __walk_function(document, scope, function_node.type_params, function_node.params, function_node.ret_type_tok, function_node.body);
        } else if (base == NODE_EXTERN_FUNC) {
            let extern_node: ExternFuncNode = node;
            let function_scope: __Scope = __Scope(scope);
            __declare_params(document, function_scope, extern_node.params);
            __walk_type(document, function_scope, extern_node.ret_type_tok);
        } else if (base == NODE_EXTERN_BLOCK) {
            let extern_block: ExternBlockNode = node;
            let j: Int = 0;
            let count: Int = 0;
            if (extern_block.funcs is !null) {
                count = extern_block.funcs.length();
            }
            while (j < count) {
                let extern_node: ExternFuncNode = extern_block.funcs[j];
                let function_scope: __Scope = __Scope(scope);
                __declare_params(document, function_scope, extern_node.params);
                __walk_type(document, function_scope, extern_node.ret_type_tok);
                j += 1;
            }
        } else if (base == NODE_VAR_DECL) {
            let declaration: VarDeclareNode = node;
            __walk_annotations(document, scope, declaration.annotations);
            __walk_type(document, scope, declaration.type_node);
            __walk_node(document, scope, declaration.value);
            __validate_named_initializer(document, scope, declaration);
        } else if (base == NODE_STRUCT_DEF) {
            let struct_node: StructDefNode = node;
            __walk_annotations(document, scope, struct_node.annotations);
            let struct_scope: __Scope = __Scope(scope);
            __declare_type_params(document, struct_scope, struct_node.type_params);
            let this_definition: SymbolDefinition = SymbolDefinition("this", SYMBOL_VARIABLE, null);
            this_definition.type_name = struct_node.name_tok.value;
            struct_scope.define(this_definition);
            let j: Int = 0;
            let count: Int = 0;
            if (struct_node.fields is !null) {
                count = struct_node.fields.length();
            }
            while (j < count) {
                let field: ParamNode = struct_node.fields[j];
                __walk_type(document, struct_scope, field.type_tok);
                let definition: SymbolDefinition = __definition( document, struct_scope, field.name_tok, SYMBOL_FIELD );
                definition.type_name = type_text(field.type_tok);
                definition.signature = definition.name + ": " + definition.type_name;
                __register_member(document, struct_node.name_tok.value, definition);
                j += 1;
            }
            __walk_node(document, struct_scope, struct_node.body);
        } else if (base == NODE_CLASS_DEF) {
            let class_node: ClassDefNode = node;
            __walk_annotations(document, scope, class_node.annotations);
            let class_scope: __Scope = __Scope(scope);
            __declare_type_params(document, class_scope, class_node.type_params);
            if (class_node.parent_tok is !null) { __walk_type(document, class_scope, class_node.parent_tok); }
            if (class_node.interfaces is !null) {
                let j: Int = 0;
                while (j < class_node.interfaces.length()) {
                    __walk_type(document, class_scope, class_node.interfaces[j]);
                    j += 1;
                }
            }

            let self_definition: SymbolDefinition = SymbolDefinition("self", SYMBOL_VARIABLE, null);
            self_definition.type_name = class_node.name_tok.value;
            class_scope.define(self_definition);
            if (class_node.parent_tok is !null) {
                let super_definition: SymbolDefinition = SymbolDefinition("$super", SYMBOL_VARIABLE, null);
                super_definition.type_name = type_text(class_node.parent_tok);
                class_scope.define(super_definition);
            }
            let j: Int = 0;
            let field_count: Int = 0;
            if (class_node.fields is !null) {
                field_count = class_node.fields.length();
            }
            while (j < field_count) {
                let field: VarDeclareNode = class_node.fields[j];
                __walk_annotations(document, class_scope, field.annotations);
                __walk_type(document, class_scope, field.type_node);
                __walk_node(document, class_scope, field.value);
                __validate_named_initializer(document, class_scope, field);
                let definition: SymbolDefinition = __definition(document, class_scope, field.name_tok, SYMBOL_FIELD);
                definition.type_name = type_text(field.type_node);
                __register_member(document, class_node.name_tok.value, definition);
                if (definition.type_name == "Auto") {
                    definition.type_name = __expression_type(document, class_scope, field.value);
                }
                definition.signature = "let " + definition.name + ": " + definition.type_name;
                j += 1;
            }
            j = 0;
            let method_count: Int = 0;
            if (class_node.methods is !null) {
                method_count = class_node.methods.length();
            }
            let conversions: Dict = Dict(8);
            while (j < method_count) {
                let method_node: MethodDefNode = class_node.methods[j];
                if (method_node.name_tok.value == "$field_init") {
                    j += 1;
                    continue;
                }
                let method_kind: Int = SYMBOL_METHOD;
                let method_name: String = method_node.name_tok.value;
                let method_token: Token = method_node.name_tok;
                if (method_name == "$init") {
                    method_token = Token(type=WhitelangTokens.TOK_IDENTIFIER, value="init", line=method_node.pos.ln, col=method_node.pos.col);
                } else if (method_name == "$deinit") {
                    method_token = Token(type=WhitelangTokens.TOK_IDENTIFIER, value="deinit", line=method_node.pos.ln, col=method_node.pos.col);
                } else if (method_name == "$type") {
                    method_kind = SYMBOL_CONVERSION;
                    method_token = Token(type=WhitelangTokens.TOK_IDENTIFIER, value="type", line=method_node.pos.ln, col=method_node.pos.col);
                    let target: String = __canonical_type(document, type_text(method_node.return_type));
                    if (conversions.contains_key(target)) { WhitelangExceptions.throw_name_error(method_node.pos, "class '" + class_node.name_tok.value + "' already defines a conversion to " + target); }
                    else { conversions.put(target, true); }
                }
                let definition: SymbolDefinition = __definition(document, class_scope, method_token, method_kind);
                definition.type_name = type_text(method_node.return_type);
                if (method_name == "$init") { definition.signature = "init" + __params_text(method_node.params); }
                else if (method_name == "$deinit") { definition.signature = "deinit" + __params_text(method_node.params); }
                else if (method_name == "$type") { definition.signature = "type " + type_text(method_node.return_type); }
                else { definition.signature = __callable_signature("func ", method_name, method_node.type_params, method_node.params, method_node.return_type); }
                __register_member(document, class_node.name_tok.value, definition);
                j += 1;
            }
            j = 0;
            while (j < method_count) {
                let method_node: MethodDefNode = class_node.methods[j];
                if (method_node.name_tok.value != "$field_init") {
                    __walk_annotations(document, class_scope, method_node.annotations);
                    __walk_function(document, class_scope, method_node.type_params, method_node.params, method_node.return_type, method_node.body);
                }
                j += 1;
            }
        } else if (base == NODE_ENUM_DEF) {
            let enum_node: EnumDefNode = node;
            __walk_annotations(document, scope, enum_node.annotations);
            let j: Int = 0;
            let count: Int = 0;
            if (enum_node.fields is !null) {
                count = enum_node.fields.length();
            }
            while (j < count) {
                let field: EnumFieldNode = enum_node.fields[j];
                let field_kind: Int = SYMBOL_ENUM_CASE;
                if (enum_node.is_error) { field_kind = SYMBOL_ERROR_CASE; }
                let field_definition: SymbolDefinition = SymbolDefinition(field.name_tok.value, field_kind, token_span(document.syntax.path, document.syntax.source_map, field.name_tok));
                field_definition.owner_type = enum_node.name_tok.value;
                field_definition.signature = enum_node.name_tok.value + "." + field.name_tok.value;
                document.definitions.append(field_definition);
                document.members.put(enum_node.name_tok.value + "." + field.name_tok.value, field_definition);
                __walk_node(document, scope, field.value);
                j += 1;
            }
        } else if (base == NODE_INTERFACE_DEF) {
            let interface_node: InterfaceDefNode = node;
            let interface_scope: __Scope = __Scope(scope);
            __declare_type_params(document, interface_scope, interface_node.type_params);
            let parent_index: Int = 0;
            while (interface_node.interfaces is !null && parent_index < interface_node.interfaces.length()) {
                __walk_type(document, interface_scope, interface_node.interfaces[parent_index]);
                parent_index += 1;
            }
            let j: Int = 0;
            let count: Int = 0;
            if (interface_node.methods is !null) {
                count = interface_node.methods.length();
            }
            while (j < count) {
                let method_node: MethodDefNode = interface_node.methods[j];
                __walk_annotations(document, interface_scope, method_node.annotations);
                let definition: SymbolDefinition = __definition( document, interface_scope, method_node.name_tok, SYMBOL_METHOD );
                definition.type_name = type_text(method_node.return_type);
                definition.signature = __callable_signature("func ", method_node.name_tok.value, method_node.type_params, method_node.params, method_node.return_type);
                __register_member(document, interface_node.name_tok.value, definition);
                __walk_function(document, interface_scope, method_node.type_params, method_node.params, method_node.return_type, null);
                j += 1;
            }
        }
        i += 1;
    }
}

func analyze_document(syntax: FrontendDocument) -> SemanticDocument {
    let document: SemanticDocument = SemanticDocument(syntax);
    if (syntax is null || syntax.ast is null) { return document; }

    __validate_named_types(document);
    __index_member_symbols(document);
    let scope: __Scope = __Scope(null);
    __declare_types(document, scope);
    __declare_top_level(document, scope);
    __walk_top_level(document, scope);
    return document;
}

func __contains_utf16(range: WhitelangExceptions.SourceRange, line: Int, column: Int) -> Bool {
    if (range is null || range.start.line != line || range.end.line != line) {
        return false;
    }
    return column >= range.start.utf16_column &&
           column < range.end.utf16_column;
}

func definition_at(document: SemanticDocument, line: Int, utf16_column: Int) -> SymbolDefinition {
    if (document is null) { return null; }

    let reference: SymbolReference = reference_at(document, line, utf16_column);
    if (reference is !null) { return reference.definition; }

    let i: Int = 0;
    while (i < document.definitions.length()) {
        let definition: SymbolDefinition = document.definitions[i];
        if (__contains_utf16(definition.range, line, utf16_column)) {
            return definition;
        }
        i += 1;
    }
    return null;
}

func reference_at(document: SemanticDocument, line: Int, utf16_column: Int) -> SymbolReference {
    if (document is null) { return null; }
    let i: Int = 0;
    while (i < document.references.length()) {
        let reference: SymbolReference = document.references[i];
        if (__contains_utf16(reference.range, line, utf16_column)) {
            return reference;
        }
        i += 1;
    }
    return null;
}

func type_at(document: SemanticDocument, line: Int, utf16_column: Int) -> String {
    let definition: SymbolDefinition = definition_at(document, line, utf16_column);
    if (definition is null) { return ""; }
    return definition.type_name;
}
