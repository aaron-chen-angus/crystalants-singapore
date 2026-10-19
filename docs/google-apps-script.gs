/* Crystal Ants: Singapore Quest — Phase 2 Google Sheets schema
 * This file documents a backend shape only. Do not paste secrets into the game client.
 * Deploy Apps Script as a private web app only after consent, access control and rate limits are configured.
 */

const SHEETS = [
  'Participants', 'Sessions', 'Levels', 'Puzzle_Results',
  'Move_Events', 'Cognitive_Tasks', 'Leaderboard_Results', 'Research_Dashboard'
];

const HEADERS = {
  Participants: ['participant_id', 'consent_version', 'consent_timestamp', 'withdrawn'],
  Sessions: ['session_id', 'participant_id', 'attempt_id', 'game_mode', 'start_timestamp', 'finish_timestamp', 'device_category'],
  Levels: ['puzzle_id', 'landmark', 'difficulty', 'seed', 'width', 'height', 'colour_count', 'solver_status'],
  Puzzle_Results: ['event_id', 'session_id', 'puzzle_id', 'actual_moves', 'certified_optimal_moves', 'move_efficiency_index', 'excess_move_ratio', 'active_gameplay_time_ms'],
  Move_Events: ['event_id', 'session_id', 'attempt_id', 'previous_state_id', 'player_action', 'relative_response_timestamp_ms', 'resulting_state_id', 'crystals_consumed', 'remaining_regions', 'remaining_crystals', 'decision_latency_ms'],
  Cognitive_Tasks: ['event_id', 'session_id', 'task_type', 'stimulus_id', 'accuracy', 'response_latency_ms', 'error_type'],
  Leaderboard_Results: ['verified_replay_id', 'anonymous_display_name', 'puzzle_id', 'score_band', 'verified_at'],
  Research_Dashboard: ['metric_name', 'metric_value', 'cohort_filter', 'computed_at']
};

function setupCrystalAntsWorkbook() {
  const workbook = SpreadsheetApp.getActive();
  SHEETS.forEach(name => {
    const sheet = workbook.getSheetByName(name) || workbook.insertSheet(name);
    sheet.clear();
    sheet.getRange(1, 1, 1, HEADERS[name].length).setValues([HEADERS[name]]);
    sheet.setFrozenRows(1);
  });
}

function doPost(request) {
  // Production implementation must validate an authenticated study token, schema, consent,
  // event_id idempotency and a bounded request size before taking a LockService lock.
  // Append only server-validated rows; never accept client scores as public leaderboard authority.
  return ContentService.createTextOutput(JSON.stringify({ok: false, reason: 'configure-private-ingestion-before-deployment'}))
    .setMimeType(ContentService.MimeType.JSON);
}

/* Deployment notes:
 * 1. Keep the workbook private and share only with approved researchers.
 * 2. Add server-side authentication/consent checks and LockService around writes.
 * 3. Reject duplicate event_id values and rate-limit by study token.
 * 4. Export aggregate CSVs for analysis; do not expose participant-level rows publicly.
 * 5. Verify ingestion with a test sheet and a controlled consented pilot before enabling upload.
 */
