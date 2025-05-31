===========
Development
===========

This section covers information relevant to developers working on the SimiFlight project.

.. toctree::
   :maxdepth: 2
   
   tools
   structure
   roadmap

Development Philosophy
======================

SimiFlight development follows these core principles:

* **Modular design** - Components should be self-contained and testable
* **Incremental progress** - Working in small, verifiable milestones
* **Documentation-driven** - Writing documentation alongside code
* **Performance awareness** - Considering optimization early in design

Getting Started
===============

To begin working on SimiFlight:

1. Clone the repository: ``git clone https://github.com/username/simiflight.git``
2. Follow setup instructions in the README
3. Run the development environment script: ``./setup_dev.sh``
4. Explore the sample scenes in ``Godot/samples/``

.. _repository-structure:

Repository Structure
====================

The SimiFlight repository is organized into several key components:

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

For more details, see :doc:`structure`.

.. _development-roadmap:

Development Roadmap
===================

The current development roadmap follows these major phases:

1. **Prototype Curve Tool** - Python backend + Godot UI
2. **Physics Core** - Implement forces, load curve data, test in 3D
3. **Spherical World** - Integrate 64-bit coordinates and floating origin
4. **Optimization** - Port physics to C++, profile performance
5. **Gameplay Systems** - Add missions, challenges, and assists
6. **Documentation** - Write user guides, example scenes, and API references

For a detailed timeline and milestones, see :doc:`roadmap`.

Contributing
============

Contributions to SimiFlight are welcome! Please follow these guidelines:

* Create a branch for new features
* Write tests for new functionality
* Document your code with comments
* Submit pull requests with clear descriptions

Code Style
==========

SimiFlight follows these coding standards:

* **GDScript** - Follow the `Godot style guide <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html>`_
* **C++** - Use the project's ``.clang-format`` file
* **Python** - Follow PEP 8 style guidelines

Documentation Standards
=======================

All code should be documented following these principles:

* **Public APIs** - Every public method should have documentation
* **Examples** - Include usage examples for complex features
* **Implementation Notes** - Document non-obvious implementation details
