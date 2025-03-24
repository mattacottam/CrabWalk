@tool
extends EditorScript

func _run():
	var dir = DirAccess.open("res://resources/characters")
	if not dir:
		print("Could not access character resources directory")
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = "res://resources/characters/" + file_name
			var character = load(path)
			
			if character is Character:
				print("Updating character: " + character.display_name)
				
				# Transfer old range value to new attack_range property
				if "range" in character:
					var old_range = character.get("range")
					character.attack_range = old_range
					print("  Updated range " + str(old_range) + " to attack_range")
				
				# Save the updated resource
				var result = ResourceSaver.save(character, path)
				if result == OK:
					print("  Saved successfully")
				else: 
					print("  Failed to save: " + str(result))
			
		file_name = dir.get_next()
	
	print("Migration complete")
