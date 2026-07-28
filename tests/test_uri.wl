// Test: LSP_FILE_URI
// File: tests/test_uri.wl
// Focus: UTF-8 percent encoding and Windows/POSIX file URI conversion.
import "builtin"
import "../internal/protocol/_pkg.wl" as protocol

func main() -> Int {
    let windows_uri -> String = "file:///F:/White%20Language/%E4%B8%AD.wl";
    let windows_path -> String = protocol.uri_to_path(windows_uri);
    if (windows_path != "F:/White Language/中.wl" || protocol.path_to_uri(windows_path) != windows_uri) {
        builtin.print("FAIL: Windows file URI");
        return 1;
    }

    let posix_path -> String = "/tmp/White Language/main.wl";
    let posix_uri -> String = "file:///tmp/White%20Language/main.wl";
    if (protocol.path_to_uri(posix_path) != posix_uri || protocol.uri_to_path(posix_uri) != posix_path) {
        builtin.print("FAIL: POSIX file URI");
        return 1;
    }

    builtin.print("PASS: LSP file URI");
    return 0;
}
