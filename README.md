# SimiFlight

This project is a further development of my flight simulator, which I developed for my high school graduation project.

Instead of the Unreal Engine, I am now using the Godot Engine.
The project is still in the very early stages of development. 

Currently, only simiflight_p1 (prototype for ground control of aircraft) and simiflight-curvetool (a tool for calculating lift and drag curves in the range of 0-360° alpha/angle of attack) are available.


SimiFlight is an open-source project designed to provide tools for simulating flight physics, specifically for aircraft dynamics and flight simulation in a 3D environment. The project is developed in Godot and Python, and it aims to offer a realistic and interactive flight simulation experience. 

## Project Structure

- **simiflight-curvetool**: Contains tools for generating and managing flight dynamics curves (Lift, Drag, etc.). 
- **Godot**: The main flight simulation GUI and logic are built using Godot Engine, supporting physics-based simulations.
- **Python**: External Python scripts for advanced calculations, such as curve generation and physics-based modeling.

## Features

- **Flight Physics**: Realistic flight dynamics based on physical principles, including Lift, Drag, and Thrust.
- **Curves Generation**: Tools for generating Lift/Drag curves to be used in the simulation.
- **Customizable Aircraft Models**: Users can create custom aircraft with different aerodynamic properties.
- **Simulation Control**: The project allows for real-time adjustments to aircraft parameters and simulation settings.

## How to Use

1. Clone the repository to your local machine:

    ```bash
    git clone https://github.com/yourusername/SimiFlight.git
    ```

2. Install dependencies for the Godot and Python components.

3. Navigate to the respective folders for Godot and Python to start using the tools.

## Getting Started with the Curvetool

The `simiflight-curvetool` directory contains the tools for generating Lift and Drag curves based on aerodynamic parameters. Follow the instructions in the respective README inside the folder to get started.

## Contributing

Feel free to fork the repository and submit pull requests! We welcome contributions from anyone interested in flight simulation and physics-based modeling.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [Godot Engine](https://godotengine.org/) for the game engine and physics support.
- [Python](https://www.python.org/) for the powerful scripting environment.
- [OpenVSP](http://www.openvsp.org/) for tools related to aerodynamic shape modeling.
