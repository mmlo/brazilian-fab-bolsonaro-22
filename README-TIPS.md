Sim. **O projeto já está preparado para exportação Web/HTML5** e possui uma estrutura relativamente boa para adicionar fases e áudio.

## 1. Como criar novas fases

A fase atual está concentrada principalmente em:

- `scripts/data/stage_1.gd`
- `scripts/data/enemy_types.gd`
- `scripts/combat/bullet_patterns.gd`
- `scripts/game.gd`
- `scripts/config/game_config.gd`

O arquivo `stage_1.gd` é orientado a dados. Ele define:

- Ondas de inimigos.
- Tempo de surgimento.
- Tipo de trajetória.
- Posição inicial.
- Quantidade e espaçamento.
- Padrões de tiro.
- Fases do chefe.
- Vida e comportamento do chefe.

### Adicionando uma nova onda

Dentro de `scripts/data/stage_1.gd`, `WAVES` é uma lista. Uma nova onda pode ser adicionada assim:

```gdscript
{
	"name_key": "wave.4.name",
	"max_time": 52.0,
	"events": [
		{
			"at": 1.0,
			"enemy": "drone",
			"path": "dive",
			"x": 0.20,
			"count": 8,
			"gap": 0.22,
			"dx": 0.10,
			"speed": 95,
			"mirror": true,
			"fire": {
				"pattern": "aimed",
				"count": 2,
				"spread": 18,
				"speed": 92,
				"shape": "orb",
				"color": "pink",
				"delay": 0.6,
				"interval": 1.5,
				"shots": 3
			}
		},
		{
			"at": 12.0,
			"enemy": "carrier",
			"path": "stop",
			"x": 0.5,
			"stop_y": 75,
			"hold": 16.0,
			"speed": 28,
			"fire": {
				"pattern": "spiral",
				"arms": 4,
				"speed": 55,
				"spin": 12,
				"shape": "rice",
				"color": "violet",
				"delay": 1.5,
				"interval": 0.22,
				"shots": 999
			}
		}
	]
}
```

Os caminhos atualmente disponíveis incluem:

```text
dive
curve
stop
sweep
```

E os padrões de projéteis existentes incluem:

```text
aimed
fixed
ring
spiral
petal
curtain
rain
```

### Adicionando uma nova fase de chefe

No dicionário `BOSS`, adicione outra entrada em `phases`:

```gdscript
{
	"name_key": "boss.phase4",
	"hp": 2600.0,
	"time": 80.0,
	"sprite": "boss_p3",
	"move": "figure8",
	"rage_at": 0.25,
	"rage": 0.70,
	"emitters": [
		{
			"origin": Vector2(0, 12),
			"interval": 0.18,
			"delay": 0.8,
			"fire": {
				"pattern": "ring",
				"count": 20,
				"speed": 72,
				"rot_step": 9,
				"shape": "big",
				"color": "orange"
			}
		}
	]
}
```

Também será necessário adicionar as traduções correspondentes:

```json
{
  "boss.phase4": "Impact Cascade: Final Lock",
  "wave.4.name": "Orbital Interception"
}
```

A mesma chave deve existir em:

```text
localization/en.json
localization/zh-CN.json
```

### Criar uma campanha com várias fases

Atualmente o jogo usa `StageData` diretamente em vários pontos de `game.gd` e `hud.gd`. Para suportar várias campanhas, o ideal é trocar as referências diretas por uma variável:

```gdscript
var current_stage = StageData
```

Depois, substituir chamadas como:

```gdscript
StageData.WAVES
StageData.BOSS
```

por:

```gdscript
current_stage.WAVES
current_stage.BOSS
```

Assim você pode criar:

```text
scripts/data/stage_1.gd
scripts/data/stage_2.gd
scripts/data/stage_3.gd
```

E selecionar a fase:

```gdscript
func load_stage(stage_number: int) -> void:
	match stage_number:
		1:
			current_stage = StageData
		2:
			current_stage = Stage2Data
		3:
			current_stage = Stage3Data
```

Também será necessário atualizar:

- Tela de seleção de fase.
- Nome e descrição da fase.
- Música específica.
- Background.
- Testes em `test/smoke.gd`.
- Barra de progresso em `hud.gd`.
- Fluxo de vitória em `game.gd`.

### Melhorias recomendadas no sistema de fases

Para um projeto maior, eu recomendaria:

1. **Separar cada fase em um arquivo próprio**, em vez de deixar tudo em `stage_1.gd`.
2. Criar uma função de validação para detectar eventos inválidos antes de executar o jogo.
3. Usar recursos `.tres` do Godot para editar fases pelo Inspector.
4. Adicionar multiplicadores por fase:
   - Velocidade dos projéteis.
   - Densidade de inimigos.
   - Vida dos inimigos.
   - Frequência de disparos.
5. Criar eventos especiais:
   - Chuva de meteoros.
   - Satélites quebrados.
   - Campo gravitacional.
   - Interferência no HUD.
   - Trechos sem tiros para recuperação.
6. Usar **object pooling** para projéteis e partículas em fases muito intensas.
7. Adicionar um sistema de sementes aleatórias para que fases procedurais possam ser reproduzidas:

```gdscript
var rng := RandomNumberGenerator.new()

func start_stage(seed_value: int) -> void:
	rng.seed = seed_value
```

---

## 2. Como adicionar efeitos sonoros

O projeto já possui um sistema centralizado em:

```text
autoload/audio_director.gd
```

Os efeitos estão organizados em:

```text
assets/audio/sfx/
```

E as músicas em:

```text
assets/audio/music/
```

O sistema atual já possui efeitos como:

```text
shoot
enemy_hit
explode_small
explode_big
graze
pickup
energy_full
bomb
player_hit
boss_break
warning
enemy_fire
combo_up
charge
victory
defeat
```

### Adicionar um novo efeito sonoro

1. Coloque um arquivo `.ogg` em:

```text
assets/audio/sfx/meteor_warning.ogg
```

2. Registre o efeito em `_cues` dentro de `autoload/audio_director.gd`:

```gdscript
"meteor_warning": [
	preload("res://assets/audio/sfx/meteor_warning.ogg"),
	-4.0, # volume em dB
	2,    # quantidade de vozes simultâneas
	0.15, # intervalo mínimo entre execuções
	0.05  # variação de pitch
],
```

3. Execute o som no código:

```gdscript
AudioDirector.play("meteor_warning")
```

Por exemplo, quando uma nova onda começa:

```gdscript
func _begin_wave(index: int) -> void:
	AudioDirector.play("warning")
	# restante da lógica da onda
```

### Recomendações para os efeitos

- Prefira `.ogg` para Web.
- Use sons curtos, normalmente entre 0,05 e 1,5 segundos.
- Evite muitos efeitos com volume alto simultaneamente.
- Use `pitch_jitter` para evitar que todos os disparos soem idênticos.
- Mantenha sons repetitivos com volume baixo.
- Use pools para tiros e impactos frequentes, como o sistema atual já faz.

---

## 3. Como adicionar trilha sonora personalizada

O sistema já possui duas músicas registradas:

```gdscript
const MUSIC := {
	"stage": preload("res://assets/audio/music/stage.ogg"),
	"boss": preload("res://assets/audio/music/boss.ogg"),
}
```

Para adicionar uma música de uma nova fase:

```gdscript
const MUSIC := {
	"stage": preload("res://assets/audio/music/stage.ogg"),
	"boss": preload("res://assets/audio/music/boss.ogg"),
	"stage_2": preload("res://assets/audio/music/stage_2.ogg"),
	"stage_3": preload("res://assets/audio/music/stage_3.ogg"),
}
```

Depois, altere a música quando a fase começar:

```gdscript
AudioDirector.play_music("stage_2", true)
```

O segundo parâmetro `true` força o reinício da música.

Para trocar de música durante um chefe:

```gdscript
AudioDirector.fade_music(1.0)
AudioDirector.play_music("boss_2", true)
```

Você também pode adicionar uma nova música de chefe:

```gdscript
const MUSIC := {
	"stage": preload("res://assets/audio/music/stage.ogg"),
	"boss": preload("res://assets/audio/music/boss.ogg"),
	"boss_2": preload("res://assets/audio/music/boss_2.ogg"),
}
```

### Formato recomendado

Para Web:

```text
OGG Vorbis
44.1 kHz
estéreo ou mono
loop musical limpo
```

Uma trilha de 2 a 4 minutos em loop costuma ser suficiente para cada fase.

O projeto já usa `BrowserBgmPlayer`, que trata a reprodução de música no navegador. Ainda assim, browsers normalmente bloqueiam áudio automático antes da primeira interação do jogador. Por isso, a música pode começar somente após o usuário clicar ou pressionar uma tecla.

---

## 4. É possível transformar em HTML5 e jogar no navegador?

**Sim. O projeto já está configurado para isso.**

O preset Web está em:

```text
export_presets.cfg
```

E o `package.json` já possui:

```json
{
  "export": "mkdir -p dist && godot --headless --path . --export-release Web dist/index.html",
  "verify-export": "node scripts/check-exported-pack.mjs"
}
```

### Exportar localmente

Dentro da pasta do projeto:

```bash
npm run export
```

Isso gera:

```text
dist/index.html
```

Depois valide o pacote:

```bash
npm run verify-export
```

### Executar localmente no navegador

Não abra o `index.html` diretamente com `file://`. O WebAssembly e os arquivos `.pck` podem ser bloqueados pelo navegador.

Use um servidor HTTP:

```bash
python3 -m http.server 8080 --directory dist
```

Depois abra:

```text
http://localhost:8080
```

Outra opção é usar:

```bash
npm run dev
```

O projeto já possui um servidor de Preview próprio.

### Onde hospedar

O conteúdo da pasta `dist/` pode ser colocado em serviços de hospedagem estática, como:

- itch.io;
- GitHub Pages;
- Netlify;
- Cloudflare Pages;
- Vercel;
- servidor próprio com Nginx ou Apache.

O servidor precisa entregar corretamente:

```text
.html
.js
.wasm
.pck
```

Em geral, hospedagens estáticas modernas já suportam esses arquivos.

### Compatibilidade Web atual

O preset atual usa:

```ini
renderer/rendering_method="gl_compatibility"
variant/thread_support=false
```

Isso é uma boa escolha para compatibilidade ampla, principalmente em:

- Chrome;
- Edge;
- Firefox;
- Safari moderno;
- celulares e tablets razoavelmente recentes.

O projeto também usa:

```text
web/loading.html
```

como shell de carregamento personalizado.

### Threads no Web

O suporte a threads está desativado atualmente:

```ini
variant/thread_support=false
```

Isso simplifica a hospedagem e evita exigências especiais de cabeçalhos HTTP.

Se você ativar threads futuramente, o servidor normalmente precisará enviar:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Para esse jogo, eu manteria threads desativadas inicialmente, porque o renderizador 2D atual já é adequado para Web.

## Resumo

O caminho recomendado é:

1. Criar `stage_2.gd`.
2. Tornar `current_stage` configurável em `game.gd` e `hud.gd`.
3. Adicionar novas chaves em inglês e chinês.
4. Criar músicas em `assets/audio/music/`.
5. Registrar efeitos em `AudioDirector`.
6. Executar:

```bash
npm run export
npm run verify-export
python3 -m http.server 8080 --directory dist
```

O projeto atual já pode ser jogado via browser; ele não precisa ser convertido para outro framework.
