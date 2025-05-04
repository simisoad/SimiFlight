==========
Curve Tool
==========

.. _curve-tool:

Purpose and Overview
===================

The SimiFlight Curve Tool is a specialized utility for generating accurate aerodynamic data for the flight simulation:

* **Primary function**: Generate lift/drag curves for airfoils under variable conditions
* **Core capability**: Calculate coefficients across different angles of attack and Mach numbers
* **Integration**: Provides data that feeds directly into the flight physics engine

.. figure:: _static/curve_tool_ui.png
   :alt: Curve Tool Interface
   :align: center
   
   *The SimiFlight Curve Tool interface*

Technical Approach
================

Aerodynamic Modeling Methods
---------------------------

The Curve Tool implements multiple complementary approaches to calculate aerodynamic properties:

1. **Semi-empirical models**:
   
   * Thin airfoil theory with corrections
   * NACA airfoil equation implementations
   * Empirical stall behavior modeling

2. **Panel method**:
   
   * 2D potential flow calculation
   * Vortex panel implementation
   * Pressure distribution analysis

3. **Data interpolation**:
   
   * Reference to standard airfoil databases
   * Interpolation between known data points
   * Curve fitting to empirical test data

Implementation
------------

The Curve Tool consists of two primary components:

* **Python backend**: Performs the mathematical calculations and aerodynamic modeling
* **Godot UI**: Provides user interface for data input and visualization

.. code-block:: python

   # Example Python code from the Curve Tool backend
   def calculate_lift_coefficient(airfoil, angle_of_attack, mach_number):
       """Calculate lift coefficient (Cl) for given conditions."""
       if mach_number < 0.3:
           # Incompressible flow
           cl = incompressible_lift(airfoil, angle_of_attack)
       else:
           # Compressible flow with Prandtl-Glauert correction
           beta = math.sqrt(1 - min(mach_number * mach_number, 0.9))
           cl = incompressible_lift(airfoil, angle_of_attack) / beta
       
       # Apply stall model if needed
       if abs(angle_of_attack) > airfoil.stall_angle:
           cl = apply_stall_model(cl, angle_of_attack, airfoil)
           
       return cl

Data Generation Process
=====================

The workflow for generating aerodynamic data is as follows:

1. **Define aircraft parameters**:
   
   * Airfoil profiles
   * Wing geometry (aspect ratio, taper ratio)
   * Control surface configuration

2. **Generate coefficient tables**:
   
   * Lift coefficients (Cl) across AOA and Mach ranges
   * Drag coefficients (Cd) with induced and parasitic components
   * Moment coefficients (Cm) for pitch behavior
   * Control surface effectiveness

3. **Export to simulation format**:
   
   * Custom SimiFlight curve format (.scurve)
   * Data visualization for verification
   * Metadata for documentation

Example Output
------------

Here's an example of how the data is visualized in the tool:

.. code-block:: text

   # Lift coefficient (Cl) vs. Angle of Attack (degrees)
   # Mach: 0.2
   # Airfoil: NACA 4412
   
   AOA     Cl       Cd       Cm
   -4.0    -0.2142  0.00821  -0.0401
   -2.0    0.0105   0.00612  -0.0382
    0.0    0.2352   0.00594  -0.0364
    2.0    0.4599   0.00632  -0.0346
    4.0    0.6846   0.00731  -0.0328
    6.0    0.9093   0.00894  -0.0309
    8.0    1.1340   0.01118  -0.0291
   10.0    1.3368   0.01407  -0.0273
   12.0    1.4733   0.01760  -0.0255
   14.0    1.5435   0.02178  -0.0236
   16.0    1.5474   0.06591  -0.0818
   18.0    1.4950   0.12445  -0.1400

Godot-Python Integration
======================

The Curve Tool demonstrates the Godot-Python integration approach used throughout SimiFlight:

* **Communication method**: HTTP API (FastAPI/Flask) 
* **Data exchange**: JSON formatted aerodynamic data
* **UI implementation**: Godot's @tool scripts for editor integration

.. note::
   For more details on how Python and Godot interact, see :doc:`integration`

Usage in Simulation
=================

The Curve Tool's output directly feeds into the flight physics engine:

* **Runtime interpolation**: The simulation interpolates between data points in real-time
* **Multi-surface compositing**: Multiple aerodynamic surfaces combine their effects
* **Dynamic conditions**: Actual forces vary based on air density, velocity, and control inputs

.. seealso::
   * :doc:`physics` - How these curves are used in the flight model
   * :doc:`../development/tools` - Other development tools in the SimiFlight toolkit
