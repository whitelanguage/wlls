// growable byte buffer used by protocol encoders
import "strings"

const MAX_BUFFER_CAPACITY -> Int = 268435456;

class ByteBuffer {
    let builder -> strings.Builder;

    init(initial_capacity -> Int) {
        if (initial_capacity < 16) { initial_capacity = 16; }
        if (initial_capacity > MAX_BUFFER_CAPACITY) { initial_capacity = MAX_BUFFER_CAPACITY; }
        self.builder = strings.Builder(initial_capacity);
    }

    method __can_write(additional -> Int) -> Bool {
        return additional >= 0 && self.builder.length() <= MAX_BUFFER_CAPACITY - additional;
    }

    method write_byte(value -> Byte) -> Bool {
        if (!self.__can_write(1)) { return false; }
        self.builder.write_byte(value)?;
        catch(err) { return false; }
        return true;
    }

    method write(value -> String) -> Bool {
        if (value is null || !self.__can_write(value.length())) { return false; }
        self.builder.write(value)?;
        catch(err) { return false; }
        return true;
    }

    method write_uint(value -> Int) -> Bool {
        if (value < 0) { return false; }
        let digits -> Int = 1;
        let remaining -> Int = value;
        while (remaining >= 10) {
            digits += 1;
            remaining /= 10;
        }
        if (!self.__can_write(digits)) { return false; }
        self.builder.write_int(value)?;
        catch(err) { return false; }
        return true;
    }

    method finish() -> String {
        let result -> String = self.builder.build()?;
        catch(err) { return null; }
        return result;
    }
}
