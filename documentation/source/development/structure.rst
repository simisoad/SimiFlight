====================
Repository Structure
====================

.. _repository-structure:

Overview
========

The SimiFlight project is organized into a modular repository structure that separates core functionality,
tools, and assets while facilitating coordinated development.

Main Repository Organization
==========================

The main repository structure is organized as follows:

.. code-block:: text

   simiflight/
   ├── Godot/                  # Main project
   │   ├── addons/            # Godot plugins and extensions
   │   ├── assets/            # Core game assets
   │   ├── scenes/            # Game scenes
   │   ├── scripts/           # GDScript code
   │   └── gdextensions/      # C++ performance-critical code
   │
   ├── simiflight-curvetool/   # Aerodynamic curve generator
   │   ├── Godot/             # CurveTool UI (Godot scenes and scripts)
   │   └── Python/            # Python backend (lift/drag calculations)
   │
   ├── assets/                # 3D models, textures, sounds
   │   ├── aircraft/          # Aircraft models and configurations
   │   ├── terrain/           # Terrain textures and heightmaps
   │   ├── environments/      # Skyboxes, weather effects
   │   └── sounds/            # Audio assets
   │
   ├── docs/                  # Documentation (Markdown, user guides)
   │   ├── api/               # API reference documentation
   │   ├── guides/            # User and developer guides
   │   └── examples/          # Example configurations
   │
   ├── Python/                # Shared Python utilities
   │   ├── aerodynamics/      # Aerodynamic modeling code
   │   ├── tools/             # Support scripts and utilities
   │   └── tests/             # Python test suite
   │
   └── README.md              # Project overview

.. figure:: ../_static/repository_structure.png
   :alt: Repository Structure Visualization
   :align: center
   
   *Visual representation of SimiFlight's repository structure*

Key Components
=============

Main Godot Project
-----------------

The core of SimiFlight resides in the Godot directory:

* **scenes/**: Core simulation scenes
  * **aircraft/**: Aircraft prefabs and components
  * **world/**: World management and terrain systems
  * **ui/**: User interface elements
  
* **scripts/**: GDScript code
  * **physics/**: Flight physics implementation
  * **world/**: World management scripts
  * **aircraft/**: Aircraft control systems
  * **editor/**: Editor tools and extensions

* **gdextensions/**: C++ performance-critical components
  * **physics_engine/**: Core physics calculations
  * **terrain_system/**: Planetary terrain rendering
  * **precision_math/**: 64-bit math operations

CurveTool Project
----------------

The Curve Tool has its own structure:

* **Godot/**: Godot-based user interface
  * **scenes/**: UI components
  * **scripts/**: Tool functionality
  
* **Python/**: Backend calculation systems
  * **aerodynamics/**: Core aerodynamic models
  * **visualization/**: Data plotting and visualization
  * **data_io/**: Data import/export utilities

Asset Organization
----------------

Assets are organized by type and purpose:

* **aircraft/**: Aircraft models and textures
  * Each aircraft in its own subdirectory
  * Includes models, textures, and configuration files
  
* **terrain/**: Terrain data
  * **textures/**: Ground textures
  * **heightmaps/**: Base terrain elevation data
  
* **environments/**: Environmental assets
  * **skies/**: Sky textures and cloud systems
  * **weather/**: Weather effect particles and textures

Python Utilities
--------------

Shared Python code for various purposes:

* **aerodynamics/**: Core aerodynamic calculations
* **tools/**: Utility scripts for content creation
* **tests/**: Automated tests for Python components

Documentation Structure
=====================

The documentation is organized to serve different audiences:

* **api/**: Technical API reference
  * Generated from code comments
  * Detailed function and class documentation
  
* **guides/**: User and developer guidance
  * **users/**: End-user tutorials
  * **developers/**: Development guides
  * **content_creators/**: Asset creation guides
  
* **examples/**: Sample configurations and templates

Development Workflow
==================

Working with the Repository
-------------------------

The recommended workflow when working with the SimiFlight repository:

1. **Clone the repository** with submodules
2. **Set up the development environment** with required tools
3. **Work in feature branches** for specific components
4. **Test integration** between components
5. **Submit pull requests** for review

.. code-block:: bash

   # Clone with submodules
   git clone --recursive https://github.com/username/simiflight.git
   
   # Navigate to main project
   cd simiflight/Godot
   
   # Launch the Godot project
   /path/to/custom/godot/binary

Best Practices
============

Repository management follows these best practices:

* **Modular design** - Components can be developed independently
* **Clear boundaries** - Interfaces between modules are well-defined
* **Consistent naming** - Naming conventions are followed throughout
* **Documentation integration** - Code and documentation are kept in sync
* **Asset optimization** - Assets are optimized before committing

.. seealso::
   * :doc:`tools` - Development tools used in SimiFlight
   * :doc:`roadmap` - Development roadmap and milestones
