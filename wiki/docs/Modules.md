---
sidebar_position: 2
---

# Built-in modules in WOS
This page is manually transcribed. Report any outdated info in issues!

## coordinates
Used to create the <code>coordinates</code> class.

### Related types
- _Coordinate_: {UniverseCoordinates: _Vector2_, SolarCoordinates: _Vector2_, ...}
- _CoordinateBounds_: {_Vector2_, _Vector2_, _Vector2_, _Vector2_}

### Methods
- **new**(_number_ UniverseCoordinatesX, _number_ UniverseCoordinatesY, _number_ SolarCoordinatesX, _number_ SolarCoordinatesY, _boolean_ inPlanet) → _Coordinate_
- **fromVector**(_Vector2_ UniverseCoordinates, _Vector2_ SolarCoordinates, _boolean_ inPlanet) → _Coordinate_
- **withBounds**(_CoordinateBounds_ CoordinateBounds, _number_ UniverseCoordinatesX, _number_ UniverseCoordinatesY, _number_ SolarCoordinatesX, _number_ SolarCoordinatesY, _boolean_ inPlanet) → _Coordinate_
- **fromString**(_string_ CoordinateString, _CoordinateBounds_ CoordinateBounds) → _Coordinate_

### Values
- _CoordinateBounds_ **DEFAULT_COORDINATE_BOUNDS**: The universe's coordinate bounds.
- _CoordinateBounds_ **NO_COORDINATE_BOUNDS**: No bounds. Unlimited.

### Example usage
```lua
local Hyperdrive = GetPart("HyperDrive")
local Coordinates = require("coordinates")
Hyperdrive.Coordinates = Coordinates.fromVector(
   Vector2.new(1, 1), -- sector coords
   Vector2.new(1, 1), -- planet coords
   false -- inside planet?
)
```

## fs
?

## nature2d
Nature2D module. [Learn more about it here](https://jaipack17.github.io/Nature2D/)

## octree
Octree module. [Learn more about it here](https://quenty.github.io/NevermoreEngine/api/Octree/)

## partdata
This module returns a table of components & parts. TBD

## players
This module is used to convert roblox usernames to userids and the other way around.

### Methods
- **:GetUsername**(_number_ userid) → _string_ username
- **:GetUserId**(_string_ username) → _number_ userid

## promise
Promise module. [Learn more about it here](https://eryn.io/roblox-lua-promise/)

## repr
This module returns a function which when passed to it, it prints the table with formatting.
```lua
local repr = require("repr")
print(repr({"hi"})) -- {"hi"}
```

## signal
Signal module. [Learn more about it here](https://devforum.roblox.com/t/lua-signal-class-comparison-optimal-goodsignal-class/1387063)

## symbol
This module returns a function which converts a string to a <code>symbol</code> (internally a _UserData_)
```lua
local symbol = require("symbol")
print(symbol("MySignal")) -- Symbol<MySignal>
```

## tableUtil
tableUtil module. [Learn more about it here](https://sleitnick.github.io/RbxUtil/api/TableUtil/)

## trove
trove module. [Learn more about it here](https://sleitnick.github.io/RbxUtil/api/Trove/)

## sift
sift module. [Learn more about it here](https://github.com/cxmeel/sift)
