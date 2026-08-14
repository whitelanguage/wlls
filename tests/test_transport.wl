// Test: LSP_TRANSPORT
// File: tests/test_transport.wl
// Focus: Content-Length parsing and protocol size limits.
import "../internal/protocol/_pkg.wl" as protocol

func main() -> Int {
    let header -> protocol.ContentLengthHeader = protocol.parse_content_length("Content-Length: 123");
    if (!header.matched || !header.valid || header.too_large || header.value != 123) {
        print("FAIL: valid Content-Length");
        return 1;
    }
    header = protocol.parse_content_length("content-length:\t7 ");
    if (!header.matched || !header.valid || header.value != 7) {
        print("FAIL: case-insensitive Content-Length");
        return 1;
    }

    header = protocol.parse_content_length("Content-Type: application/vscode-jsonrpc; charset=utf-8");
    if (header.matched || !header.valid) {
        print("FAIL: unrelated protocol header");
        return 1;
    }

    header = protocol.parse_content_length("Content-Length: 12x");
    if (!header.matched || header.valid || header.too_large) {
        print("FAIL: malformed Content-Length");
        return 1;
    }

    header = protocol.parse_content_length("Content-Length: 67108865");
    if (!header.matched || header.valid || !header.too_large) {
        print("FAIL: oversized Content-Length");
        return 1;
    }

    print("PASS: LSP transport");
    return 0;
}
