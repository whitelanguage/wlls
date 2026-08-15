// Test: LSP_FILE_URI
// File: tests/test_uri.wl
// Focus: UTF-8 percent encoding and Windows/POSIX file URI conversion.
import "../internal/protocol/_pkg.wl" as protocol

func main() -> Int {
    let windows_uri: String = "file:///F:/White%20Language/%E4%B8%AD.wl";
    let windows_path: String = protocol.uri_to_path(windows_uri);
    if (windows_path != "F:/White Language/中.wl" || protocol.path_to_uri(windows_path) != windows_uri) {
        print("FAIL: Windows file URI");
        return 1;
    }

    let vscode_uri: String = "file:///f%3A/White%20Language/%E4%B8%AD.wl";
    if (protocol.uri_to_path(vscode_uri) != windows_path) {
        print("FAIL: percent-encoded Windows drive");
        return 1;
    }

    let posix_path: String = "/tmp/White Language/main.wl";
    let posix_uri: String = "file:///tmp/White%20Language/main.wl";
    if (protocol.path_to_uri(posix_path) != posix_uri || protocol.uri_to_path(posix_uri) != posix_path) {
        print("FAIL: POSIX file URI");
        return 1;
    }

    let unc_path: String = "//server/share/White Language/main.wl";
    let unc_uri: String = "file://server/share/White%20Language/main.wl";
    if (protocol.path_to_uri(unc_path) != unc_uri || protocol.uri_to_path(unc_uri) != unc_path) {
        print("FAIL: UNC file URI");
        return 1;
    }

    if (protocol.uri_to_path("file://localhost/tmp/main.wl") != "/tmp/main.wl" || protocol.uri_to_path("https://example.com/main.wl") is !null || protocol.uri_to_path("file:///tmp/bad%2.wl") is !null || protocol.uri_to_path("file:///tmp/bad%XZ.wl") is !null || protocol.uri_to_path("file:///tmp/bad%FF.wl") is !null) {
        print("FAIL: invalid file URI");
        return 1;
    }

    print("PASS: LSP file URI");
    return 0;
}
