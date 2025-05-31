SimiFlight – Project Overview
=============================


Vision
------


SimiFlight aims to combine the physical realism of advanced flight simulators with the freedom and creativity of sandbox-style exploration games. It is designed to be engaging for enthusiasts of aviation physics while avoiding overly complex cockpit systems. The long-term goal is to simulate flight on a spherical world, respecting scientific accuracy and offering an immersive, scalable experience.

Personal Motivation
-------------------


* The name “SimiFlight” is derived from “Simon” in the Luzerner Hinterland dialect (“Simi”).
* Inspired by a lifelong passion for aviation and the experience of building a physical flight simulator prototype in Unreal Engine for the Matura thesis.
* Preference for realistic physics (e.g., DCS World) but without the complexity of full instrumentation.
* Strong desire to include a spherical world because a flat Earth is scientifically inaccurate.
* Deep emotional connection to certain aircraft, especially the Canadair CL-415 "Super Scooper", which has become a symbol of hope, precision, and airborne heroism.

Goals
-----


Realism
^^^^^^^


* Physics-based flight model including lift, drag, G-forces, and stalling behavior.
* Modular realism options: toggle simplified controls, auto-trim, wind effects, etc.
* No need to simulate every switch; focus is on flying, not cold-start procedures.
* Accurate aircraft behaviors based on airframe types (e.g., STOL, delta wings, heavy cargo jets).

World & Scale
^^^^^^^^^^^^^


* Full spherical planet (no flat terrain).
* Large-world coordinates with 64-bit precision for accurate global positioning.
* Floating origin technique to avoid precision errors far from origin.
* Dynamic level of detail and object culling.
* Potential integration of natural environments and weather systems (e.g., wind, updrafts, wildfires).

Gameplay
^^^^^^^^


* Game/simulator hybrid ("sim-lite").
* Freedom of exploration.
* Potential for missions, challenges, races, or delivery systems.
* Optional arcade elements: assistive HUDs, simplified physics, AI traffic, etc.
* Support for unique mission types like aerial firefighting (e.g., CL-415 operations).

Modding and Extensibility
^^^^^^^^^^^^^^^^^^^^^^^^^


* SimiFlight is being designed as a **modular, extensible simulator framework**.
* Focus on clear structure and scalability from the beginning.
* Aircraft, missions, and world elements are modular and plug-in based.
* Goal is to make it **easy for others to create mods**, from simple aircraft to complex avionics.
* Support for:

  * Aircraft plugins with physical models, 3D models, and sound packages.
  * Scripting API in Python, GDScript, or possibly Lua.
  * Sandbox mission editor with GUI.
  * Community mod folder and loader structure.

Software Architecture and Development Concepts
----------------------------------------------


Principles
^^^^^^^^^^


* **Clean Code**: readable, maintainable, testable
* **Single Responsibility Principle (SRP)**: each class/script has one job
* **Loose Coupling**: avoid hard dependencies, use interfaces and signals
* **High Modularity**: small, replaceable parts for aircraft, missions, systems
* **Ease of Extension**: mods and aircraft can be created by others

Proposed Project Structure
^^^^^^^^^^^^^^^^^^^^^^^^^^


```
res://
├── core/           # Core systems: Input, Config, Logger
├── physics/        # Flight physics, environment, forces
├── aircraft/       # Aircraft logic and definitions
├── systems/        # HUD, camera, missions
├── world/          # Terrain, fire systems, atmosphere
├── ui/             # User interface
├── scenes/         # Game scenes (menu, world, flight)
└── utils/          # General-purpose utilities
```

Communication Between Modules
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


* Use **signals** for event-driven communication
* Use **autoload singletons** for global systems (Input, WorldManager)
* Optional: central **EventBus** to dispatch global events

Code Structure Example (SRP)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^


For an aircraft:

```
Cessna.gd
├── FlightController.gd  → handles input
├── Aerodynamics.gd      → lift/drag calculations
├── Engine.gd            → thrust and fuel
├── Visual.gd            → visuals
```

Data-Driven Design
^^^^^^^^^^^^^^^^^^


Aircraft and config stored in external files (e.g., JSON):

```json
{
  "name": "CL-415",
  "mass": 12100,
  "engines": 2,
  "type": "turboprop",
  "lift_curve": "res://curves/cl415_lift.json"
}
```

```gdscript
var plane_data = load_json("res://aircraft/cl415/data.json")
plane.load_from_data(plane_data)
```

Testing
^^^^^^^


* Use **GUT** for unit tests (flight models, math functions, mission logic)
* Separate logic and rendering to allow headless testing

Aircraft Testing & Development Philosophy
-----------------------------------------


* Initial test aircraft will cover different aerodynamic profiles:

  * Cessna 172 (standard general aviation, low speed, propeller-driven)
  * Messerschmitt Bf-109 (WWII-era propeller aircraft)
  * Mirage III (delta wing supersonic jet – useful for stress-testing lift modeling)
* Long-term integration of the Canadair CL-415 as a dedicated aerial firefighting aircraft:

  * Amphibious water landing and scooping mechanics
  * Fire zone simulation with smoke, heat, and wind
  * Precision water drop mechanics
* Flexible physics to allow diverse aircraft types and roles.

Inspirations
------------


| Game                 | Why it's relevant                                                        |
| -------------------- | ------------------------------------------------------------------------ |
| DCS World            | Excellent flight physics, but too complex for casual gameplay.           |
| Kerbal Space Program | Blends science with fun; great handling of spherical worlds and physics. |
| Outerra              | Real spherical world with terrain streaming and flight.                  |
| SimplePlanes         | Physics-focused, sandbox-style flight.                                   |
| FlightGear           | Open-source flight simulator; useful for reference and data.             |

Development Tools
-----------------


* **Godot Engine**: Modified version for 64-bit precision and planetary rendering.
* **Python**: Used for external tools like the curve editor or aerodynamic modeling.
* **Markdown & PyCharm**: Project documentation and scripting.
* **GitHub**: Project hosting (`simiflight` repository), structured into sub-projects.
* **CLion / C++**: For performance-critical modules (e.g. physics engine)

Repository Structure
--------------------


```
simiflight/
├── Godot/                  # Main game project
├── simiflight-curvetool/  # Python GUI for aerodynamic curve editing
├── simiflight-docs/       # Markdown documentation
├── assets/                # 3D models, textures, sounds
└── README.md              # Project overview
```

---

This document is an evolving concept and early-stage idea collection for the SimiFlight project. It may contain duplicate ideas or inconsistent structure. A refactored and structured version will follow as the project matures.
