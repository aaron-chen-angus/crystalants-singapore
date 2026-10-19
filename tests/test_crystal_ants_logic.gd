extends SceneTree

const CrystalBoard = preload("res://scripts/puzzle/board_model.gd")
const CrystalSolver = preload("res://scripts/puzzle/solver.gd")

func _init() -> void:
    _test_orthogonal_consumption()
    _test_completion()
    _test_certified_solver()
    _test_efficiency_formula()
    print("Crystal Ants logic tests passed")
    quit()

func _board_with_cells(values: Array, width: int, colours: int) -> CrystalBoard:
    var board := CrystalBoard.new(width, int(values.size() / width), colours, 1, "test")
    board.cells = values.duplicate()
    board.captured = []
    board.captured.resize(values.size())
    for index in values.size():
        board.captured[index] = false
    board.current_color = int(board.cells[0])
    board.captured_count = 0
    board._capture_initial_region()
    board.move_count = 0
    return board

func _test_orthogonal_consumption() -> void:
    var board := _board_with_cells([0, 0, 1, 2, 0, 3, 2, 2, 2, 1, 1, 3, 3, 3, 2, 2], 4, 4)
    var result := board.apply_move(1)
    assert(result.valid)
    assert(result.consumed == 1)
    assert(board.is_captured(2))
    assert(not board.is_captured(5))
    assert(board.count_remaining_regions() > 0)

func _test_completion() -> void:
    var board := _board_with_cells([0, 1, 1, 0], 2, 2)
    var first := board.apply_move(1)
    assert(first.valid)
    assert(first.consumed == 2)
    var second := board.apply_move(0)
    assert(second.valid)
    assert(board.has_won())
    assert(board.move_count == 2)

func _test_certified_solver() -> void:
    var board := _board_with_cells([0, 1, 1, 0], 2, 2)
    var solution := CrystalSolver.solve(board)
    assert(solution.certified)
    assert(solution.moves == 2)
    assert(solution.path.size() == 2)

func _test_efficiency_formula() -> void:
    var certified_optimal := 4
    var actual_moves := 5
    var efficiency := float(certified_optimal) / float(actual_moves) * 100.0
    var excess_ratio := float(actual_moves - certified_optimal) / float(certified_optimal)
    assert(is_equal_approx(efficiency, 80.0))
    assert(is_equal_approx(excess_ratio, 0.25))
