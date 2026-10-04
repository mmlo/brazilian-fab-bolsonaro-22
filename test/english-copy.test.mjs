import assert from 'node:assert/strict'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const root = dirname(dirname(fileURLToPath(import.meta.url)))

function gdFiles(dir) {
  const out = []
  for (const name of readdirSync(join(root, dir))) {
    const rel = `${dir}/${name}`
    if (statSync(join(root, rel)).isDirectory()) out.push(...gdFiles(rel))
    else if (name.endsWith('.gd')) out.push(rel)
  }
  return out
}

test('player-facing copy lives in localization catalogs, not in scripts', () => {
  for (const path of ['project.godot', ...gdFiles('scripts'), ...gdFiles('autoload')]) {
    const source = readFileSync(join(root, path), 'utf8')
    // "简体中文" is the language's own name in the language selector.
    assert.doesNotMatch(source.replaceAll('简体中文', ''), /\p{Script=Han}/u, path)
  }
})

test('UI font chain bundles Exo 2 with Noto Sans SC fallback', () => {
  const composite = readFileSync(join(root, 'assets/template/fonts/ui_regular.tres'), 'utf8')
  assert.ok(composite.includes('res://assets/template/fonts/Exo2-VF.subset.woff2'))
  assert.ok(composite.includes('res://assets/template/fonts/noto_sans_sc_regular.tres'))
  const ui = readFileSync(join(root, 'scripts/ui/pixel_ui.gd'), 'utf8')
  assert.ok(ui.includes('res://assets/template/fonts/'), 'PixelUI loads the bundled fonts')
})

test('EN and zh-CN catalogs share every key', () => {
  const en = JSON.parse(readFileSync(join(root, 'localization/en.json'), 'utf8'))
  const zh = JSON.parse(readFileSync(join(root, 'localization/zh-CN.json'), 'utf8'))
  assert.deepEqual(Object.keys(en).sort(), Object.keys(zh).sort())
})
