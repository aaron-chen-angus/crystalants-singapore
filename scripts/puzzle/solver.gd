class_name CrystalSolver
extends RefCounted

static func solve(board: CrystalBoard, max_states: int = 180000) -> Dictionary:
    if board.total_cells > 64:
        return {"certified": false, "moves": -1, "path": [], "states": 0, "reason": "Board exceeds the exact solver's 64-cell support."}
    var start_mask := _mask_from_board(board)
    var full_mask := _full_mask(board.total_cells)
    if start_mask == full_mask:
        return {"certified": true, "moves": 0, "path": [], "states": 1}
    var queue: Array = [{"mask": start_mask, "colour": board.current_color}]
    var head := 0
    var distances := {}
    var parent := {}
    var start_key := _key(start_mask, board.current_color)
    distances[start_key] = 0
    var goal_key := ""
    while head < queue.size() and distances.size() <= max_states:
        var state: Dictionary = queue[head]
        head += 1
        var mask: int = state.mask
        var colour: int = state.colour
        var distance: int = int(distances[_key(mask, colour)])
        for choice in board.color_count:
            if choice == colour:
                continue
            var next_mask := board.expand_mask(mask, choice)
            if next_mask == mask:
                continue
            var next_key := _key(next_mask, choice)
            if distances.has(next_key):
                continue
            distances[next_key] = distance + 1
            parent[next_key] = {"previous": _key(mask, colour), "choice": choice}
            if next_mask == full_mask:
                goal_key = next_key
                head = queue.size()
                break
            queue.append({"mask": next_mask, "colour": choice})
        if goal_key != "":
            break
    if goal_key == "":
        return {"certified": false, "moves": -1, "path": [], "states": distances.size(), "reason": "Search bound reached before certification."}
    var path: Array[int] = []
    var cursor := goal_key
    while cursor != start_key:
        var link: Dictionary = parent[cursor]
        path.push_front(int(link.choice))
        cursor = link.previous
    return {"certified": true, "moves": path.size(), "path": path, "states": distances.size()}

static func _mask_from_board(board: CrystalBoard) -> int:
    var mask := 0
    for index in board.total_cells:
        if board.is_captured(index):
            mask |= (1 << index)
    return mask

static func _full_mask(cell_count: int) -> int:
    var mask := 0
    for index in cell_count:
        mask |= (1 << index)
    return mask

static func _key(mask: int, colour: int) -> String:
    return "%s|%s" % [str(mask), str(colour)]

static func greedy_hint(board: CrystalBoard) -> Dictionary:
    var options := board.valid_colors()
    var best := -1
    var best_gain := -1
    for choice in options:
        var gain := board.preview_gain(choice)
        if gain > best_gain:
            best_gain = gain
            best = choice
    return {"colour": best, "gain": max(best_gain, 0), "certified": false}
