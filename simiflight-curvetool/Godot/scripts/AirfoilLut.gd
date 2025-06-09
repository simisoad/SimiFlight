# res://scripts/AirfoilLut.gd
class_name AirfoilLut
extends Resource

# Dieses Skript definiert die Struktur für unsere Lookup-Tabelle.
# Es wird von LutGenerator.gd erstellt und von SimiFlight.gd geladen.

# Die Stützpunkte der Achsen
@export var alpha_points: Array[float]
@export var mach_points: Array[float]
@export var altitude_points: Array[float]

# Die flachen Daten-Arrays. Die Werte sind so angeordnet:
# for alt in altitude_points:
#   for mach in mach_points:
#     for alpha in alpha_points:
#       data.append(...)
@export var cl_data: Array[float]
@export var cd_data: Array[float]
