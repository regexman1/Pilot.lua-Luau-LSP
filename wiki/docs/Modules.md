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
