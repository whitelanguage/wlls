// growable byte buffer used by protocol encoders
extern "C" {
    func wl_alloc_string(size -> Long) -> String;
    func wl_string_set_length(value -> String, length -> Int) -> Void;
}

const MAX_BUFFER_CAPACITY -> Int = 268435456;

func __buffer_data(value -> String) -> AnyPtr {
    if (value is null) { return nullptr; }
    let ptr fields -> AnyPtr = AnyPtr(value);
    return fields[0];
}

class ByteBuffer {
    let storage -> String;
    let length -> Int;
    let capacity -> Int;

    init(initial_capacity -> Int) {
        if (initial_capacity < 16) { initial_capacity = 16; }
        if (initial_capacity > MAX_BUFFER_CAPACITY) { initial_capacity = MAX_BUFFER_CAPACITY; }
        self.storage = wl_alloc_string(Long(initial_capacity));
        self.length = 0;
        self.capacity = initial_capacity;
        if (self.storage is !null) { wl_string_set_length(self.storage, 0); }
    }

    method __reserve(additional -> Int) -> Bool {
        if (additional < 0 || self.length > MAX_BUFFER_CAPACITY - additional) { return false; }
        let required -> Int = self.length + additional;
        if (required <= self.capacity) { return true; }
        let next_capacity -> Int = self.capacity;
        while (next_capacity < required) {
            if (next_capacity > MAX_BUFFER_CAPACITY / 2) {
                next_capacity = MAX_BUFFER_CAPACITY;
                break;
            }
            next_capacity *= 2;
        }
        if (next_capacity < required) { return false; }
        let replacement -> String = wl_alloc_string(Long(next_capacity));
        if (replacement is null) { return false; }
        let ptr source -> Byte = __buffer_data(self.storage);
        let ptr target -> Byte = __buffer_data(replacement);
        let i -> Int = 0;
        while (i < self.length) {
            target[i] = source[i];
            i += 1;
        }
        wl_string_set_length(replacement, self.length);
        self.storage = replacement;
        self.capacity = next_capacity;
        return true;
    }

    method write_byte(value -> Byte) -> Bool {
        if (!self.__reserve(1)) { return false; }
        let ptr output -> Byte = __buffer_data(self.storage);
        output[self.length] = value;
        self.length += 1;
        return true;
    }

    method write(value -> String) -> Bool {
        if (value is null || !self.__reserve(value.length())) { return false; }
        let ptr source -> Byte = __buffer_data(value);
        let ptr output -> Byte = __buffer_data(self.storage);
        let i -> Int = 0;
        while (i < value.length()) {
            output[self.length + i] = source[i];
            i += 1;
        }
        self.length += value.length();
        return true;
    }

    method write_uint(value -> Int) -> Bool {
        if (value < 0) { return false; }
        if (value == 0) { return self.write_byte(Byte(48)); }
        let divisor -> Int = 1;
        while (value / divisor >= 10) {
            if (divisor > 100000000) { break; }
            divisor *= 10;
        }
        while (divisor > 0) {
            if (!self.write_byte(Byte(48 + (value / divisor) % 10))) { return false; }
            divisor /= 10;
        }
        return true;
    }

    method finish() -> String {
        if (self.storage is null) { return null; }
        wl_string_set_length(self.storage, self.length);
        return self.storage;
    }
}
