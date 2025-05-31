.. \_simiflight\_topics\_overview:

SimiFlight – System Overview and Planning Topics
================================================


This document lists key topics, features, and systems relevant to the design and development of the SimiFlight simulator. It serves as a central planning reference and will be expanded and prioritized as development continues.

---

Flight Physics & Aerodynamics
-----------------------------


* Lift and Drag curves based on angle of attack (Alpha)
* Center of pressure shift (especially for delta wings)
* Vortex lift modeling for high-Alpha performance
* Modular WingSections per aircraft
* Dynamic control surfaces: canards, slats, flaps
* Ground handling without physics-based wheels
* Nose gear steering via lateral ground force
* Relative airflow computation from motion and wind
* Multiple propulsion types: propeller, jet, rocket

World & Environment
-------------------


* Spherical planetary world
* Large-scale coordinate system with 64-bit support
* Floating origin system for precision
* Global/local wind system
* Gusts and turbulence (randomized)
* Thermal zones (volumetric updrafts)
* Orographic lift simulation (advanced)
* Humidity and air density (optional)
* Temperature model (for thermals and engine efficiency)

Propulsion & Aircraft Systems
-----------------------------


* Thrust-based propulsion forces
* Engine definitions per type (prop, jet, rocket)
* Thrust vectoring support
* Fuel system and center-of-gravity impact
* Optional engine startup sequences

Flight Control & Input
----------------------


* Manual control surfaces mapping (elevator, aileron, rudder)
* Optional autopilot / assist systems
* Controller input abstraction (joystick, keyboard, etc.)
* Per-aircraft control logic
* Trim systems for fine-tuned input

Simulation & Debugging
----------------------


* Visualization of forces and lift points
* Flight data logging for testing
* GodPlot or custom graphing tools
* Frame-stepped simulation mode
* Replay or timeline system (future feature)

Collision & Damage Modeling
---------------------------


* G-force structural limits and failures
* Stall/spin behavior and recovery
* Gear damage from hard landings
* Damage influencing flight behavior

Architecture & Modularity
-------------------------


* Clean Code principles (e.g. SRP)
* Signal-based module communication
* Modular systems: aircraft, environment, logic
* Plug-in architecture for modding support
* Configurable aircraft definitions (e.g. YAML/JSON)
* Maintained Sphinx-based documentation

Tools & Editor Extensions
-------------------------


* Curve editor for aerodynamic curves
* Aircraft configuration editor
* Terrain-based tool for thermal zone prediction
* In-game debug console (e.g. GameConsole plugin)
* Extended Godot inspector integration

Gameplay and Features (Later)
-----------------------------


* Mission framework or sandbox scenarios
* Training mode / flight school
* Time trials, races, and challenge modes
* Amphibious / seaplane support
* Multiplayer and shared world (low priority)
* AI aircraft with support for civil, racing, and combat behaviors
* Combat systems: weapons, ground targets, destructible structures
* Ground vehicles and civilian traffic (optional)
* Wildfire simulation and water-drop mechanics for CL-415
* Living world elements: trains, road traffic, bridges, interactive infrastructure

---

This list serves as a living reference and can be updated as new systems are introduced or priorities shift. Each topic may link to its own dedicated documentation file over time.
