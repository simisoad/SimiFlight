======================
Godot-Python Integration
======================

.. _godot-python:

Overview
========

SimiFlight leverages both Godot Engine and Python to combine the strengths of each technology:

* **Godot Engine**: Provides the game engine, rendering, and core simulation framework
* **Python**: Powers advanced mathematical modeling, especially for aerodynamics
* **Integration layer**: Connects these systems for seamless operation

This hybrid approach allows SimiFlight to benefit from Godot's game development capabilities while utilizing Python's scientific computing ecosystem.

.. figure:: _static/godot_python_integration.png
   :alt: Godot-Python Integration
   :align: center
   
   *Overview of the Godot-Python integration architecture*

Integration Methods
=================

SimiFlight employs two primary methods for Godot-Python integration:

External Process Communication
----------------------------

The simplest integration approach uses external process calls:

* Godot launches Python scripts as separate processes
* Data exchange via standard input/output (stdin/stdout)
* Suitable for non-realtime operations like pre-computing aerodynamic tables

.. code-block:: gdscript

   # Example GDScript for calling a Python script
   func generate_aerodynamic_data(airfoil_params):
       var output = []
       var args = ["python", "aerodynamics_calculator.py"]
       
       # Add parameters
       for key in airfoil_params:
           args.append("--" + key + "=" + str(airfoil_params[key]))
       
       # Execute process
       var exit_code = OS.execute("python", args, true, output)
       
       if exit_code == 0:
           return parse_json(output[0])
       else:
           push_error("Failed to generate aerodynamic data")
           return null

HTTP API
-------

For more complex interactions, especially in development tools, SimiFlight uses an HTTP-based approach:

* Python runs a lightweight server (Flask or FastAPI)
* Godot communicates via HTTP requests
* JSON used for data exchange
* WebSockets enable real-time updates for interactive tools

.. code-block:: python

   # Example Python FastAPI server code
   from fastapi import FastAPI
   import uvicorn
   from pydantic import BaseModel
   from aerodynamics_engine import calculate_coefficients
   
   app = FastAPI()
   
   class AirfoilParams(BaseModel):
       profile: str
       angle_of_attack: float
       mach_number: float
       reynolds_number: float
   
   @app.post("/calculate_coefficients")
   def api_calculate_coefficients(params: AirfoilParams):
       cl, cd, cm = calculate_coefficients(
           params.profile,
           params.angle_of_attack,
           params.mach_number,
           params.reynolds_number
       )
       return {"cl": cl, "cd": cd, "cm": cm}
   
   if __name__ == "__main__":
       uvicorn.run(app, host="127.0.0.1", port=8000)

Python Libraries Used
===================

SimiFlight leverages several Python libraries for its aerodynamic calculations:

* **NumPy/SciPy**: Core numerical computing and scientific functions
* **Matplotlib**: Visualization of aerodynamic data
* **Pandas**: Data manipulation and analysis
* **Flask/FastAPI**: HTTP API servers
* **PyAero**: Airfoil analysis tools

Development Workflow
==================

The development workflow for the integrated system involves:

1. **Python development**: 
   
   * Write and test aerodynamic models independently
   * Create comprehensive test cases
   * Validate against known aerodynamic data

2. **Godot integration**: 
   
   * Build UI elements for parameter input
   * Implement data visualization components
   * Create seamless API calls to Python backend

3. **Testing and validation**:
   
   * Verify data consistency between systems
   * Profile performance bottlenecks
   * Optimize communication paths

Security Considerations
=====================

When integrating external processes and HTTP APIs, security is important:

* **Input validation**: All parameters are validated before processing
* **Process isolation**: Python runs in a separate process with limited permissions
* **Local-only services**: HTTP services bind only to localhost
* **Response sanitization**: All responses are validated before use

Example: The Curve Tool
=====================

The :doc:`curve` demonstrates this integration approach:

* **Python backend**: Performs complex aerodynamic calculations
* **Godot frontend**: Provides user interface and visualization
* **HTTP bridge**: Connects the components for interactive workflow

.. note::
   This integration pattern is extensible to other simulation aspects, such as weather modeling or navigation systems.

Future Extensions
===============

The Godot-Python integration architecture allows for future extensions:

* **Machine learning** for procedural terrain or AI behavior
* **Advanced statistical models** for environmental simulation
* **External data connections** to real-world weather or aviation databases

.. seealso::
   * :doc:`curve` - The Curve Tool implementation details
   * :doc:`../development/tools` - Development tools used in SimiFlight
