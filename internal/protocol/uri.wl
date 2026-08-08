// file URI conversion at the LSP boundary
import "strings"

func __hex_digit(value -> Byte) -> Int {
    let raw -> Int = Int(value);
    if (raw >= 48 && raw <= 57) { return raw - 48; }
    if (raw >= 97 && raw <= 102) { return raw - 97 + 10; }
    if (raw >= 65 && raw <= 70) { return raw - 65 + 10; }
    return -1;
}

func __write_byte(output -> strings.Builder, value -> Byte) -> Bool {
    output.write_byte(value)?;
    catch(err) { return false; }
    return true;
}

func __write(output -> strings.Builder, value -> String) -> Bool {
    output.write(value)?;
    catch(err) { return false; }
    return true;
}

func __finish(output -> strings.Builder) -> String {
    let result -> String = output.build()?;
    catch(err) { return null; }
    return result;
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
    }
    let drive_path -> Bool = false;
    if (!unc && start + 2 < uri.length() && uri[start] == '/' && ((uri[start + 1] >= 'A' && uri[start + 1] <= 'Z') || (uri[start + 1] >= 'a' && uri[start + 1] <= 'z'))) {
        if (uri[start + 2] == ':') { drive_path = true; }
        else if (start + 4 < uri.length() && uri[start + 2] == '%' && __hex_digit(uri[start + 3]) >= 0 && __hex_digit(uri[start + 4]) >= 0 && ((__hex_digit(uri[start + 3]) << 4) | __hex_digit(uri[start + 4])) == 58) { drive_path = true; }
    }
    if (drive_path) { start += 1; }
    let output -> strings.Builder = strings.Builder(uri.length() - start + 2);
    if (unc && (!__write_byte(output, Byte(47)) || !__write_byte(output, Byte(47)))) { return null; }
    let i -> Int = start;
    let first -> Bool = true;
    while (i < uri.length()) {
        if (uri[i] == '?' || uri[i] == '#') { return null; }
        let value -> Byte = uri[i];
        if (value == '%') {
            if (i + 2 >= uri.length()) { return null; }
            let high -> Int = __hex_digit(uri[i + 1]);
            let low -> Int = __hex_digit(uri[i + 2]);
            if (high < 0 || low < 0) { return null; }
            let decoded -> Int = (high << 4) | low;
            if (decoded == 0 || !__write_byte(output, Byte(decoded))) { return null; }
            i += 3;
        } else {
            if (first && drive_path && value >= 'a' && value <= 'z') { value = Byte(Int(value) - 32); }
            if (!__write_byte(output, value)) { return null; }
            i += 1;
        }
        first = false;
    }
    return __finish(output);
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
    let capacity -> Int = 64;
    if (path.length() <= (2147483647 - 8) / 3) { capacity = path.length() * 3 + 8; }
    let output -> strings.Builder = strings.Builder(capacity);
    if (!__write(output, "file://")) { return null; }
    let unc -> Bool = path.length() > 1 && (path[0] == '/' || path[0] == '\\') && (path[1] == '/' || path[1] == '\\');
    if (!unc && (path.length() == 0 || path[0] != '/') && !__write_byte(output, Byte(47))) { return null; }
    let i -> Int = 0;
    if (unc) { i = 2; }
    while (i < path.length()) {
        let value -> Byte = path[i];
        if (value == '\\') {
            if (!__write_byte(output, Byte(47))) { return null; }
        } else if (__uri_unreserved(value)) {
            if (!__write_byte(output, value)) { return null; }
        } else {
            if (!__write_byte(output, Byte(37)) || !__write_byte(output, __hex((Int(value) >> 4) & 15)) || !__write_byte(output, __hex(Int(value) & 15))) { return null; }
        }
        i += 1;
    }
    return __finish(output);
}
