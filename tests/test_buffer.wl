// Test: PROTOCOL_BUFFER
// File: tests/test_buffer.wl
// Focus: Protocol byte buffer growth and integer encoding.
import "builtin"
import "../internal/protocol/_pkg.wl" as protocol

func main() -> Int {
    let output -> protocol.ByteBuffer = protocol.ByteBuffer(1);
    if (!output.write("tokens=") || !output.write_uint(0) || !output.write_byte(Byte(44)) || !output.write_uint(2147483647) || output.write_uint(-1)) {
        builtin.print("FAIL: protocol buffer write");
        return 1;
    }
    if (output.finish() != "tokens=0,2147483647") {
        builtin.print("FAIL: protocol buffer contents");
        return 1;
    }

    builtin.print("PASS: protocol buffer");
    return 0;
}
