# Research metrics data dictionary

This dictionary describes the compact event fields emitted by `CrystalTelemetry`. Records use anonymous participant codes and session IDs; no name, email, IP address or unnecessary fingerprint is collected by the Phase 1 client.

| Field | Operational meaning | Computation / unit |
|---|---|---|
| `participant_id` | Anonymous participant code | Locally assigned string; replace with consented study code at a future backend boundary |
| `session_id` | One gameplay session identifier | Random local string |
| `attempt_id` | One puzzle attempt within the session | Random local string |
| `puzzle_id` | Deterministic landmark and seed | Example: `merlion-3117` |
| `difficulty` | Standardised board condition | Phase 1: `standard-8x8` |
| `game_mode` | Selected mode | Adventure, Time Attack, Strategic Challenge, Daily Challenge or Research Mode |
| `timestamp` | Human-readable event timestamp | ISO wall-clock value for audit only |
| `relative_response_timestamp_ms` | Monotonic time from session start | `Time.get_ticks_usec() - started_usec`, converted to ms |
| `decision_latency_ms` | Time since previous meaningful action | Monotonic interval in ms |
| `crystals_consumed` | New cells acquired by one valid move | `|C' - C|` |
| `remaining_regions` | Uncaptured orthogonally connected same-colour components | Recomputed after the move |
| `remaining_crystals` | Cells outside the colony | `w×h - |C|` |
| `actual_moves` | Number of valid colour expansions | Counts atomic valid transitions; rejected selections do not increment |
| `certified_optimal_moves` | Exact shortest path length | Present only when the bounded BFS solver certifies the board |
| `move_efficiency_index` | Planning efficiency metric | `certified_optimal_moves / actual_moves × 100` |
| `excess_move_ratio` | Relative excess over certified optimum | `(actual_moves - certified_optimal_moves) / certified_optimal_moves` |
| `pause_time_ms` | Time paused | Accumulated monotonic pause intervals |
| `active_gameplay_time_ms` | Active play duration | Elapsed duration excluding recorded pauses where available |
| `certification_status` | Whether optimal metrics are safe to report | `certified` or `not_certified` |

## Interpretation limits

These variables describe performance within this game. They are not validated neuropsychological assessments and must not be converted into a clinical diagnosis or arbitrary composite cognitive score. Any study use needs consent, a private datastore, an approved protocol and an access-controlled researcher dashboard.
