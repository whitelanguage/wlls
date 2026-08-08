// in-memory documents owned by one language server session
import Dict from "dict"
import "../frontend/_pkg.wl" as source

class Document {
    let path -> String;
    let version -> Int;
    let text -> String;
    let result -> source.FrontendResult;

    init(path -> String, version -> Int, text -> String, result -> source.FrontendResult) {
        self.path = path;
        self.version = version;
        self.text = text;
        self.result = result;
    }
}

class Workspace {
    let documents -> Dict;
    let frontend -> source.FrontendWorkspace;

    init() {
        self.documents = Dict(16);
        self.frontend = source.FrontendWorkspace();
    }

    method find(path -> String) -> Document {
        return self.documents[source.normalize_source_path(path)];
    }

    method open(path -> String, version -> Int, text -> String) -> Document {
        let normalized -> String = source.normalize_source_path(path);
        let document -> Document = self.find(normalized);
        if (document is !null && version <= document.version) { return document; }
        let result -> source.FrontendResult = self.frontend.update(normalized, version, text);
        if (document is null) {
            document = Document(normalized, version, text, result);
            self.documents.put(normalized, document);
        } else {
            document.version = version;
            document.text = text;
            document.result = result;
        }
        return document;
    }

    method close(path -> String) -> Bool {
        let normalized -> String = source.normalize_source_path(path);
        if (!self.documents.contains_key(normalized)) { return false; }
        self.documents.remove(normalized);
        self.frontend.remove(normalized);
        return true;
    }

    method is_open(path -> String) -> Bool {
        return self.documents.contains_key(source.normalize_source_path(path));
    }

    method is_indexed(path -> String) -> Bool {
        return self.frontend.find(path) is !null;
    }

    method invalidate(path -> String) -> Bool {
        let normalized -> String = source.normalize_source_path(path);
        if (self.documents.contains_key(normalized)) { return false; }
        return self.frontend.remove(normalized);
    }
}
