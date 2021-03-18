#include "script_component.hpp"
/*
 * Author: marc_book, commy2, CAA-Picard
 * Unload and paradrop object from plane or helicopter.
 *
 * Arguments:
 * 0: Object <OBJECT>
 * 1: Vehicle <OBJECT>
 * 2: Show Hint <BOOL> (default: true)
 *
 * Return Value:
 * Object unloaded <BOOL>
 *
 * Example:
 * [object, vehicle] call ace_cargo_fnc_paradropItem
 *
 * Public: No
 */

params ["_item", "_vehicle", ["_showHint", true]];
TRACE_2("params",_item,_vehicle);

private _loaded = _vehicle getVariable [QGVAR(loaded), []];

if !(_item in _loaded) exitWith {false};

// unload item from cargo
_loaded deleteAt (_loaded find _item);
_vehicle setVariable [QGVAR(loaded), _loaded, true];

private _cargoSpace = [_vehicle] call FUNC(getCargoSpaceLeft);
private _itemSize = [_item] call FUNC(getSizeItem);
_vehicle setVariable [QGVAR(space), (_cargoSpace + _itemSize), true];

private _typeOfCargo = if (_item isEqualType "") then {_item} else {typeOf _item};

// keep additional space between both vehicles
private _safetyDistance = 20;

// find safe position behind transporter
(boundingBoxReal _vehicle) params ["_transporter_bb1", "_transporter_bb2"];
private _distToBackLimit = (_transporter_bb1 select 1) min (_transporter_bb2 select 1);

// temporarily create vehicle to get physical size of it (at least one has to exist on map somewhere)
private _vec = createVehicle [_typeOfCargo, [(random 100) - 50, (random 100) - 50, 1000 + random 100], [], 0, "NONE"];
(boundingBoxReal _vec) params ["_cargo_bb1", "_cargo_bb2"];
private _distToFrontLimit = (_cargo_bb1 select 1) max (_cargo_bb2 select 1);
deleteVehicle _vec;

// calculate position behind transporter with a safe distance
private _posBehindVehicleAGL = _vehicle modelToWorld [0, - (_distToFrontLimit - _distToBackLimit + _safetyDistance), -2];

private _itemObject = if (_item isEqualType objNull) then {
    detach _item;
    // hideObjectGlobal must be executed before setPos to ensure light objects are rendered correctly
    // do both on server to ensure they are executed in the correct order
    [QGVAR(serverUnload), [_item, _posBehindVehicleAGL]] call CBA_fnc_serverEvent;
    _item
} else {
    private _newItem = createVehicle [_item, _posBehindVehicleAGL, [], 0, "NONE"];
    _newItem setPosASL (AGLtoASL _posBehindVehicleAGL);
    _newItem
};

_itemObject setVelocity ((velocity _vehicle) vectorAdd ((vectorNormalized (vectorDir _vehicle)) vectorMultiply -5));

// open parachute and attach smoke shell
[{
    params ["_item"];

    if (isNull _item || {getPos _item select 2 < 1}) exitWith {};

    private _parachute = createVehicle ["B_Parachute_02_F", [0,0,0], [], 0, "CAN_COLLIDE"];

    // cannot use setPos on parachutes without them closing down
    _parachute attachTo [_item, [0,0,0]];
    detach _parachute;

    private _velocity = velocity _item;

    _item allowDamage false;
    _item attachTo [_parachute, [0,0,3]];
    _parachute setVelocity _velocity;

    private _smoke = "SmokeshellYellow" createVehicle [0,0,0];
    _smoke attachTo [_item, [0,0,0]];

    // delete smoke and repair vehicle when landed
    [{
        (_this select 0) params ["_item"];

        if (isNull _item) exitWith {
            [_this select 1] call CBA_fnc_removePerFrameHandler;
        };
        
        // vehicle landed?
        if ((getPos _item select 2) < 3 && (abs (velocity _item select 2)) < 0.2) then
        {
            // detach and delete all smokeshells
            { 
                if (typeOf _x == "SmokeshellYellow") then
                {
                    detach _x;
                    deleteVehicle _x;
                };
            } forEach attachedObjects _item;

            // repair + refuel
            _item setDamage 0;
            _item setFuel 1;
            _item allowDamage true;
            [_this select 1] call CBA_fnc_removePerFrameHandler;
        };
    }, 1, [_item]] call CBA_fnc_addPerFrameHandler;

}, [_itemObject], 0.7] call CBA_fnc_waitAndExecute;

if (_showHint) then {
    [
        [
            LSTRING(UnloadedItem),
            getText (configOf _itemObject >> "displayName"),
            getText (configOf _vehicle >> "displayName")
        ],
        3
    ] call EFUNC(common,displayTextStructured);
};

// Invoke listenable event
["ace_cargoUnloaded", [_item, _vehicle, "paradrop"]] call CBA_fnc_globalEvent;

true
