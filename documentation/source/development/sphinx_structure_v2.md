===================
Repository Structure
===================

This page details the organization of the SimiFlight project repository.

Top-Level Structure
==================

.. code-block:: text

   simiflight/  
   ├── Godot/                  # Main project (C++/GDScript, physics, scenes)  
   ├── simiflight-curvetool/   # Aerodynamic curve generator  
   │   ├── Godot/             # CurveTool UI (Godot scenes and scripts)  
   │   └── Python/            # Python backend (lift/drag calculations)  
   ├── assets/                # 3D models, textures, sounds  
   ├── docs/                  # Documentation (Sphinx format)  
   ├── Python/                # Shared physics utilities (optional)  
   └── README.md              # Project overview  

Main Godot Project
=================

The primary Godot project contains the core simulation:

.. code-block:: text

   Godot/
   ├── project.godot          # Godot project file
   ├── scenes/                # Game scenes
   │   ├── main.tscn          # Main game scene
   │   ├── aircraft/          # Aircraft scenes
   │   └── terrain/           # Terrain rendering scenes
   ├── scripts/               # GDScript code
   │   ├── physics/           # Flight physics implementation
   │   ├── world/             # World handling (spherical, LOD)
   │   └── ui/                # User interface code
   ├── addons/                # Godot add-ons
   │   └── simiflight_physics/ # Custom physics GDExtension
   └── resources/             # Game resources
       ├── aircraft/          # Aircraft data
       └── terrain/           # Terrain data

Curve Tool
=========

The curve tool for aerodynamic data generation:

.. code-block:: text

   simiflight-curvetool/
   ├── Godot/                 # Godot UI for curve tool
   │   ├── project.godot      # Godot project file
   │   ├── scenes/            # Tool interface scenes
   │   └── scripts/           # Tool interface code
   └── Python/                # Python backend
       ├── requirements.txt   # Python dependencies
       ├── airfoil_calc.py    # Airfoil calculations
       ├── lift_drag.py       # Lift and drag curve generation
       └── api/               # HTTP API implementation

Assets
=====

External assets organized by type:

.. code-block:: text

   assets/
   ├── models/                # 3D models
   │   ├── aircraft/          # Aircraft models
   │   └── props/             # Environment props
   ├── textures/              # Texture files
   ├── sounds/                # Audio files
   └── materials/             # Material definitions

Documentation
============

Project documentation in Sphinx format:

.. code-block:: text

   docs/
   ├── source/                # Documentation source files
   │   ├── conf.py            # Sphinx configuration
   │   ├── index.rst          # Main index
   │   └── ...                # Documentation pages
   ├── Makefile               # Build scripts for Unix
   └── make.bat               # Build scripts for Windows

Python Utilities
==============

Shared Python code for physics calculations:

.. code-block:: text

   Python/
   ├── requirements.txt       # Python dependencies
   ├── atmosphere/            # Atmospheric models
   ├── coordinates/           # Coordinate system utilities
   └── tests/                 # Test cases

Build System
===========

SimiFlight uses several build scripts:

.. code-block:: text

   build/
   ├── linux/                 # Linux build scripts
   ├── windows/               # Windows build scripts
   ├── macos/                 # macOS build scripts
   └── gdextension/           # GDExtension build configuration

File Types and Formats
=====================

SimiFlight uses these file formats:

* **Aircraft Data**: Custom JSON format (``.aircraft``)
* **Aerodynamic Data**: Binary curve data (``.aero``)
* **Scene Files**: Godot scene format (``.tscn``)
* **Script Files**: GDScript (``.gd``), C++ (``.cpp``, ``.h``), Python (``.py``)

Version Control
=============

Guidelines for Git usage:

* Use feature branches for new development
* Tag releases with semantic versioning
* Include descriptive commit messages
