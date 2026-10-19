extends SceneTree

func _init() -> void:
    var scene := preload("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    scene.start_level(0, "Adventure")
    scene.tutorial_open = false
    scene._set_ui_state()
    await process_frame
    await process_frame
    var image: Image = root.get_viewport().get_texture().get_image()
    image.save_png("/tmp/crystal-ants-play.png")
    print("Saved native gameplay capture to /tmp/crystal-ants-play.png")
    quit()
