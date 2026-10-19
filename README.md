# Crystal Ants: Singapore Quest

A polished 2D strategy puzzle game about expanding an ant colony through Singapore landmark crystal mosaics. The first release includes playable Merlion, Marina Bay Sands and Gardens by the Bay boards, deterministic seeds, animated ant scouts, crystal dissolve particles, exact BFS certification for supported boards, undo/pause/restart/tutorial/hints, five play modes, English/Simplified Chinese copy, accessibility toggles and a local anonymous leaderboard.

## Run locally

Requires Godot 4.7.2 and Node.js. From the project root:

```bash
npm run check
npm run test:logic
godot --headless --audio-driver Dummy --path . --quit-after 2
```

The managed Game preview uses the current session `HOST` and `PORT` and the supplied runtime server. For a direct native run, use the editor or `godot --path .`.

## Controls

Choose a landmark, select a colour, and consume every orthogonally connected matching frontier region. Diagonals never count. Keyboard shortcuts: `1–7` choose a colour, `U` undo, `H` hint, `P` pause, `Esc` return to the map. Large on-screen buttons support touchscreen and mouse play.

## Architecture and research boundary

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the exact state transition rule and module map. [`docs/RESEARCH_DATA_DICTIONARY.md`](docs/RESEARCH_DATA_DICTIONARY.md) defines telemetry fields. [`docs/google-apps-script.gs`](docs/google-apps-script.gs) is a private-backend schema starter only; no Google credentials are included, and no live Sheets integration is claimed until a consented backend is configured and verified.

Telemetry is anonymous and queued locally in `user://crystal_ants_telemetry.json`. Certified efficiency metrics are displayed only when the solver proves a shortest path within its stated 64-cell support and state bound. The game does not provide a clinical cognitive score.

## GitHub Pages handoff

The Godot Web export is prepared by the Manus Game runtime. The repository contains the project source and a GitHub Actions workflow scaffold. Connect the prepared `site/` payload to GitHub Pages only after the managed Web export has been created; do not commit `dist/`, `.godot/`, secrets or private research exports.

## Known limitations / next phases

- Phase 1 uses local telemetry and a demo leaderboard; authenticated public rankings and Google Sheets ingestion require a server-side validation boundary.
- The exact solver is certified only for boards up to 64 cells and its configured search bound; uncertified boards must not be presented as optimal.
- The standardised Crystal Rush, Memory, Calculation, Spatial Navigator, Flexibility and Selective Attention modules plus private researcher dashboard are documented extension points for Phase 2–3.
- Browser input/audio/layout acceptance still needs final human acceptance in the published Web build; headless checks do not claim that acceptance.
