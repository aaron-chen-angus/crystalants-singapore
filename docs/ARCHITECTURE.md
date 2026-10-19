# Crystal Ants: Singapore Quest — Phase 1 architecture

## Gameplay rule

The board is a rectangular grid `G = {0..w-1} × {0..h-1}`. Two cells are adjacent only when their Manhattan distance is one: `|(x1-x2)| + |(y1-y2)| = 1`. Diagonals are not adjacent. The colony is a connected set `C` with a current colour `c`. Selecting colour `k` computes the least fixed point of:

`C' = C ∪ { v ∉ C | colour(v)=k and v is orthogonally adjacent to C' }`.

The move is valid only when `C' ≠ C`. The game stores one atomic snapshot after every valid move, updates the colony, and then animates the already-authoritative result. Undo restores the prior snapshot; animation cannot mutate logic. The puzzle ends when `|C| = w×h`.

## Modules

- `scripts/puzzle/board_model.gd` — deterministic board generation, orthogonal flood expansion, region counting, snapshots and state identifiers.
- `scripts/puzzle/solver.gd` — breadth-first exact solver for boards of up to 64 cells. It returns a certified move count only when the search reaches the full mask within its state bound; larger boards must be labelled uncertified.
- `scripts/crystal_ants_main.gd` — rendering, input, screen flow, ant motion, crystal particles and local leaderboard. Rendering reads model state and never decides outcomes.
- `scripts/telemetry/telemetry_service.gd` — anonymised event records, monotonic in-session intervals and an offline queue in `user://crystal_ants_telemetry.json`.
- `scripts/core/localization.gd` — pinned English/Simplified Chinese copy and language toggle.

## Phase boundary

Phase 1 is intentionally self-contained and local-first. The telemetry queue is ready for a future HTTPS batch endpoint. Google Apps Script schema and validation guidance live in `docs/google-apps-script.gs`; no credentials are embedded. A production public leaderboard should add server-side replay verification before accepting rankings. Standardised cognitive mini-challenges, private dashboard authentication and authenticated Sheets ingestion are Phase 2–3 extension points, not claimed as delivered integrations.

## Metrics

`Move Efficiency Index = certified_optimal_moves / actual_moves × 100` and `Excess Move Ratio = (actual_moves - certified_optimal_moves) / certified_optimal_moves`. These are shown only when `certified_optimal_moves` is available. The game does not create or imply a clinical cognitive score.
