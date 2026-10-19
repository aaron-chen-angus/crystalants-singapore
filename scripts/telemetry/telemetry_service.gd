class_name CrystalTelemetry
extends RefCounted

var participant_id := "participant-local"
var session_id := ""
var attempt_id := ""
var started_usec: int = 0
var last_action_usec: int = 0
var active_gameplay_usec: int = 0
var paused_usec: int = 0
var pause_started_usec: int = 0
var events: Array = []
var offline_queue: Array = []

func start_session(puzzle_id: String, difficulty: String, mode: String) -> void:
    session_id = "s-%s-%s" % [str(Time.get_unix_time_from_system()), str(randi() % 100000)]
    attempt_id = "a-%s" % str(randi() % 1000000)
    started_usec = Time.get_ticks_usec()
    last_action_usec = started_usec
    events.clear()
    record_event("session_started", {
        "participant_id": participant_id,
        "session_id": session_id,
        "attempt_id": attempt_id,
        "puzzle_id": puzzle_id,
        "difficulty": difficulty,
        "game_mode": mode,
        "device_category": "browser",
        "input_method": "keyboard_or_touch",
    })

func record_move(previous_state: String, action: int, resulting_state: String, consumed: int, remaining_regions: int, remaining_crystals: int, puzzle_id: String, difficulty: String) -> void:
    var now := Time.get_ticks_usec()
    var decision_latency := now - last_action_usec
    active_gameplay_usec += decision_latency
    last_action_usec = now
    record_event("move", {
        "previous_state_id": previous_state,
        "player_action": action,
        "relative_response_timestamp_ms": float(now - started_usec) / 1000.0,
        "resulting_state_id": resulting_state,
        "crystals_consumed": consumed,
        "remaining_regions": remaining_regions,
        "remaining_crystals": remaining_crystals,
        "puzzle_id": puzzle_id,
        "difficulty": difficulty,
        "decision_latency_ms": float(decision_latency) / 1000.0,
    })

func record_event(event_type: String, payload: Dictionary) -> void:
    var event := payload.duplicate(true)
    event["event_id"] = "%s-%s" % [event_type, str(events.size() + offline_queue.size() + 1)]
    event["event_type"] = event_type
    event["session_id"] = session_id
    event["timestamp"] = Time.get_datetime_string_from_system(true)
    events.append(event)
    offline_queue.append(event)

func set_paused(is_paused: bool) -> void:
    var now := Time.get_ticks_usec()
    if is_paused:
        pause_started_usec = now
    elif pause_started_usec > 0:
        paused_usec += now - pause_started_usec
        pause_started_usec = 0

func finish_session(actual_moves: int, certified_optimal_moves: int, puzzle_id: String, difficulty: String) -> Dictionary:
    var total_usec := Time.get_ticks_usec() - started_usec
    var certified := certified_optimal_moves >= 0
    var efficiency := -1.0
    var excess_ratio := -1.0
    if certified and actual_moves > 0:
        efficiency = float(certified_optimal_moves) / float(actual_moves) * 100.0
        excess_ratio = float(actual_moves - certified_optimal_moves) / float(certified_optimal_moves)
    var summary := {
        "participant_id": participant_id,
        "session_id": session_id,
        "attempt_id": attempt_id,
        "puzzle_id": puzzle_id,
        "difficulty": difficulty,
        "total_elapsed_time_ms": float(total_usec) / 1000.0,
        "active_gameplay_time_ms": float(max(active_gameplay_usec, total_usec - paused_usec)) / 1000.0,
        "pause_time_ms": float(paused_usec) / 1000.0,
        "actual_moves": actual_moves,
        "certified_optimal_moves": certified_optimal_moves,
        "move_efficiency_index": efficiency,
        "excess_move_ratio": excess_ratio,
        "certification_status": "certified" if certified else "not_certified",
    }
    record_event("session_finished", summary)
    persist_queue()
    return summary

func persist_queue() -> void:
    var file := FileAccess.open("user://crystal_ants_telemetry.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(offline_queue))

func queued_event_count() -> int:
    return offline_queue.size()
