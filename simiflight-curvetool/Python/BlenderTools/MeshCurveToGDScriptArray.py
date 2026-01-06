import bpy
import os

def export_vertices_to_godot():
    # 1. Get the active object
    obj = bpy.context.active_object

    # Check if an object is selected and is a Mesh
    if not obj or obj.type != 'MESH':
        print("Error: Please select a Mesh object first.")
        return

    # Ensure the blender file is saved so we know where to save the .gd file
    if not bpy.data.filepath:
        print("Error: Please save your .blend file first.")
        return
        
    # 2. Prepare the data
    # We use matrix_world to get the coordinates as they appear in the viewport 
    # (including rotation, scale, and location)
    matrix = obj.matrix_world
    mesh = obj.data
    
    # List to store the processed points
    points_data = []

    for v in mesh.vertices:
        # Convert local vertex coord to global world coord
        world_pos = matrix @ v.co
        
        # Apply the logic requested:
        # X multiplied by 10
        # Y stays as is
        # Note: Blender Z is 'Up', Y is 'Back'. 
        # If your curve is drawn in Top View (XY plane), use world_pos.y.
        # If your curve is drawn in Front View (XZ plane), you might want world_pos.z.
        # I am using .y here as requested.
        
        final_x = world_pos.x * 10.0
        final_y = world_pos.y 
        
        points_data.append((final_x, final_y))

    # OPTIONAL: Sort points by X value? 
    # Lift curves are usually functions where X is the input. 
    # If the vertices are in random order, the line in Godot will be a scribble.
    # Uncomment the next line to sort by X:
    points_data.sort(key=lambda p: p[0])

    # 3. Format the Variable Name
    # Clean the object name to be a valid GDScript variable (no spaces)
    var_name = obj.name.replace(" ", "_").replace(".", "_").lower()

    # 4. Build the GDScript String
    gd_content = f"var {var_name}: Array[Vector2] = [\n"
    
    for p in points_data:
        # Format: Vector2(100.0, 5.0),
        gd_content += f"\tVector2({p[0]:.4f}, {p[1]:.4f}),\n"
        
    gd_content += "]"

    # 5. Save to File
    blend_path = os.path.dirname(bpy.data.filepath)
    filename = f"{var_name}_data.gd"
    full_path = os.path.join(blend_path, filename)

    try:
        with open(full_path, "w") as f:
            f.write(gd_content)
        print(f"Success! Saved to: {full_path}")
        
        # simple popup to confirm
        def draw(self, context):
            self.layout.label(text=f"Saved {filename}")
        bpy.context.window_manager.popup_menu(draw, title="Export Successful", icon='CHECKMARK')
        
    except IOError as e:
        print(f"Could not write file: {e}")

# Run the function
export_vertices_to_godot()