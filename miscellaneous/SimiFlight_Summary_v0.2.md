# SimiFlight – Project Overview (Combined Summary)
**Version:** 0.1 • Initial draft, expanded

## Vision & Project Overview  
- **Core Goal**: Build a modular flight simulator ("SimiFlight") in **Godot Engine 4.4** that blends realistic physics with sandbox-style exploration.  
- **Key Balance**: Physical realism (e.g., aerodynamics, spherical world) paired with casual gameplay (no complex cockpit systems).  
- **Long-Term Vision**: Simulate flight on a **scientifically accurate spherical planet** using scalable technical solutions like 64-bit coordinates and floating origin systems.  
- **Technologies**:  
  - Godot Engine (modified for 64-bit precision).  
  - C++ GDExtensions for performance-critical physics.  
  - Python 3.x for aerodynamic curve generation and external tools.  

---

## Personal Motivation  
- **Name Origin**: “SimiFlight” derives from “Simi” (Luzerner dialect for “Simon”).  
- **Inspiration**: Lifelong aviation passion + experience building a physical flight simulator prototype for a Matura thesis.  
- **Physics Preference**: Realistic flight dynamics (e.g., DCS World) without overwhelming complexity.  
- **Spherical World**: A rejection of flat Earth in simulations; inspired by *Kerbal Space Program* and *Outerra*.  

---

## Goals  

### Realism  
- Physics-based flight model: Lift, drag, G-forces, stalling, Mach effects (Prandtl-Glauert correction up to Mach 0.85).  
- Modular realism: Toggle simplified controls, auto-trim, wind effects, etc.  
- Focus on **flying**, not cockpit procedures (no cold-start simulations).  

### World & Scale  
- **Full spherical planet** with terrain streaming.  
- **64-bit floating-point precision** for global positioning.  
- Floating origin technique to mitigate precision errors.  
- Dynamic LOD (level of detail) and object culling.  

### Gameplay  
- Hybrid “sim-lite” experience: Mix simulator rigor with arcade freedom.  
- Exploration, missions, races, or delivery systems.  
- Optional assists: Simplified physics, AI traffic, HUD guides.  

---

## Technical Concepts  

### 1. Hybrid Precision World  
- Local rendering in standard engine coordinates.  
- Global positioning in `float64` for planetary-scale accuracy.  
- Floating origin system for stable physics far from the origin.  

### 2. Godot Engine Modifications  
- Custom Godot build with 64-bit support.  
- Workarounds for GPU double-precision limitations (shader hacks, fixed-function fallbacks).  

### 3. Flight Physics Engine  
- **Core Forces**: Lift, drag, weight, thrust (applied at wing control points).  
- **Data Input**: Precomputed aerodynamic tables (angle of attack, Mach number).  
- **Implementation**:  
  - Prototype in GDScript, optimize via C++ GDExtensions.  
  - Multi-threading for performance-critical tasks.  

### 4. Curve Tool (Aerodynamic Modeling)  
- **Purpose**: Generate lift/drag curves for airfoils under variable angles of attack and Mach numbers.  
- **Methods**:  
  - Semi-empirical model (thin airfoil theory + stall corrections).  
  - Panel method for 2D potential flow.  
- **Integration**:  
  - Python scripts called by Godot via HTTP (Flask/FastAPI) or process execution.  
  - Godot UI built with `@tool` scripts for editor-driven design.  

### 5. Godot-Python Integration  
- **Workflows**:  
  - External process calls (Godot ↔ Python stdout).  
  - HTTP API for real-time data exchange.  

---

## Development Tools  
- **Godot Engine**: Customized for planetary rendering and 64-bit physics.  
- **Python**: Aerodynamic modeling, curve generation, and external tools.  
- **C++**: GDExtensions for high-performance physics.  
- **GitHub**: Hosting for `simiflight` repository with sub-projects.  
- **Documentation**: Markdown (PyCharm + GitHub).  

---

## Repository Structure (Combined)  
```plaintext
simiflight/  
├── Godot/                  # Main project (C++/GDScript, physics, scenes)  
├── simiflight-curvetool/   # Aerodynamic curve generator  
│   ├── Godot/             # CurveTool UI (Godot scenes and scripts)  
│   └── Python/            # Python backend (lift/drag calculations)  
├── assets/                # 3D models, textures, sounds  
├── docs/                  # Documentation (Markdown, user guides)  
├── Python/                # Shared physics utilities (optional)  
└── README.md              # Combined project overview  
```

---

## Inspirations  
| Game                 | Relevance                                                                 |  
|----------------------|---------------------------------------------------------------------------|  
| DCS World            | Flight physics benchmark, but overly complex for casual play.             |  
| Kerbal Space Program | Spherical worlds + playful science.                                      |  
| Outerra              | Planetary-scale terrain streaming.                                       |  
| SimplePlanes         | Sandbox flight with physics focus.                                       |  
| FlightGear           | Open-source reference for flight data and systems.                        |  

---

## Development Roadmap  
1. **Prototype Curve Tool**: Python backend + Godot UI.  
2. **Physics Core**: Implement forces, load curve data, test in 3D.  
3. **Spherical World**: Integrate 64-bit coordinates and floating origin.  
4. **Optimization**: Port physics to C++, profile performance.  
5. **Gameplay Systems**: Add missions, challenges, and assists.  
6. **Documentation**: Write user guides, example scenes, and API references.  

---

## Best Practices  
- **Modularity**: Separate UI, physics, and data modules.  
- **Version Control**: Use Git branches for features/experiments.  
- **Testing**: Provide sample curve files and test scenes.  
- **Performance**: Profile update loops; prioritize GPU/CPU bottlenecks.  

---

*Combined from v0.1 and v0.2 summaries. Update as needed!* 🚀