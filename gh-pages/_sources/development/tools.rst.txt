=================
Development Tools
=================

.. _development-tools:

Overview
========

SimiFlight development relies on a specific set of tools that enable the complex integration of flight physics,
planetary-scale rendering, and an accessible user experience.

Core Development Environment
==========================

Godot Engine
-----------

The primary development environment for SimiFlight is a customized version of Godot Engine 4.4:

* **Custom build** with modifications for 64-bit precision
* **Editor extensions** for aerodynamic data visualization 
* **Asset pipeline** optimized for terrain and aircraft models

.. figure:: ../_static/godot_editor.png
   :alt: Godot Editor Environment
   :align: center
   
   *SimiFlight's customized Godot Editor environment*

Python Environment
----------------

Several Python tools and libraries are used for advanced computational tasks:

* **Python 3.x** - Base language for aerodynamic modeling
* **NumPy/SciPy** - Scientific computing and mathematics
* **Matplotlib** - Data visualization for aerodynamic coefficients
* **Pandas** - Data analysis and manipulation
* **Flask/FastAPI** - HTTP API for Godot-Python communication

C++ Development
-------------

Performance-critical components are implemented in C++:

* **GDExtensions** - Custom C++ modules for Godot integration
* **Physics libraries** - High-performance numerical calculations
* **Memory management** - Optimized data structures for terrain handling

Version Control and Collaboration
===============================

GitHub Repository
---------------

The SimiFlight project is hosted on GitHub with the following organization:

* **Main repository**: Core project code and documentation
* **Issue tracking**: Feature requests and bug reports
* **Pull requests**: Code review and contribution workflow
* **Actions**: Automated testing and build verification

Documentation Tools
----------------

Documentation is maintained using several tools:

* **Sphinx**: This documentation generator you're currently viewing
* **Markdown**: For simpler readme files and GitHub documentation
* **PyCharm**: IDE with integrated documentation support
* **Doxygen**: For C++ API documentation

Development Workflow
==================

Local Development Process
-----------------------

The typical development workflow involves:

1. **Feature branch creation** from the main development branch
2. **Local development** using the customized Godot build
3. **Python integration** for mathematical components
4. **Testing** with sample scenarios and configurations
5. **Documentation updates** for new features
6. **Pull request** for code review and integration

.. code-block:: bash

   # Example workflow
   git checkout -b feature/new-aerodynamic-model
   
   # Work on code...
   
   # Test with development build
   ./simiflight-godot --debug-mode
   
   # Update documentation
   cd docs
   make html
   
   # Commit and push
   git add .
   git commit -m "Add new aerodynamic model with improved stall behavior"
   git push origin feature/new-aerodynamic-model

Continuous Integration
--------------------

SimiFlight uses continuous integration to ensure code quality:

* **Automated builds** for multiple platforms
* **Unit tests** for physics components
* **Integration tests** for Godot-Python communication
* **Documentation builds** to verify RST structure

Specialized Development Tools
===========================

Curve Tool
---------

The Curve Tool is both a core component and a development tool:

* **Interactive UI** for aerodynamic data generation
* **Visualization** of lift, drag, and moment coefficients
* **Export capabilities** for simulation data

See :doc:`../technical/curve` for more details on the Curve Tool.

Physics Debugger
--------------

A specialized tool for debugging flight physics:

* **Force visualization** showing lift, drag, weight, and thrust
* **Real-time plots** of aerodynamic coefficients
* **Scenario recorder** for reproducing and analyzing flight behavior

Terrain Generator
---------------

Tools for working with planetary-scale terrain:

* **Height map processors** for large-scale terrain generation
* **LOD optimization** tools for performance tuning
* **Asset placement** utilities for environmental objects

External Resources
================

SimiFlight development is supported by several external resources:

* **Aerodynamic databases** for airfoil validation
* **Terrain datasets** for realistic world modeling
* **Open-source physics libraries** adapted for flight simulation

.. seealso::
   * :doc:`structure` - Repository structure information
   * :doc:`roadmap` - Development roadmap and milestones
