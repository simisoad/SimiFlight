extends Node

static func get_aerodynamic_center(mach: float) -> float:
	# 1. Unterschall (bis Mach 0.8)
	if mach < 0.8:
		return 0.25 # Klassische 25%

	# 2. Überschall (ab Mach 1.2) -> Ackeret Theorie
	elif mach > 1.2:
		return 0.50 # Wandert auf 50%

	# 3. Transschall (Übergangsbereich)
	else:
		# Wir interpolieren weich zwischen 0.25 und 0.50
		# t geht von 0.0 (bei Mach 0.8) bis 1.0 (bei Mach 1.2)
		var t = (mach - 0.8) / 0.4

		# Smoothstep sorgt für einen organischen Übergang (S-Kurve)
		var blend = t * t * (3.0 - 2.0 * t)

		return lerp(0.25, 0.50, blend)

func apply_forces():
	# ... Mach berechnen ...
	var mach = 1.0
	# Dynamischen Punkt holen
	var ac_percent = get_aerodynamic_center(mach)
	var chord_length
	# Position berechnen (Z-Achse ist lokal hinten)
	@warning_ignore("unassigned_variable", "unused_variable")
	var ac_local_pos = Vector3(0, 0, chord_length * ac_percent)

	# ... Kraft dort anwenden ...
#
#2. Missiles (Raketen)
#Hier musst du unterscheiden zwischen den Fins (Flossen) und dem Körper (Body).
#Fins: Funktionieren exakt wie kleine Flügel. Nutze die Formel oben (0.25 -> 0.50). Das ist korrekt für Air-to-Air Missiles (Sidewinder etc.).
#Körper (Rumpf): Ein langer Zylinder erzeugt auch Auftrieb (Body Lift), aber der Neutralpunkt ist anders.
#Nach der Slender Body Theory liegt der aerodynamische Druckpunkt eines Zylinders meist sehr weit vorne.
#Bei Raketen vereinfacht man oft: Der Auftrieb des Rumpfes ist klein im Vergleich zu den Flossen, aber er greift weit vorne an (destabilisierend).
#Tipp: Für den Anfang kannst du den Rumpf als "Flügel mit sehr kleiner Spannweite und sehr schlechtem Profil" simulieren, aber setze den AC statisch auf ca. 10-20% der Länge, wenn du keine komplexe Rumpf-Aerodynamik schreiben willst.
