// JSON request adapter for the language server protocol
import "json"

class Request {
    let root -> json.Value;

    init(root -> json.Value) {
        self.root = root;
    }

    method int(name -> String, fallback -> Int) -> Int {
        let field -> json.Value = self.root.find(name);
        if (field is null) { return fallback; }

        let value -> Long = field.as_long()?;
        catch(err) { return fallback; }
        if (value < -2147483648L || value > 2147483647L) {
            return fallback;
        }

        let converted -> Int = Int(value)?;
        catch(err) { return fallback; }
        return converted;
    }

    method string(name -> String) -> String {
        let field -> json.Value = self.root.find(name);
        if (field is null) { return null; }

        let value -> String = field.as_string()?;
        catch(err) { return null; }
        return value;
    }

    method bool(name -> String, fallback -> Bool) -> Bool {
        let field -> json.Value = self.root.find(name);
        if (field is null) { return fallback; }
        let value -> Bool = field.as_bool()?;
        catch(err) { return fallback; }
        return value;
    }

    method object(name -> String) -> Request {
        let field -> json.Value = self.root.find(name);
        if (field is null || field.kind() != json.Kind.Object) { return null; }
        return Request(field);
    }

    method array(name -> String) -> json.Value {
        let field -> json.Value = self.root.find(name);
        if (field is null || field.kind() != json.Kind.Array) { return null; }
        return field;
    }

    method raw(name -> String, fallback -> String) -> String {
        let field -> json.Value = self.root.find(name);
        if (field is null) { return fallback; }
        let encoded -> String = json.encode(field)?;
        catch(err) { return fallback; }
        return encoded;
    }

    method contains(name -> String) -> Bool {
        return self.root.contains(name);
    }

    method valid_id() -> Bool {
        let field -> json.Value = self.root.find("id");
        if (field is null || field.kind() == json.Kind.Null) { return true; }
        return field.kind() == json.Kind.Text || field.kind() == json.Kind.Number;
    }
}

func decode_request(message -> String) -> Request? {
    let root -> json.Value = json.decode(message)?;
    if (root.kind() != json.Kind.Object) {
        throw json.JsonError.TypeMismatch;
    }
    return Request(root);
}

func quote(value -> String) -> String {
    // protocol strings have already passed UTF-8 validation during request decoding
    let encoded_value -> json.Value = json.string(value)?;
    catch(err) { return "null"; }
    let encoded -> String = json.encode(encoded_value)?;
    catch(err) { return "null"; }
    return encoded;
}
