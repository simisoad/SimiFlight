============
Ground Effect
============

What Is Ground Effect?
=====================

When an aircraft flies very close to the surface—within roughly one wingspan's height—the airflow patterns around the wing change. The wing's downwash is squeezed between wing and ground, which:

* **Increases effective lift** by reducing the strength of wingtip vortices
* **Decreases induced drag**, since less energy is lost swirling air

The result? A "cushion" of higher pressure under the wing that makes the airplane feel a bit more buoyant.

.. figure:: _static/ground_effect_illustration.png
   :alt: Ground Effect Illustration
   :align: center
   
   *Illustration of airflow patterns in ground effect*

Why It Matters
=============

Ground effect has several practical implications for flight:

* **Shorter takeoff runs:** You need less runway to lift off, because you're getting extra lift just above the surface
* **Softer landings:** As you flare and settle, that cushion slows your descent a bit—helpful on amphibious or STOL (short takeoff and landing) aircraft
* **Ekranoplans / Wing-In-Ground (WIG) Craft:** These Soviet "Caspian Sea Monsters" and modern WIG boats operate almost entirely in ground effect, cruising a few meters above the water at high speed

.. note::
   Pilots need to be aware of ground effect during takeoff and landing, as it can cause an aircraft to "float" down the runway if not properly managed.

Simulating Ground Effect in SimiFlight
=====================================

To add ground‐effect into the SimiFlight physics model, we implement the following approach:

1. **Modify the lift coefficient (Cl):**

   .. math::
      
      Cl_{ground} = Cl_{\infty} \times \bigl(1 + f(h/b)\bigr)
   
   where:
   
   * :math:`h` is height above ground
   * :math:`b` is wingspan
   * :math:`f(h/b)` is a factor that decreases as height increases

2. **Reduce induced drag:** 
   
   Apply the inverse of that same factor to the induced drag coefficient (:math:`Cd_i`).

3. **Blend smoothly:** 
   
   Ensure the effect transitions smoothly over :math:`0 < h/b < 0.5`, so there's no sudden "jump" in forces.

Implementation Details
---------------------

The implementation in SimiFlight uses a smooth transition function:

.. code-block:: python

   def ground_effect_factor(height, wingspan):
       # Calculate h/b ratio (height to wingspan)
       h_b_ratio = height / wingspan
       
       # No effect above h/b = 0.5
       if h_b_ratio >= 0.5:
           return 0.0
       
       # Maximum effect at ground level, tapering off to zero at h/b = 0.5
       return max(0.0, 0.25 * (1 - (h_b_ratio / 0.5)**2))

This ground effect implementation makes takeoffs feel noticeably "bouncy" and gives aircraft that satisfying liftoff sensation once they break through the effect zone.

.. seealso::
   
   * :doc:`physics` - Main flight physics engine documentation
   * :doc:`curve` - How the coefficient curves are generated

Physics Background
=================

The reduction in induced drag occurs because the ground interrupts the formation of wingtip vortices. In free air, these vortices create downwash that effectively reduces the angle of attack. Near the ground, this downwash is partially blocked, resulting in:

* Higher effective angle of attack
* Increased lift coefficient
* Reduced induced drag

Research has shown that ground effect becomes significant when an aircraft is flying at a height less than one wingspan above the ground, with maximum effect occurring very close to the surface.