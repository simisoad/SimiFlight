=====
Goals
=====

SimiFlight aims to achieve several key objectives across different aspects of the simulation.

Realism
======

Flight Physics
-------------

SimiFlight implements a physics-based flight model that includes:

* **Lift and drag forces** calculated from aerodynamic principles
* **G-force** effects on aircraft performance and handling
* **Stall** characteristics based on angle of attack
* **Mach effects**, including Prandtl-Glauert correction up to Mach 0.85

Modular Approach
---------------

The simulation adopts a modular approach to realism:

* Toggle **simplified controls** for casual players
* Adjustable **auto-trim** functionality
* Optional **wind effects** and atmospheric conditions
* Focus on **flying experience** rather than cockpit procedures

.. note::
   SimiFlight deliberately avoids complex startup procedures and system management,
   focusing instead on the experience of flight itself.

World & Scale
============

Planetary Simulation
-------------------

A key technical goal is the implementation of a full planetary model:

* **Complete spherical planet** with continuous terrain
* **Terrain streaming** for seamless exploration
* **Dynamic weather systems** spanning the globe

Technical Implementation
-----------------------

To achieve this scale, SimiFlight employs advanced techniques:

* **64-bit floating-point precision** for global positioning
* **Floating origin technique** to mitigate precision errors
* **Dynamic LOD** (level of detail) for terrain and objects
* Sophisticated **object culling** to maintain performance

Gameplay
=======

Hybrid Experience
----------------

SimiFlight creates a "sim-lite" experience that combines:

* **Simulator rigor** in physics and flight dynamics
* **Arcade freedom** in exploration and mission design
* **Progressive difficulty** options for various player skill levels

Game Elements
------------

The simulator incorporates various gameplay elements:

* **Exploration** of an open world
* **Missions** with specific objectives
* **Races** and time challenges
* **Delivery systems** for cargo transport
* **Optional assists** for new players

.. figure:: _static/gameplay_elements.png
   :alt: Gameplay Elements
   :align: center
   
   *Illustration of SimiFlight's gameplay elements*

Technical goals are further detailed in the :doc:`technical/index` section.
