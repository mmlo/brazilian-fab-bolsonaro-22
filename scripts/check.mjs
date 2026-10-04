// A finite smoke check; long-running Preview belongs to npm run dev.
import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { runGodotCheck } from './godot-check.mjs'

const root = dirname(dirname(fileURLToPath(import.meta.url)))
runGodotCheck(process.env.GODOT_BIN || 'godot',
  ['--headless', '--path', root, '--script', 'test/smoke.gd'],
  '[SMOKE_PASS]', root)
