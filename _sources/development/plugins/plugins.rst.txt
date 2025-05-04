===========================
Godot Plugins Overview
===========================

This document provides an overview of the Godot plugins utilized in the flight simulator project.

-------------------------------------------------------------------------------------------------

Game Console
------------

**Repository:** https://github.com/XanatosX/godot-game-console

**Description:**

The Game Console plugin introduces an in-game console to Godot, enabling developers to execute commands during runtime. This facilitates debugging and testing without modifying the game code.

**Features:**

- Execute custom commands at runtime.
- Navigate command history using arrow keys.
- Extendable with user-defined commands.

**Usage:**

To add and remove custom commands, refer to the example script provided in the repository or consult the quickstart section.

---

GodPlot
-------

**Repository:** https://github.com/onegm/GodPlot

**Description:**

GodPlot is a Godot 4 plugin designed for creating various types of graphs directly within the editor. It supports multiple graph types, making it suitable for visualizing data such as flight parameters.

**Supported Graph Types:**

- Scatter plots (circle, square, triangle, X, star)
- Line graphs
- Area graphs
- Histograms

**Usage:**

Instantiate a `Graph2D` node and utilize the provided API to add data series and points. This is particularly useful for plotting real-time data like altitude or speed.

---

GUT (Godot Unit Test)
---------------------

**Repository:** https://github.com/bitwes/Gut

**Documentation:** https://gut.readthedocs.io/en/latest/

**Description:**

GUT is a unit testing framework tailored for the Godot Engine, allowing developers to write and run tests for GDScript code. It supports integration with the Godot Editor, command line, and VSCode.

**Features:**

- Write tests in GDScript.
- Run tests through the Godot Editor or command line.
- Supports test doubles and assertions.

**Installation:**

GUT can be installed via the Godot Asset Library or by cloning the repository. For detailed installation instructions, refer to the official documentation.

---

Inspector Extender
------------------

**Repository:** https://github.com/don-tnowe/godot-inspector-extender

**Description:**

Inspector Extender enhances the Godot Inspector by allowing developers to add specialized controls using comments above properties in scripts. This plugin supports nodes, resources, and non-tool scripts.

**Features:**

- Add messages, warnings, and errors in the inspector.
- Group buttons and organize properties.
- Conditional visibility of properties.

**Usage:**

By placing specific comments (e.g., `@@message`, `@@button_group`) above exported properties, developers can customize the appearance and behavior of the inspector for their scripts.

---

End of Document
