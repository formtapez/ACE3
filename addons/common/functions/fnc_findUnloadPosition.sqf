#include "script_component.hpp"
/*
 * Author: PabstMirror, ViperMaul
 * Find a safe place near a vehicle to unload something.
 * Handles Normal Terrain, In Water or On Buildings (Pier, StaticShip).
 *
 * Arguments:
 * 0: Source Vehicle <OBJECT>
 * 1: Cargo <OBJECT> or <STRING>
 * 2: Unloader (player) <OBJECT> (default: objNull)
 * 3: Max Distance (meters) <NUMBER> (default: 10)
 * 4: Check Vehicle is Stable <BOOL> (default: true)
 *
 * Return Value:
 * Unload PositionAGL (can Be [] if no valid pos found) <ARRAY>
 *
 * Example:
 * [theCar, "CAManBase", player, 10, true] call ace_common_fnc_findUnloadPosition
 *
 * Public: No
 */

params ["_vehicle", "_cargo", ["_theUnloader", objNull], ["_maxDistance", 50], ["_checkVehicleIsStable", true]];
TRACE_5("params",_vehicle,_cargo,_theUnloader,_maxDistance,_checkVehicleIsStable);

scopeName "main";

if (_checkVehicleIsStable) then {
    if (((vectorMagnitude (velocity _vehicle)) > 1.5) || {(!(_vehicle isKindOf "Ship")) && {(!isTouchingGround _vehicle) && {((getPos _vehicle) select 2) > 1.5}}}) then {
        TRACE_4("bad vehicle state",_vehicle,velocity _vehicle,isTouchingGround _vehicle,getPos _vehicle);
        [] breakOut "main";
    };
};

private _typeOfCargo = if (_item isEqualType "") then {_item} else {typeOf _item};

// keep additional space between both vehicles
private _safetyDistance = 5;

// find safe position behind transporter
(boundingBoxReal _vehicle) params ["_transporter_bb1", "_transporter_bb2"];
private _distToBackLimit = (_transporter_bb1 select 1) min (_transporter_bb2 select 1);

// temporarily create vehicle to get physical size of it (at least one has to exist on map somewhere)
private _vec = createVehicle [_typeOfCargo, [(random 100) - 50, (random 100) - 50, 1000 + random 100], [], 0, "NONE"];
(boundingBoxReal _vec) params ["_cargo_bb1", "_cargo_bb2"];
private _distToFrontLimit = (_cargo_bb1 select 1) max (_cargo_bb2 select 1);
deleteVehicle _vec;

// calculate position behind transporter with a safe distance
private _vecPos = _vehicle modelToWorld [0, - (_distToFrontLimit - _distToBackLimit + _safetyDistance), 0];
(_vecPos) breakOut "main";
