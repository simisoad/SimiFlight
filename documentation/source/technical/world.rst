===========================
Hybrid Precision World Model
============================

The Hybrid Precision World Model is a cornerstone of SimiFlight's technical implementation,
enabling simulation across an entire planet while maintaining numerical precision.

Core Concept
============

SimiFlight uses a dual coordinate system approach:

* **Local coordinates** (32-bit) - Used for rendering and physics calculations
* **Global coordinates** (64-bit) - Used for planetary positioning
* **Coordinate transformation** - Dynamic mapping between local and global space



Floating Origin System
======================

To avoid precision issues when far from the origin point:

* The origin of the physics world "follows" the player
* All objects are repositioned relative to the new origin when a threshold is crossed
* Physics calculations remain stable regardless of global position

Implementation Details
======================

Global Positioning
------------------

Global positions use 64-bit double-precision values:

.. code-block:: cpp

   struct GlobalPosition {
       double latitude;    // in radians
       double longitude;   // in radians
       double altitude;    // in meters above sea level
   };

Coordinate Transformation
-------------------------

Converting between coordinate systems:

.. code-block:: cpp

   // Convert global to local coordinates
   Vector3 globalToLocal(const GlobalPosition& global) {
       // Calculate distance from floating origin
       // Project spherical coordinates to local cartesian coordinates
       // ...
   }
   
   // Convert local to global coordinates
   GlobalPosition localToGlobal(const Vector3& local) {
       // Add local offset to floating origin global position
       // Convert to spherical coordinates
       // ...
   }

Performance Considerations
==========================

The hybrid precision approach introduces some overhead:

* **Coordinate transformation cost** - Performed during critical operations
* **Memory usage** - Additional storage for 64-bit coordinates
* **Threshold tuning** - Balancing precision vs. transformation frequency

.. note::
   SimiFlight uses optimized C++ GDExtensions for coordinate transformations
   to minimize performance impact.

Related Technical Concepts
==========================

* :doc:`physics` - Integration with the physics system

References
==========

* Kerbal Space Program's floating origin system
* NASA technical papers on planetary simulation
