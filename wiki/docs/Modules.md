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
