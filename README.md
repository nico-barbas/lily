# Lily, a small scripting language

A small scripting language somewhere between Lua and Pascal, with some inspiration from Ada.

```lua
type Entity is class
    id: number
    active: bool
    x: number
    y: number

    constructor(_id: number, _x: number, _y: number):
        id = _id
        x = _x
        y = _y
    end

    fn update():
        x += 1
    end
end

var myEntity = Entity(0, 10, 25)
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
-- Strings are managed by the VM and are dynamically allocated.
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
```