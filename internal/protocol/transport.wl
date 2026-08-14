// framed standard I/O transport
import "io"

const MAX_HEADER_SIZE -> Int = 8192;
const MAX_MESSAGE_SIZE -> Int = 67108864;

error TransportError {
    InvalidHeader,
    HeaderTooLarge,
    MessageTooLarge,
    UnexpectedEndOfFile
}

class Message {
    let body -> String;
    let closed -> Bool;

    init(body -> String, closed -> Bool) {
        self.body = body;
        self.closed = closed;
    }
}

struct ContentLengthHeader(matched -> Bool, valid -> Bool, too_large -> Bool, value -> Int)

func __ascii_equal_fold(left -> Byte, right -> Byte) -> Bool {
    let lhs -> Int = Int(left);
    let rhs -> Int = Int(right);
    if (lhs >= 65 && lhs <= 90) { lhs += 32; }
    if (rhs >= 65 && rhs <= 90) { rhs += 32; }
    return lhs == rhs;
}

func parse_content_length(line -> String) -> ContentLengthHeader {
    let prefix -> String = "Content-Length:";
    if (line.length() < prefix.length()) { return ContentLengthHeader(false, true, false, -1); }
    let prefix_index -> Int = 0;
    while (prefix.length() > prefix_index) {
        if (!__ascii_equal_fold(line[prefix_index], prefix[prefix_index])) { return ContentLengthHeader(false, true, false, -1); }
        prefix_index += 1;
    }
    let i -> Int = prefix.length();
    while (line.length() > i && (line[i] == ' ' || line[i] == '\t')) { i += 1; }

    let length -> Int = 0;
    let found -> Bool = false;
    while (line.length() > i && line[i] >= '0' && line[i] <= '9') {
        found = true;
        let digit -> Int = Int(line[i]) - Int('0');
        if (length > (MAX_MESSAGE_SIZE - digit) / 10) { return ContentLengthHeader(true, false, true, -1); }
        length = length * 10 + digit;
        i += 1;
    }
    while (line.length() > i && (line[i] == ' ' || line[i] == '\t')) { i += 1; }
    if (i != line.length() || !found) { return ContentLengthHeader(true, false, false, -1); }
    return ContentLengthHeader(true, true, false, length);
}

func read_message() -> Message? {
    // EOF is clean only between protocol frames
    let content_length -> Int = -1;
    let header_size -> Int = 0;
    let saw_header -> Bool = false;
    while true {
        let line -> String = io.stdin.read_line()?;
        catch(err) {
            if (!saw_header) { return Message("", true); }
            throw TransportError.UnexpectedEndOfFile;
        }
        if (line.length() == 0) { break; }
        saw_header = true;
        if (line.length() > MAX_HEADER_SIZE - header_size - 2) { throw TransportError.HeaderTooLarge; }
        header_size += line.length() + 2;
        let parsed -> ContentLengthHeader = parse_content_length(line);
        if (parsed.too_large) { throw TransportError.MessageTooLarge; }
        if (parsed.matched && !parsed.valid) { throw TransportError.InvalidHeader; }
        if (parsed.matched) {
            if (content_length >= 0) { throw TransportError.InvalidHeader; }
            content_length = parsed.value;
        }
    }
    if (content_length < 0) { throw TransportError.InvalidHeader; }
    if (content_length > MAX_MESSAGE_SIZE) { throw TransportError.MessageTooLarge; }
    let body -> String = io.stdin.read_full(content_length)?;
    catch(err) { throw TransportError.UnexpectedEndOfFile; }
    return Message(body, false);
}

func write_message(body -> String) -> Void? {
    io.stdout.write_all("Content-Length: " + body.length() + "\r\n\r\n")?;
    io.stdout.write_all(body)?;
    io.stdout.flush()?;
    return;
}
