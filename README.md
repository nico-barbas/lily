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

## Notes:
- Class fields are zero initialized
- Function parameters are immutables
- At the moment, every trace allocation is done via `os.heap_allocator`

## Status and Roadmap:
### Control flow:
- [x] If statement
- [x] For statement
- [x] Match statement
- [x] 'break' statement
- [x] 'continue' statement
### Builtin types:
- [x] Array Type
- [x] Array builtin procedures 
- [x] Map Type
- [ ] Map builtin procedures 
### User defined types:
- [x] Functions
- [ ] Type Alias
- [x] Class Types
- [x] Enumeration Types
- [ ] ADTs
- [ ] Ranges
### Memory Management:
- [x] Extremely simple mark-and-sweep GC
- [ ] Escape analysis and scoped allocation
- [ ] Custom class allocator for faster instanciation
### Embedding features:
- [x] Foreign functions declaration in Lily source code
- [x] Lily Function handles capture in host application
- [x] Safe (sortof) VM stack manipulation
### Minimal standard library:
- [x] Print
- [x] String conversion (super hacky)
- [x] A few common math procedures
### Full test suite:
- [x] Lexer
- [ ] Parser :: 80%
- [ ] Checker
- [ ] Compiler
- [ ] VM

### Features TODO:
- [x] Most common assignment operators (=, +=, -=, *=, /=)
- [ ] Container iterators
- [x] Modules
- [ ] Variadic function parameters
- [x] Nil check on ref types
- [ ] Coroutine and builtin green threads

## Tooling:
- [x] lily (Standalone compiler/interpreter)
- [x] lilyfmt: Functioning but very simple
    - [x] Source code handling => On par with compiler features [07/08/2022]
    - [ ] Comment handling 
    - [ ] Can disable regions
- [ ] lilycheck


## Known Bugs:
- User defined foreign fn declaration are not supported in the standalone compiler and should be disallowed
- Unable to compile multiple modules separately in host application
- Fix symbol table overflow
