AI System Overview – SimiFlight
===============================


This document outlines the concepts and architecture for integrating AI-controlled aircraft in the SimiFlight simulator. The AI system is modular and designed to scale from simple path-following behavior to complex dogfight and BVR combat logic.

---

Core Concept
------------


The aircraft AI is built on a perception-decision-action cycle:

1. **Perception** – Senses the environment (targets, threats, terrain)
2. **Decision Making** – Chooses an action (follow, attack, evade, patrol)
3. **Execution** – Adjusts flight controls to carry out the action

---

Modular Architecture
--------------------


.. code-block:: text

```
[ PilotAI ]         ← High-level logic (objectives, combat, racing)
     ↓
[ FlightBrain ]     ← Low-level flight controller (heading, pitch, roll, throttle)
     ↓
[ Aircraft Model ]  ← Physics engine + aerodynamics
```

* **PilotAI**: Controls strategic/tactical decisions.
* **FlightBrain**: Converts intentions into physical control surface changes.
* **Aircraft Model**: Simulates aircraft movement and response.

This separation allows reuse and testing of each component independently.

---

AI Types (Progressive Development)
----------------------------------


1. **Target Dummy AI** – Static or very simple scripted flight
2. **Path-Following AI** – Navigation through waypoints or race track
3. **Passenger/Civilian AI** – Flies defined routes with altitude/speed profile
4. **Racing AI** – Competes along a course, optimizes lap time
5. **Dogfight AI** – Chases, evades, and attacks players or other AI
6. **BVR AI** – Beyond-visual-range tactics, radar usage, missile logic
7. **Formation AI** – Wingman behavior, tactical formations

---

Core AI Behaviors
-----------------


* Chase target
* Evade or retreat
* Maintain speed and energy
* Stay within flight envelope
* Predict target motion (lead)
* Maintain line of sight or missile lock

---

Design Patterns & Tools
-----------------------


* **Finite State Machine (FSM)** – Simple behavior switching
* **Behavior Tree** – Modular complex decision structures
* **Blackboard System** – Shared memory for AI reasoning
* **PID Controllers** – Smooth input transitions (throttle, pitch, etc.)
* **Debug Tools** – Visualize paths, target lines, status labels

---

Simplified AI Flight Model
--------------------------


AI aircraft may use a reduced-physics model:

* Directly set heading, pitch rate, climb angle
* No full aerodynamic simulation required
* Easier tuning and less CPU load

Can still integrate into main simulation pipeline for consistency.

---

Future Considerations
---------------------


* Personality traits (aggressive, cautious, erratic)
* Voice & radio comms (immersion)
* Scenario scripting interface for custom AI missions
* Multiplayer integration (AI vs. player or coop missions)

---

Development Strategy
--------------------


Start small:

* Begin with civilian waypoint AI or racing opponents
* Expand toward combat and advanced maneuvering

By separating FlightBrain from PilotAI, each behavior layer can evolve independently and be reused across aircraft.

This document will evolve alongside the AI system in SimiFlight.
