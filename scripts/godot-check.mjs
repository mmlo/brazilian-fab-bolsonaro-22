import { spawnSync } from 'node:child_process'

export function runGodotCheck(command, args, marker, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: 'utf8',
    timeout: 120_000,
    maxBuffer: 8 * 1024 * 1024,
  })
  const output = `${result.stdout || ''}\n${result.stderr || ''}`
  if (result.error || result.status !== 0 || !output.includes(marker) || /(?:SCRIPT ERROR:|^ERROR:)/m.test(output)) {
    throw new Error(`Godot check failed (${marker}): ${result.error?.message || `exit ${result.status}`}\n${output}`)
  }
  process.stdout.write(output)
}
