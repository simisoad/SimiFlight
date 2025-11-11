# res://scripts/AirfoilLut.gd
class_name AirfoilLut
extends Resource

# Die Stützpunkte der Achsen
@export var alpha_points: Array[float]
@export var mach_points: Array[float]
# ALT: @export var altitude_points: Array[float]
@export var reynolds_points: Array[float] # NEU

# Die flachen Daten-Arrays. Die Werte sind jetzt so angeordnet:
# for re in reynolds_points:
#   for mach in mach_points:
#     for alpha in alpha_points:
#       data.append(...)
@export var cl_data: Array[float]
@export var cd_data: Array[float]
