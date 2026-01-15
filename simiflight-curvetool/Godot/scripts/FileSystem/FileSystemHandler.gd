class_name FileSystemHandler
extends RefCounted

static var app_folder_name = GlobalConfig.app_folder_name
static var airfoil_subfolder = GlobalConfig.airfoil_subfolder

# Returns the safe, writeable path: C:/Users/Me/Documents/SimiFlight_SimiFoil/Airfoils/
static func get_user_airfoil_dir() -> String:
	# WEB GUARD
	if OS.has_feature("web"):
		return "" # Return empty so the list scanner just does nothing
	var docs = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var root = docs.path_join(app_folder_name)
	var af_dir = root.path_join(airfoil_subfolder)

	# Create directories if they don't exist
	var dir = DirAccess.open(docs)
	if dir:
		if not dir.dir_exists(app_folder_name):
			dir.make_dir(app_folder_name)

		# Open the root to create the subfolder
		var root_access = DirAccess.open(root)
		if root_access and not root_access.dir_exists(airfoil_subfolder):
			root_access.make_dir(airfoil_subfolder)

	return af_dir

# Returns the root for LUTs/JSONs
static func get_user_data_root() -> String:
	var docs = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return docs.path_join(app_folder_name)
