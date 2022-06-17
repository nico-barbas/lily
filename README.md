# Lily, a small scripting language

A small scripting language somewhere between Lua and Pascal, with some inspiration from Ada.

```lua
type Entity is class
    id: number
    active: bool
    x: number
    y: number

    constructor new(_id: number, _x: number, _y: number):
        id = _id
        x = _x
        y = _y
    end

    fn update():
        x += 1
    end
end

var myEntity = Entity.new(0, 10, 25)
myEntity.update()
```

* Lily is small and meant to embedded in other applications.
* Lily is straightforward and has a small cherry picked set of features.
* Lily support classes and Object orientation. 

## Basics:
```lua
-- A variable named foo of type 'number'.
var foo: number = 10
-- The type of a variable can be infered at compile time.
var bar = false -- is of type 'bool'

-- More builtin types:
-- Strings are managed by the VM, are immutable and are dynamically allocated.
var str: string = "Hello world!"
-- Arrays are also managed by the VM and are dynamically allocated.
-- They are also growable.
var myArray = array of number[1, 4, 9]
myArray.append(9)
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

-- Functions declaration and calling:
fn add(a: number, b: number): number
    result = a + b
end
var addResult = add(5, 10)
```

## Status and Roadmap:
- [ ] += (and others) assignment operatros
- [x] Control flow
- [ ] Container iterators
- [x] Array Type
- [ ] Map Type
- [x] Custom functions
- [x] Custom Types
- [x] Custom Class Types
- [x] Class constructors
- [x] Class methods
- [ ] Modules
    - [x] Parsing
    - [ ] Checking
    - [ ] Compiling
- [ ] Minimal standard library
- [ ] Full test suite
    - [x] Lexer
    - [ ] Parser :: 50%
    - [ ] Checker
    - [ ] Compiler
    - [ ] VM
