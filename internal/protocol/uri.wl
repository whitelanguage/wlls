// file URI conversion at the LSP boundary
extern "C" {
    func wl_alloc_string(size -> Long) -> String;
    func wl_string_set_length(value -> String, length -> Int) -> Void;
}

func __string_data(value -> String) -> AnyPtr {
    if (value is null) { return nullptr; }
    let ptr fields -> AnyPtr = AnyPtr(value);
    return fields[0];
}

func __hex_digit(value -> Byte) -> Int {
    let raw -> Int = Int(value);
    if (raw >= 48 && raw <= 57) { return raw - 48; }
    if (raw >= 97 && raw <= 102) { return raw - 97 + 10; }
    if (raw >= 65 && raw <= 70) { return raw - 65 + 10; }
    return -1;
}

func uri_to_path(uri -> String) -> String {
    if (uri is null || !uri.starts_with("file://")) { return null; }
    let start -> Int = 7;
    let unc -> Bool = false;
    if (start >= uri.length()) { return null; }
    if (uri[start] != '/') {
        let authority_end -> Int = start;
        while (authority_end < uri.length() && uri[authority_end] != '/') { authority_end += 1; }
        if (authority_end == uri.length()) { return null; }
        let authority -> String = uri.slice(start, authority_end);
        if (authority == "localhost") { start = authority_end; }
        else { unc = true; }
    } else if (start + 2 < uri.length() && uri[start + 2] == ':') {
        start += 1;
    }
    let result -> String = wl_alloc_string(Long(uri.length() - start + 2));
    if (result is null) { return null; }
    let ptr output -> Byte = __string_data(result);
    let i -> Int = start;
    let written -> Int = 0;
    if (unc) {
        output[written] = Byte(47);
        output[written + 1] = Byte(47);
        written += 2;
    }
    while (i < uri.length()) {
        if (uri[i] == '?' || uri[i] == '#') { return null; }
        if (uri[i] == '%' && i + 2 < uri.length()) {
            let high -> Int = __hex_digit(uri[i + 1]);
            let low -> Int = __hex_digit(uri[i + 2]);
            if (high < 0 || low < 0) { return null; }
            let decoded -> Int = (high << 4) | low;
            if (decoded == 0) { return null; }
            output[written] = Byte(decoded);
            written += 1;
            i += 3;
        } else if (uri[i] == '%') {
            return null;
        } else {
            output[written] = uri[i];
            written += 1;
            i += 1;
        }
    }
    if (!unc && written > 1 && output[1] == Byte(58) && output[0] >= Byte(97) && output[0] <= Byte(122)) { output[0] = Byte(Int(output[0]) - 32); }
    wl_string_set_length(result, written);
    if (!result.is_valid_utf8()) { return null; }
    return result;
}

func __uri_unreserved(value -> Byte) -> Bool {
    let raw -> Int = Int(value);
    return (raw >= 97 && raw <= 122) || (raw >= 65 && raw <= 90) || (raw >= 48 && raw <= 57) || raw == 45 || raw == 46 || raw == 95 || raw == 126 || raw == 47 || raw == 58;
}

func __hex(value -> Int) -> Byte {
    if (value < 10) { return Byte(Int('0') + value); }
    return Byte(Int('A') + value - 10);
}

func path_to_uri(path -> String) -> String {
    if (path is null) { return null; }
    if (path.starts_with("file://")) { return path; }
    let result -> String = wl_alloc_string(Long(path.length()) * 3L + 8L);
    if (result is null) { return null; }
    let ptr output -> Byte = __string_data(result);
    let written -> Int = 0;
    let prefix -> String = "file://";
    let prefix_index -> Int = 0;
    while (prefix_index < prefix.length()) {
        output[written] = prefix[prefix_index];
        written += 1;
        prefix_index += 1;
    }
    let unc -> Bool = path.length() > 1 && (path[0] == '/' || path[0] == '\\') && (path[1] == '/' || path[1] == '\\');
    if (!unc && (path.length() == 0 || path[0] != '/')) {
        output[written] = Byte(47);
        written += 1;
    }
    let i -> Int = 0;
    if (unc) { i = 2; }
    while (i < path.length()) {
        let value -> Byte = path[i];
        if (value == '\\') {
            output[written] = Byte(47);
            written += 1;
        } else if (__uri_unreserved(value)) {
            output[written] = value;
            written += 1;
        } else {
            output[written] = Byte(37);
            output[written + 1] = __hex((Int(value) >> 4) & 15);
            output[written + 2] = __hex(Int(value) & 15);
            written += 3;
        }
        i += 1;
    }
    wl_string_set_length(result, written);
    return result;
}
