# lift_calc.py
import sys
import math

def calculate_lift(alpha_deg):
    alpha_rad = math.radians(float(alpha_deg))
    cl = 2 * math.pi * alpha_rad  # Näherung: Cl = 2π * alpha (rad)
    return cl

if __name__ == "__main__":
    alpha = sys.argv[1]
    cl = calculate_lift(alpha)
    print(cl)
