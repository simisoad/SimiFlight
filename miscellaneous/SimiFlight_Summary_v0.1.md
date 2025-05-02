# SimiFlight Project Summary (v0.1)

**Version:** 0.1 • Initial draft

## 1. Project Overview

- Goal: Build a modular flight simulator (SimiFlight) in Godot Engine 4.4 with realistic flight physics, a GUI curve tool for lift and drag calculation, and external Python computation.
- Technologies:
  - Godot 4.4 for simulation and GUI
  - GDExtensions in C++ for performance-critical physics
  - Python 3.x for external curve generation and advanced calculations
  - Optional use of tool scripts in GDScript for editor-driven UI creation

## 2. Repository Structure

SimiFlight/
  simiflight-curvetool/
    Godot/        # GUI frontend (CurveToolUI scene and script)
    Python/       # Python scripts for lift and drag calculations
  Godot/         # Main simulator project (C++ and GDScript)
  Python/        # Shared physics modules and utilities
  docs/          # Documentation

## 3. Curve Tool (Lift and Drag Generator)

- Purpose: Generate lift and drag curves for airfoil profiles under variable angles of attack and Mach numbers.
- Approaches:
  1. Semi-empirical model using thin airfoil theory, empirical stall corrections, and compressibility adjustments for Mach effects.
  2. Panel method for 2D potential flow with separate stall model for detailed subsonic results.
- Implementation:
  - Python scripts in the Python folder, called by Godot via Process execution or HTTP.
  - Inputs: angle range, profile parameters, Mach number.
  - Outputs: JSON or CSV files containing the curve data.
  - Godot UI script uses tool annotation to build controls in the editor.

## 4. Godot and Python Integration

- External process call: Godot executes Python scripts and reads standard output.
- HTTP approach: local Flask or FastAPI server, Godot sends requests and receives JSON responses.
- Editor workflow: tool scripts generate UI nodes at edit time, then saved as scenes for visual editing.

## 5. Flight Physics Engine (Godot + C++)

- Core forces: lift, drag, weight, thrust.
- Data input: precomputed tables for lift and drag coefficients by angle and Mach.
- Force application: apply forces at multiple wing control points using Godot physics or custom C++ integration.
- Mach effects: apply Prandtl-Glauert correction up to Mach 0.85 and simple wave drag increase beyond.

## 6. GUI Layout Strategies

- Editor-driven layout with containers (VBox, HBox, Grid) for responsive design.
- Code-driven initial UI generation using @tool scripts, then save scenes for further visual refinement.
- Use anchors and margins to center panels and scale to different window sizes.

## 7. Development Roadmap

1. Python curve tool prototype: implement lift and drag formulas, Mach correction, and export logic.
2. Godot curve tool UI: attach tool script, generate inputs and buttons, wire Python calls.
3. Prototype simulator: simple 3D aircraft, load curve data, apply forces, visualize vectors.
4. Performance optimization: port physics loop to C++ via GDExtensions, multi-thread if needed.
5. Documentation: detailed READMEs, sample data, test scenes, and user guides.

## 8. Best Practices and Tips

- Keep modules separate: UI, physics core, data I/O.
- Use Git branches and versioned releases for milestones.
- Provide example curve files for quick testing.
- Profile simulation performance and adjust update loops accordingly.

*This summary collects all proposed ideas and solutions for your SimiFlight project. Use it as a living document and update as you progress.*
