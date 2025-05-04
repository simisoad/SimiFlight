======================
Godot Engine Modifications
======================

.. _godot-modifications:

Overview
========

SimiFlight requires several modifications to the standard Godot Engine 4.4 to achieve its technical goals,
particularly for planetary-scale simulation with high precision.

Custom Godot Build
=================

To support SimiFlight's requirements, we maintain a customized version of the Godot Engine:

* **64-bit precision support** for transform matrices and vector operations
* **Enhanced memory management** for handling large terrain datasets
* **Custom render pipeline** optimizations for distant terrain

.. figure:: _static/godot_customization.png
   :alt: Godot Customization Diagram
   :align: center
   
   *Overview of Godot Engine customizations for SimiFlight*

GPU Precision Workarounds
========================

Modern GPUs have limited support for double-precision floating-point operations, requiring creative solutions:

* **Shader hacks** that decompose high-precision values into multiple components
* **Fixed-function fallbacks** for certain operations
* **Relative coordinates** for rendering distant objects

.. code-block:: glsl

   // Example shader code for high-precision position calculation
   // Using two float32 vectors to represent one double-precision position
   vec3 high_part = ...; // High bits of position
   vec3 low_part = ...;  // Low bits of position
   
   // Combine for precise positioning
   vec3 world_pos = high_part + low_part;

Performance Optimizations
========================

Several performance optimizations have been implemented to maintain high frame rates:

* **Custom culling system** that accounts for planetary curvature
* **LOD (Level of Detail)** systems optimized for flight simulation
* **Occlusion techniques** specifically designed for aerial perspectives
* **Memory pooling** for frequently used physics calculations

Scene Structure
==============

SimiFlight uses a specialized scene structure to accommodate both local and global precision:

.. code-block:: text

   World (64-bit coordinates)
   ├── FloatingOrigin (recenters at threshold)
   │   ├── Terrain (relative to floating origin)
   │   ├── Aircraft (relative to floating origin)
   │   └── Environment (clouds, weather)
   └── GlobalSystems (absolute 64-bit positioning)

Integration with Physics
======================

The modified Godot Engine integrates with the custom physics system in several ways:

* **Custom physics callbacks** for aerodynamic force application
* **Extended collision detection** for terrain interaction
* **Multi-threaded physics** for performance-critical operations

.. note::
   All modifications to Godot Engine are maintained in a separate fork to facilitate
   updates when new Godot versions are released.

Development Workflow
==================

To work with the modified Godot Engine:

1. Build the custom Godot engine from our repository
2. Configure project settings to use the extended precision features
3. Follow SimiFlight's best practices for scene organization

.. seealso::
   * :doc:`world` - How the hybrid precision world system works
   * :doc:`../development/tools` - Development tools used in SimiFlight
