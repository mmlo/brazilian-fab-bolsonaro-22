import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runGodotCheck } from './godot-check.mjs'
const root = dirname(dirname(fileURLToPath(import.meta.url)))
const godot = process.env.GODOT_BIN || 'godot'
for (const [script, marker, extra] of [
  ['smoke', '[SMOKE_PASS]', []],
  ['localization', '[STARVEIL_LOCALIZATION_PASS]', []],
  // Full-stage bot run (god mode) — slower; skip with SKIP_PLAYTHROUGH=1
  ...(process.env.SKIP_PLAYTHROUGH ? [] : [['playthrough', '[PLAYTHROUGH_PASS]', ['--fixed-fps', '60']]]),
]) {
  runGodotCheck(godot, ['--headless', '--audio-driver', 'Dummy', ...extra, '--path', root, '--script', `test/${script}.gd`], marker, root)
}
