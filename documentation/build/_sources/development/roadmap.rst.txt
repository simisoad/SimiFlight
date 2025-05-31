=================
Development Roadmap
===================

This page outlines the development plan for SimiFlight, including major milestones,
priorities, and estimated timelines.

Major Phases
============

Phase 1: Prototype Curve Tool
-----------------------------

**Status**: In Progress

**Goals**:

* Implement Python backend for aerodynamic calculations

* Create Godot UI for curve tool

* Export aerodynamic data in usable format

* Validate calculations against known airfoils

**Timeline**: Q3 2025

**Key Tasks**:


.. list-table::
    :widths: 10 50 20 20
    :header-rows: 1
   
    * - Task

    - Description

    - Status

    - Priority

    * - Python Backend

    - Implement basic lift/drag calculations

    - In Progress

    - High

    * - Simple UI

    - Create minimal Godot interface

    - Planned

    - Medium

    * - Data Export

    - Define and implement data format

    - Not Started

    - Medium

    * - Validation

    - Test against NACA airfoil data

    - Not Started

    - High


Phase 2: Physics Core
---------------------

**Status**: Planning

**Goals**:

* Implement core flight physics in GDScript

* Create test aircraft with simple controls

* Load and utilize aerodynamic curve data

* Test flight model in simple 3D environment

**Timeline**: Q4 2025

**Dependencies**:

* Completion of Curve Tool prototype

* Definition of aircraft data format

Phase 3: Spherical World
------------------------

**Status**: Research

**Goals**:

* Implement 64-bit coordinate system

* Create floating origin mechanism

* Test physics integration with spherical world

* Develop basic terrain streaming

**Timeline**: Q1 2026

**Technical Challenges**:

* Godot Engine modifications for 64-bit precision

* Performance optimizations for coordinate transformations

* LOD implementation for planetary scale

Phase 4: Optimization
---------------------

**Status**: Not Started

**Goals**:

* Port critical physics components to C++

* Profile performance and identify bottlenecks

* Implement multi-threading for physics calculations

* Optimize terrain rendering and LOD systems

**Timeline**: Q2 2026

Phase 5: Gameplay Systems
-------------------------

**Status**: Conceptual

**Goals**:

* Implement mission system

* Create challenge framework

* Add assist systems for new players

* Develop initial gameplay loops

**Timeline**: Q3-Q4 2026

Phase 6: Documentation
----------------------

**Status**: Ongoing

**Goals**:

* Complete API reference documentation

* Create user guides and tutorials

* Document example scenes and usage patterns

* Prepare contributor guidelines

**Timeline**: Continuous

Milestone Chart
===============

.. figure:: ../_static/roadmap_chart.png
   :alt: Roadmap Timeline
   :align: center
   
   *SimiFlight development roadmap timeline*

Release Versioning
==================

SimiFlight follows semantic versioning:

* **0.x**: Development versions (not feature complete)
* **1.0**: First stable release with core functionality
* **1.x**: Incremental feature