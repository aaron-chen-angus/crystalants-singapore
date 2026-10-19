class_name CrystalBoard
extends RefCounted

const COLOR_NAMES := ["Cyan", "Coral", "Gold", "Violet", "Mint", "Azure", "Rose"]
const COLOR_ICONS := ["◆", "●", "▲", "■", "✦", "⬟", "✚"]

var width: int
var height: int
var color_count: int
var seed_value: int
var landmark_id: String
var cells: Array = []
var captured: Array = []
var current_color: int = 0
var move_count: int = 0
var total_cells: int
var captured_count: int = 0

func _init(board_width: int = 8, board_height: int = 8, palette_size: int = 4, puzzle_seed: int = 1, landmark: String = "merlion") -> void:
    width = board_width
    height = board_height
    color_count = palette_size
    seed_value = puzzle_seed
    landmark_id = landmark
    total_cells = width * height
    cells.resize(total_cells)
    captured.resize(total_cells)
    _generate()

func _generate() -> void:
    var state: int = abs(seed_value) + 97
    for index in total_cells:
        state = int((state * 1103515245 + 12345) % 2147483647)
        cells[index] = int(state % color_count)
        captured[index] = false
    # Gentle landmark-specific bands make each seed readable while keeping the puzzle fair.
    for y in height:
        for x in width:
            var index := y * width + x
            if landmark_id == "merlion" and (x == width - 2 or (y == height / 2 and x > width / 2)):
                cells[index] = (x + y + 1) % color_count
            elif landmark_id == "marina" and (y == 1 or y == height - 2):
                cells[index] = (x + 2) % color_count
            elif landmark_id == "gardens" and ((x + y) % 5 == 0 or x == width / 2):
                cells[index] = (x * 2 + y + 1) % color_count
    current_color = cells[0]
    _capture_initial_region()
    move_count = 0

func _capture_initial_region() -> void:
    captured_count = 0
    var queue: Array[int] = [0]
    var visited := {}
    while not queue.is_empty():
        var index: int = queue.pop_front()
        if visited.has(index):
            continue
        visited[index] = true
        if cells[index] != current_color:
            continue
        captured[index] = true
        captured_count += 1
        for neighbour in neighbours(index):
            if not visited.has(neighbour):
                queue.append(neighbour)

func neighbours(index: int) -> Array[int]:
    var x := index % width
    var y := int(index / width)
    var result: Array[int] = []
    if x > 0:
        result.append(index - 1)
    if x < width - 1:
        result.append(index + 1)
    if y > 0:
        result.append(index - width)
    if y < height - 1:
        result.append(index + width)
    return result

func cell_color(index: int) -> int:
    return int(cells[index])

func is_captured(index: int) -> bool:
    return bool(captured[index])

func valid_colors() -> Array[int]:
    var available: Array[int] = []
    var seen := {}
    for index in total_cells:
        if not captured[index]:
            for neighbour in neighbours(index):
                if captured[neighbour]:
                    var colour := cell_color(index)
                    if colour != current_color and not seen.has(colour):
                        seen[colour] = true
                        available.append(colour)
                    break
    return available

func preview_gain(colour: int) -> int:
    if colour == current_color:
        return 0
    var mask := _captured_mask()
    var expanded := expand_mask(mask, colour)
    return _bit_count(expanded ^ mask)

func apply_move(colour: int) -> Dictionary:
    if colour < 0 or colour >= color_count or colour == current_color:
        return {"valid": false, "consumed": 0, "colour": colour}
    var before := _captured_mask()
    var after := expand_mask(before, colour)
    var consumed := _bit_count(after ^ before)
    if consumed == 0:
        return {"valid": false, "consumed": 0, "colour": colour}
    for index in total_cells:
        captured[index] = bool(after & (1 << index))
    current_color = colour
    captured_count = _bit_count(after)
    move_count += 1
    return {
        "valid": true,
        "consumed": consumed,
        "colour": colour,
        "state_id": state_id(),
        "regions_remaining": count_remaining_regions(),
        "remaining_crystals": total_cells - captured_count,
    }

func expand_mask(mask: int, colour: int) -> int:
    var result := mask
    var queue: Array[int] = []
    var queued := {}
    for index in total_cells:
        if bool(mask & (1 << index)):
            queue.append(index)
            queued[index] = true
    while not queue.is_empty():
        var index: int = queue.pop_front()
        for neighbour in neighbours(index):
            if bool(result & (1 << neighbour)):
                continue
            if cell_color(neighbour) == colour:
                result |= (1 << neighbour)
                if not queued.has(neighbour):
                    queued[neighbour] = true
                    queue.append(neighbour)
    return result

func _captured_mask() -> int:
    var mask := 0
    for index in total_cells:
        if captured[index]:
            mask |= (1 << index)
    return mask

func _bit_count(value: int) -> int:
    var remaining := value
    var count := 0
    while remaining != 0:
        remaining &= remaining - 1
        count += 1
    return count

func count_remaining_regions() -> int:
    var visited := {}
    var regions := 0
    for start in total_cells:
        if captured[start] or visited.has(start):
            continue
        regions += 1
        var queue: Array[int] = [start]
        while not queue.is_empty():
            var index: int = queue.pop_front()
            if visited.has(index) or captured[index]:
                continue
            visited[index] = true
            for neighbour in neighbours(index):
                if not visited.has(neighbour) and not captured[neighbour] and cell_color(neighbour) == cell_color(index):
                    queue.append(neighbour)
    return regions

func has_won() -> bool:
    return captured_count >= total_cells

func state_id() -> String:
    return "%s:%s:%s" % [str(seed_value), str(current_color), str(_captured_mask())]

func snapshot() -> Dictionary:
    return {
        "captured": captured.duplicate(),
        "current_color": current_color,
        "move_count": move_count,
        "captured_count": captured_count,
    }

func restore(snapshot_data: Dictionary) -> void:
    captured = snapshot_data.captured.duplicate()
    current_color = int(snapshot_data.current_color)
    move_count = int(snapshot_data.move_count)
    captured_count = int(snapshot_data.captured_count)

func _to_string() -> String:
    return "CrystalBoard(%sx%s, seed=%s, progress=%s%%)" % [width, height, seed_value, int(float(captured_count) / float(total_cells) * 100.0)]
