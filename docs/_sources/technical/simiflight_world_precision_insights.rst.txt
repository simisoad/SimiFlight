.. _simiflight_world_precision_insights:

====================================================================
Insights on Large World Simulation and Precision for SimiFlight
====================================================================

This document summarizes key technical concepts and approaches discussed in the context of large-scale world simulation, particularly relevant to the SimiFlight project's goal of a spherical planet and managing floating-point precision.

Floating-Point Precision in Large Worlds
-----------------------------------------

The core challenge in simulating large (planetary-scale) worlds is managing the limitations of 32-bit floating-point numbers (``float``).

*   **32-bit Floats (``float``)**: Offer limited significant digits. As objects move further from the origin (0,0,0) of the coordinate system, the representable gap between consecutive numbers increases.

*   **Consequences**:

*   **Jittering**: Objects may appear to shake or jump as their exact position can no longer be precisely represented.

*   **Physics Instability**: Collision detection and physics calculations become inaccurate, leading to objects passing through each other or other erroneous behaviors.

*   **Rendering Artifacts**: Vertex positions can suffer from precision loss, causing visual glitches, especially in shaders relying on accurate positional data.

*   **64-bit Floats (``double``)**: Provide significantly more precision, drastically reducing precision loss over vast distances. This allows for accurate positioning of objects on a planetary scale.

Why Not Use 64-bit for Everything?
-----------------------------------

*   **GPU Limitations**: Most consumer GPUs are optimized for 32-bit (``float``) calculations. Native 64-bit (``double``) operations in shaders are often unsupported or significantly slower, making a full 64-bit rendering pipeline generally impractical for real-time performance.
*   **Engine Architecture**: Many game engines, including Godot Engine by default, are heavily built around 32-bit float-based structures (vectors, matrices, physics, rendering pipelines). A full conversion to 64-bit is a substantial undertaking.

Techniques for Simulating Large Worlds with 32-bit Limitations
---------------------------------------------------------------

Several techniques are employed to overcome 32-bit float limitations, primarily by keeping high-precision calculations local.

1.  **Floating Origin (Origin Rebasing)**:

*   **Concept**: This is the **most crucial and common technique**. Instead of a single, static world origin, the local coordinate system's origin (0,0,0) dynamically moves with or near the player/camera.

*   **Workflow**:

1.  The player's (and other key objects') **global position** is stored with high precision (e.g., using 64-bit floats or a custom `Vector3d` type on the CPU).

2.  All objects and calculations (physics, rendering) occurring **near the player** are transformed into a **local 32-bit coordinate system** whose origin is close to the player.

3.  When the player moves too far from this local origin, the origin is "rebased" (re-centered):

*   The global 64-bit position of the player (or the new origin point) is updated.

*   All relevant nearby objects have their local 32-bit coordinates recalculated relative to this *new* local origin (typically by subtracting a large offset corresponding to the origin shift).

*   **Advantage**: High-precision calculations (physics, rendering of nearby objects) always occur near the local 32-bit origin, where precision is highest, mitigating issues like jittering.

*   **Consideration**: Requires careful management of coordinate transformations and object repositioning during origin shifts.

2.  **Hybrid Precision**:

*   **Concept**: Use 64-bit floats only where absolutely necessary (e.g., for storing global celestial body positions, or the aircraft's global planetary coordinates) and 32-bit floats for most other operations (local physics, rendering data sent to the GPU).

*   **Integration**: Often used in conjunction with a Floating Origin system. The global position is 64-bit, while the local scene around the floating origin uses 32-bit.

3.  **"Double-Single" Emulation (Less Relevant for SimiFlight's CPU-side Global Positions)**:

*   **Concept**: Representing a high-precision number (like a 64-bit `double`) as the sum of two 32-bit `float` numbers (one મુખ્ય `head` and one `tail` for the remainder/error).

*   **Application**: Primarily a workaround for environments lacking native `double` support (e.g., some GPU shaders).

*   **Relevance to SimiFlight**: For CPU-side global coordinate storage, using native 64-bit `double` types (e.g., via a custom `Vector3d` or modified Godot `Vector3d`) is far more straightforward and efficient than emulating them.

Floating Origin and AI / Multiple Distant Objects
--------------------------------------------------

Managing multiple objects, such as AI aircraft, that can be far from the player and each other, within a Floating Origin system presents choices:

1.  **Single Player-Centric Floating Origin (Simplest Start)**:

*   **Concept**: Only one active local origin, tied to the player.

*   **AI Positioning**: AI aircraft store their global 64-bit positions. For local simulation (physics, rendering near the player), their positions are transformed into the player's local 32-bit space: ``ai_local_pos32 = ai_global_pos64 - player_local_origin64``.

*   **Pros**: Easier to implement initially.

*   **Cons**:

*   Far-distant AI suffers from precision loss in *their* local representation relative to the player's origin.

*   Interactions (e.g., physics, collision) between two AI aircraft that are both far from the player would use these less precise local coordinates.

2.  **Multiple Floating Origins ("Bubbles") (More Complex, Higher Fidelity)**:

*   **Concept**: Each significant entity (player, each AI aircraft, or groups of AI) maintains its own local floating origin bubble.

*   **AI Positioning**: Each AI aircraft performs its own physics and behavior calculations with high precision relative to its *own* local origin.

*   **Interaction Challenge**: Interactions between different bubbles (e.g., player shooting at a distant AI, or two AIs interacting) require transforming coordinates between bubbles or performing calculations in a common (possibly temporary) high-precision reference frame, or directly using global 64-bit coordinates if the physics system supports it performantly.

*   **Pros**: Highest precision for all actively simulated entities.

*   **Cons**: Significantly more complex to implement, manage, and synchronize, especially for inter-bubble interactions.

3.  **Level of Detail (LOD) for AI Precision (Pragmatic Enhancement)**:

*   **Concept**: Often combined with a player-centric origin. The simulation fidelity of distant AI is reduced.

*   **Implementation**:

*   **Physics LOD**: Distant AI uses simplified physics or path-following with global coordinates, rather than full aerodynamic simulation.

*   **Behavioral LOD**: Simpler decision-making for distant AI.

*   **Pros**: Good performance/accuracy trade-off.

*   **Cons**: Behavior of distant AI is not physically accurate.

**Recommendation for SimiFlight's Development Path**:

*   **Start with a Player-Centric Floating Origin (Approach 1)**. This establishes the core system for handling large scales relative to the player's experience.
*   **Architect for Global Coordinates**: Ensure all entities internally manage their true global 64-bit positions, even if local simulations use transformed 32-bit coordinates.
*   **Defer Complex AI Precision**: Address the precision issues for distant AI or inter-AI interactions later. If AI is part of an early milestone (e.g., Bachelor thesis), initially accept the precision limitations for AI far from the player's local origin.
*   **Iterate Towards Higher Fidelity**: Once the core player experience and a single floating origin are robust, consider:

*   Implementing **AI LOD (Approach 3)** as a first step to manage many AI entities.

*   If absolutely necessary for specific gameplay mechanics (e.g., highly accurate long-range engagements between multiple entities), then explore **Multiple Floating Origins (Approach 2)**, being mindful of its complexity.

This phased approach allows for manageable development milestones while keeping the long-term vision of a fully realized, precise, and scalable planetary simulation achievable.