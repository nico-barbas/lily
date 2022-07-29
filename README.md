# Lily, a small scripting language

:warning: This project is still in early development :warning:

A small scripting language somewhere between Lua and (Object)Pascal, with some inspiration from Ada.

```lua
type Entity is class
    id: number
    active: bool
    x: number
    y: number

    constructor new(_id: number, _x: number, _y: number):
        self.id = _id
        self.x = _x
        self.y = _y
    end

    fn update():
        self.x += 1
    end
end

var myEntity = Entity.new(0, 10, 25)
myEntity.update()
```

* Lily is small and meant to embedded in other applications.
* Lily is straightforward and has a small cherry picked set of features.
* Lily support classes and Object orientation. 
* Lily is typed.

## Basics:
```lua
-- A variable named foo of type 'number'.
var foo: number = 10
-- The type of a variable can be infered at compile time.
var bar = false -- is of type 'bool'

-- assignment operators:
foo += 1
foo -= 4
foo *= 0.25
foo /= 3

-- More builtin types:
-- Strings are managed by the VM, are immutable and are dynamically allocated.
var str: string = "Hello world!"
-- Arrays are also managed by the VM and are dynamically allocated.
-- They are also growable.
var myArray = array of number[1, 4, 9]
myArray.append(9)
myArray.length()
-- Maps are associative arrays (managed and dynamically allocated).
-- As expected, inserting a new element or retrieving one is done by indexing into
-- the map with a key of the given type.
var myMap = map of (string, number)["foo" = 11, "bar" = 4]
myMap["foobar"] = 62
var mapValue = myMap["foo"]

-- Control flow:
var foobar: number
if true:
    foobar = 2
else:
    foobar = 3
end

for i in 0..<10:
    foobbar = foobar + 1
end

match foobar:
    when 1:

    end
    when 2:
    
    end
    when 3:

    end
end

-- Functions declaration and calling:
fn add(a: number, b: number): number
    result = a + b
end
var addResult = add(5, 10)

-- Foreign function declaration:
foreign fn sub(a: number, b: number): number

-- Class declaration:
type Vector is class
    x: number
    y: number

    constructor new():
    end
end

-- Enumeration declaration:
type Foo is enum
    Bar
    Baz
end

var fooVal = Foo.Bar
```

## Status and Roadmap:
- [ ] Memory management (either GC or RC)
- [x] Zero initialize class fields
- [x] += (and others) assignment operators
- [x] Control flow
    - [x] If statement
    - [x] For statement
    - [x] Match statement
    - [x] 'break' statement
    - [x] 'continue' statement
- [ ] Container iterators
- [x] Array Type
- [x] Array builtin procedures 
- [x] Map Type
- [ ] Map builtin procedures 
- [x] Custom functions
- [ ] Custom Type Alias
- [x] Custom Class Types
- [x] Class constructors
- [x] Class methods
- [ ] Custom Enumeration types
- [ ] Custom ADTs
- [x] Modules
- [x] Dot chaining
- [x] Immutable function parameters
- [ ] Variadic function parameters
- [x] Foreign functions
- [ ] Minimal standard library
- [ ] Full test suite
    - [x] Lexer
    - [ ] Parser :: 80%
    - [ ] Checker
    - [ ] Compiler
    - [ ] VM

## Known Bugs:
- User defined foreign fn declaration are not supported in the standalone compiler and should be disallowed
- Many, many compiler memory leaks (will be fixed very soon)
- Fix symbol table overflow

<!-- ## Dot operator rules:

- **`Right-handside Dot expression`** => | `Left Dot Operand` | . | `Selector Dot Operand` |
    - `Left Dot Operand` =>  | `Module Name` | `Class Name` | `Variable Name` | `Call Expression` | `Index Expression` |
    - `Selector Dot Operand` => `Class Name` | `Variable Name` | `Call Expression` | `Chained Selector` |
    - `Chained Selector` => | `Chained Selector` | . | `Call Expression` | `Field Name` | `Index Expression` |
    - `Chained Selector` => `Call Expression` | `Field Name` | `Index Expression` | -->


<!-- - **`Left-handside Dot expression`** => | `Left Dot Operand` | . | `Selector Dot Operand` |
    - `Left Dot Operand` =>  | `Module Name` | `Variable Name` | `Call Expression` | `Index Expression` |
    - `Selector Dot Operand` => `Variable Name` | `Chained Selector` |
    - `Chained Selector` => | `Chained Selector` | . | `Call Expression` | `Field Name` | `Index Expression` |
    - `Chained Selector` => `Call Expression` | `Field Name` | `Index Expression` | -->
