import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { runGodotCheck } from './godot-check.mjs'

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const managedVerifier = process.env.GAME_RUNTIME
  ? resolve(process.env.GAME_RUNTIME, 'scripts/verify-game.mjs')
  : resolve(projectRoot, '.manus-game-tools/scripts/verify-game.mjs')
const packPath = process.argv[2] ? resolve(projectRoot, process.argv[2])
  : process.env.GAME_RUNTIME || existsSync(managedVerifier) ? (await import(pathToFileURL(managedVerifier).href)).verifiedPack(projectRoot).path
  : resolve(projectRoot, 'dist/index.pck')
const godot = process.env.GODOT_BIN || 'godot'

if (!existsSync(packPath)) {
  throw new Error(`exported pack not found: ${packPath}`)
}

const preset = readFileSync(resolve(projectRoot, 'export_presets.cfg'), 'utf8')
const filterMatch = preset.match(/^exclude_filter="([^"]*)"$/m)
if (!filterMatch) throw new Error('Web export exclude_filter not found')
const excludePatterns = filterMatch[1]
  .split(',')
  .map((pattern) => pattern.trim())
  .filter(Boolean)
const directoryPattern = /^([^*?]+)\/\*$/
const excludedDirectories = excludePatterns.map((pattern) => pattern.match(directoryPattern)?.[1]).filter(Boolean)
const unsupportedPatterns = excludePatterns.filter((pattern) => !directoryPattern.test(pattern))
if (excludedDirectories.length === 0) throw new Error('Web export has no directory exclusions')
if (unsupportedPatterns.length > 0) {
  console.warn(`[PCK_CONTENTS_WARN] patterns not verified: ${unsupportedPatterns.join(', ')}`)
}

const runDirectory = mkdtempSync(join(tmpdir(), 'game-pck-check-'))
const contentsProbe = resolve(runDirectory, 'exported_pack_contents.gd')
const requiredDirectoryLines = ['scenes', 'scripts']
  .map((directory) => `\t${JSON.stringify(`res://${directory}`)},`)
  .join('\n')
const directoryLines = excludedDirectories.map((directory) => `\t${JSON.stringify(`res://${directory}`)},`).join('\n')
writeFileSync(
  contentsProbe,
  `extends SceneTree\n\nconst REQUIRED_DIRECTORIES := [\n${requiredDirectoryLines}\n]\nconst EXCLUDED_DIRECTORIES := [\n${directoryLines}\n]\n\nfunc _initialize() -> void:\n\tfor directory in REQUIRED_DIRECTORIES:\n\t\tif not DirAccess.dir_exists_absolute(directory):\n\t\t\tpush_error("[PCK_CONTENTS_FAIL] pack not mounted or required directory missing: " + directory)\n\t\t\tquit(1)\n\t\t\treturn\n\tfor directory in EXCLUDED_DIRECTORIES:\n\t\tif DirAccess.dir_exists_absolute(directory):\n\t\t\tpush_error("[PCK_CONTENTS_FAIL] excluded directory present: " + directory)\n\t\t\tquit(1)\n\t\t\treturn\n\tprint("[PCK_CONTENTS_PASS] required directories present and excluded directories absent")\n\tquit(0)\n`,
)

const checks = [
  [contentsProbe, '[PCK_CONTENTS_PASS]'],
  [resolve(projectRoot, 'test/exported_pack_boot.gd'), '[PCK_BOOT_PASS]'],
]

let failed = false
try {
  for (const [script, marker] of checks) {
    try {
      runGodotCheck(godot, ['--headless', '--main-pack', packPath, '--script', script], marker, runDirectory)
    } catch (error) {
      if (error?.code === 'ENOENT') {
        console.error(`[PCK_CHECK_FAIL] Godot binary not found: ${godot}; set GODOT_BIN to override`)
      } else {
        console.error(`[PCK_CHECK_FAIL] ${script}: ${error instanceof Error ? error.message : String(error)}`)
      }
      failed = true
      break
    }
  }
} finally {
  rmSync(runDirectory, { recursive: true, force: true })
}

if (failed) process.exitCode = 1
