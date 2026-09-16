#!/bin/bash
# Instalador do VoiceBar: leitura em voz alta das respostas do Claude Code.
# Seguro de rodar mais de uma vez: refaz só o que estiver faltando.
# Uso:  ./install.sh            instala tudo
#       ./install.sh --sem-modelos   pula o download das vozes (usa as já baixadas)

SRC="$(cd "$(dirname "$0")" && pwd)/src"
V="$HOME/.claude/voice"
H="$HOME/.claude/hooks"
SKIP_MODELS=0
[ "${1:-}" = "--sem-modelos" ] && SKIP_MODELS=1

ok(){   printf "  \033[32m✓\033[0m %s\n" "$*"; }
info(){ printf "  · %s\n" "$*"; }
warn(){ printf "  \033[33m!\033[0m %s\n" "$*"; }
die(){  printf "\n  \033[31m✗ %s\033[0m\n\n" "$*" >&2; exit 1; }
step(){ printf "\n\033[1m%s\033[0m\n" "$*"; }

# ─────────────────────────────────────────────────────────── 1. pré-requisitos
step "1/9  Conferindo o que a máquina já tem"

[ "$(uname -s)" = "Darwin" ] || die "Este instalador é só para macOS."
info "macOS $(sw_vers -productVersion) em $(uname -m)"

command -v swiftc >/dev/null 2>&1 || die "Falta o compilador Swift. Instale as ferramentas de linha de comando com:  xcode-select --install"
ok "compilador Swift"

command -v jq >/dev/null 2>&1 || die "Falta o jq. Instale com:  brew install jq"
ok "jq"

command -v brew >/dev/null 2>&1 || die "Falta o Homebrew. Veja https://brew.sh"
ok "Homebrew"

# O Kokoro ainda não roda em Python 3.13 ou mais novo, então precisa do 3.12.
PY312=""
for c in /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12 "$(command -v python3.12 2>/dev/null)"; do
  [ -x "$c" ] && { PY312="$c"; break; }
done
if [ -z "$PY312" ]; then
  info "instalando o Python 3.12, exigido pelo Kokoro (pode demorar)"
  brew install python@3.12 >/dev/null 2>&1 || die "Não consegui instalar o python@3.12."
  for c in /opt/homebrew/bin/python3.12 /usr/local/bin/python3.12; do [ -x "$c" ] && PY312="$c"; done
fi
[ -n "$PY312" ] || die "Python 3.12 não encontrado mesmo depois de instalar."
ok "Python 3.12 em $PY312"

PY3="$(command -v python3)" || die "Falta o python3."
ok "Python padrão $($PY3 -V 2>&1 | cut -d' ' -f2)"

# ────────────────────────────────────────────────────────────── 2. os arquivos
step "2/9  Copiando os scripts"
mkdir -p "$V/models" "$V/kokoro" "$V/run/q" "$H"
cp "$SRC/VoiceBar.swift" "$SRC/voice" "$SRC/synth.sh" "$SRC/speak.py" \
   "$SRC/speak_kokoro.py" "$SRC/read-selection.sh" "$SRC/summarize.sh" "$SRC/voices.txt" "$V/"
chmod +x "$V/voice" "$V/synth.sh" "$V/speak.py" "$V/speak_kokoro.py" \
         "$V/read-selection.sh" "$V/summarize.sh"
mkdir -p "$V/lang"
cp "$SRC"/lang/*.conf "$SRC"/lang/*.prompt "$V/lang/"
[ -f "$V/lang.active" ] || echo pt-BR > "$V/lang.active"
cp "$SRC/hooks/speak-response.sh" "$SRC/hooks/speak-response.py" "$SRC/hooks/voice-alert.sh" "$H/"
chmod +x "$H/speak-response.sh" "$H/speak-response.py" "$H/voice-alert.sh"
ok "scripts e pacotes de idioma instalados"

# ajustes padrão, sem sobrescrever escolhas que já existam
seed(){ [ -f "$V/$1" ] || printf '%s\n' "$2" > "$V/$1"; }
seed current  cadu
seed volume   1.0
seed speed    1.0
seed mode     fila
seed pause    media
seed announce 1
seed alerts   1
[ -f "$V/muted.txt" ]    || : > "$V/muted.txt"
[ -f "$V/projects.txt" ] || : > "$V/projects.txt"
[ -f "$V/labels.txt" ]   || : > "$V/labels.txt"
[ -f "$V/summary_prompt.txt" ] || : > "$V/summary_prompt.txt"
if [ ! -f "$V/summary.conf" ]; then
  printf 'enabled=0\nmin_words=60\nmode=percent\nmodel=\npercent=25\nwords=60\n' > "$V/summary.conf"
fi
ok "ajustes padrão criados"

# ─────────────────────────────────────────────────────────── 3. motor Piper
step "3/9  Instalando o Piper (voz local rápida)"
if [ ! -x "$V/venv/bin/python" ]; then
  "$PY3" -m venv "$V/venv" >/dev/null 2>&1 || die "Não consegui criar o ambiente do Piper."
fi
"$V/venv/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1
"$V/venv/bin/pip" install --quiet piper-tts >/dev/null 2>&1 \
  || die "Falha ao instalar o piper-tts."
"$V/venv/bin/python" -c "import piper" 2>/dev/null || die "O piper não importa."
ok "piper-tts instalado"

# O wheel do Piper traz um caminho de dados gravado em tempo de compilação, que não
# existe nesta máquina. Este diretório de atalhos contorna isso.
ESPD="$(ls -d "$V"/venv/lib/python*/site-packages/piper/espeak-ng-data 2>/dev/null | head -1)"
[ -n "$ESPD" ] || die "Não achei os dados de fonemas do Piper."
rm -rf "$V/esp"; mkdir -p "$V/esp"
ln -s "$ESPD"/* "$V/esp/" 2>/dev/null
ln -s "$ESPD" "$V/esp/espeak-ng-data" 2>/dev/null
ok "dados de fonemas ligados"

# ─────────────────────────────────────────────────────────── 4. motor Kokoro
step "4/9  Instalando o Kokoro (voz local mais natural)"
if [ ! -x "$V/kvenv/bin/python" ]; then
  "$PY312" -m venv "$V/kvenv" >/dev/null 2>&1 || die "Não consegui criar o ambiente do Kokoro."
fi
"$V/kvenv/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1
"$V/kvenv/bin/pip" install --quiet kokoro-onnx soundfile >/dev/null 2>&1 \
  || die "Falha ao instalar o kokoro-onnx."
"$V/kvenv/bin/python" -c "import kokoro_onnx" 2>/dev/null || die "O kokoro-onnx não importa."
ok "kokoro-onnx instalado"

# ─────────────────────────────────────────────────────────────── 5. as vozes
step "5/9  Baixando as vozes (cerca de 620 MB na primeira vez)"
if [ "$SKIP_MODELS" = "1" ]; then
  warn "pulado a pedido (--sem-modelos)"
else
  HF="https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR"
  baixa_piper(){  # nome qualidade
    [ -s "$V/models/$1.onnx" ] && { info "$1 já estava aqui"; return; }
    info "baixando a voz $1"
    curl -fsSL --retry 2 -o "$V/models/$1.onnx"      "$HF/$1/$2/pt_BR-$1-$2.onnx"      || die "falhou baixar $1"
    curl -fsSL --retry 2 -o "$V/models/$1.onnx.json" "$HF/$1/$2/pt_BR-$1-$2.onnx.json" || die "falhou baixar a config de $1"
  }
  baixa_piper cadu medium
  baixa_piper faber medium
  baixa_piper jeff medium
  baixa_piper edresson low

  KR="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
  if [ -s "$V/kokoro/kokoro.onnx" ]; then info "modelo do Kokoro já estava aqui"; else
    info "baixando o modelo do Kokoro (310 MB)"
    curl -fsSL --retry 2 -o "$V/kokoro/kokoro.onnx" "$KR/kokoro-v1.0.onnx" || die "falhou baixar o Kokoro"
  fi
  if [ -s "$V/kokoro/voices.bin" ]; then info "vozes do Kokoro já estavam aqui"; else
    curl -fsSL --retry 2 -o "$V/kokoro/voices.bin" "$KR/voices-v1.0.bin" || die "falhou baixar as vozes do Kokoro"
  fi
  ok "sete vozes brasileiras prontas"
fi

# ──────────────────────────────────────────────────────────── 6. app da barra
step "6/9  Compilando o app da barra de menus"
swiftc -O -swift-version 5 -o "$V/voicebar.new" "$V/VoiceBar.swift" 2>/dev/null \
  || die "A compilação falhou. Confira se o Xcode Command Line Tools está completo."
launchctl bootout "gui/$(id -u)/com.claude.voicebar" 2>/dev/null
pkill -x voicebar 2>/dev/null
sleep 1
mv "$V/voicebar.new" "$V/voicebar"
ok "app compilado"

# ───────────────────────────────────────────────────── 7. hook do Claude Code
step "7/9  Ligando o hook do Claude Code"
S="$HOME/.claude/settings.json"
[ -f "$S" ] || echo '{}' > "$S"
cp "$S" "$S.bak-$(date +%Y%m%d%H%M%S)"
TMP="$(mktemp)"
# acrescenta o hook Stop preservando tudo o que já existir no arquivo
jq '
  .hooks //= {} |
  .hooks.Stop //= [] |
  if ([.hooks.Stop[]?.hooks[]?.command] | any(. == "~/.claude/hooks/speak-response.sh"))
  then .
  else .hooks.Stop += [{"hooks":[{"type":"command","command":"~/.claude/hooks/speak-response.sh","timeout":30,"async":true}]}]
  end
' "$S" > "$TMP" && mv "$TMP" "$S" || die "Não consegui editar o settings.json (backup preservado)."
jq -e '[.hooks.Stop[]?.hooks[]?.command] | any(. == "~/.claude/hooks/speak-response.sh")' "$S" >/dev/null \
  || die "O hook não ficou registrado."

# avisos: pergunta, permissão, espera e erro
TMP2="$(mktemp)"
jq '
  def add($ev; $arg):
    .hooks[$ev] //= [] |
    if ([.hooks[$ev][]?.hooks[]?.command] | any(startswith("~/.claude/hooks/voice-alert.sh")))
    then .
    else .hooks[$ev] += [{"hooks":[{"type":"command","command":("~/.claude/hooks/voice-alert.sh " + $arg),"timeout":20,"async":true}]}]
    end;
  .hooks //= {}
  | add("Elicitation";"pergunta") | add("PermissionRequest";"permissao")
  | add("Notification";"atencao") | add("StopFailure";"erro")
' "$S" > "$TMP2" && mv "$TMP2" "$S"
ok "hooks registrados: leitura e quatro avisos (backup do settings.json ao lado)"

# ───────────────────────────────────────── 8. serviço de texto selecionado
step "8/9  Instalando o serviço Ler em voz alta"
W="$HOME/Library/Services/Ler em voz alta.workflow"
mkdir -p "$W/Contents"
cp "$SRC/service/Info.plist" "$W/Contents/Info.plist"
"$PY3" - "$W/Contents/document.wflow" "$V/read-selection.sh" <<'PYEOF'
import plistlib, sys, uuid
dest, script = sys.argv[1], sys.argv[2]
u = lambda: str(uuid.uuid4()).upper()
acao = {
 "AMAccepts": {"Container": "List", "Optional": True, "Types": ["com.apple.cocoa.string"]},
 "AMActionVersion": "2.0.3", "AMApplication": ["Automator"],
 "AMParameterProperties": {k: {} for k in
   ["COMMAND_STRING", "CheckedForUserDefaultShell", "inputMethod", "shell", "source"]},
 "AMProvides": {"Container": "List", "Types": ["com.apple.cocoa.string"]},
 "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
 "ActionName": "Run Shell Script",
 "ActionParameters": {"COMMAND_STRING": script, "CheckedForUserDefaultShell": True,
                      "inputMethod": 0, "shell": "/bin/zsh", "source": ""},
 "BundleIdentifier": "com.apple.RunShellScript", "CFBundleVersion": "2.0.3",
 "CanShowSelectedItemsWhenRun": False, "CanShowWhenRun": True,
 "Category": ["AMCategoryUtilities"], "Class Name": "RunShellScriptAction",
 "InputUUID": u(), "OutputUUID": u(), "UUID": u(),
 "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
 "UnlocalizedApplications": ["Automator"], "arguments": {},
 "isViewVisible": 1, "location": "309.000000:253.000000",
 "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
}
doc = {"AMApplicationBuild": "521", "AMApplicationVersion": "2.10", "AMDocumentVersion": "2",
       "actions": [{"action": acao, "isViewVisible": 1}], "connectors": {},
       "state": {"AMLogTabViewSelectedIndex": 0, "windowFrame": "{{100, 100}, {700, 600}}"},
       "workflowMetaData": {"serviceApplicationBundleID": "", "serviceProcessesInput": 0,
         "serviceInputTypeIdentifier": "com.apple.Automator.text",
         "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
         "workflowTypeIdentifier": "com.apple.Automator.servicesMenu"}}
with open(dest, "wb") as f: plistlib.dump(doc, f)
PYEOF
[ -s "$W/Contents/document.wflow" ] || die "Não consegui gerar o serviço."
# atalho de teclado: Control + Option + Comando + L
defaults write pbs NSServicesStatus -dict-add \
  "com.claude.voice.lerselecao - Ler em voz alta - runWorkflowAsService" \
  '{ "enabled_context_menu" = 1; "enabled_services_menu" = 1; "key_equivalent" = "^~@l"; }' 2>/dev/null
/System/Library/CoreServices/pbs -flush 2>/dev/null
ok "serviço instalado, com atalho Control Option Comando L"

# ───────────────────────────────────────────── 9. início automático e atalho
step "9/9  Deixando o app pronto para subir sozinho"
LA="$HOME/Library/LaunchAgents/com.claude.voicebar.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$LA" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.claude.voicebar</string>
  <key>ProgramArguments</key><array><string>$V/voicebar</string></array>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST
plutil -lint "$LA" >/dev/null || die "O arquivo de início automático saiu inválido."
launchctl bootstrap "gui/$(id -u)" "$LA" 2>/dev/null
mkdir -p "$HOME/.local/bin"
ln -sf "$V/voice" "$HOME/.local/bin/voice"
ok "início automático e comando voice instalados"

sleep 2
if pgrep -x voicebar >/dev/null; then ok "app rodando na barra de menus"
else warn "o app não subiu; abra manualmente com:  ~/.claude/voice/voicebar &"; fi

# ────────────────────────────────────────────────────────────────── conclusão
step "Pronto"
printf "  Um ícone de alto-falante deve ter aparecido na barra de menus.\n"
printf "  Clique nele e escolha \033[1mComo usar…\033[0m para o guia completo.\n\n"
printf "  Testar agora:   \033[1mvoice say \"Instalação concluída.\"\033[0m\n"
printf "  Ver o estado:   \033[1mvoice status\033[0m\n"
printf "  Trocar de voz:  \033[1mvoice list\033[0m  e depois  \033[1mvoice use dora\033[0m\n\n"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) warn "~/.local/bin não está no seu PATH. Acrescente ao ~/.zshrc:"
     printf "      export PATH=\"\$HOME/.local/bin:\$PATH\"\n\n";;
esac
printf "  O resumo por IA vem desligado. Para usar, abra \033[1mResumo por IA…\033[0m no menu\n"
printf "  e cole uma chave da OpenAI. Sem chave, tudo o mais funciona offline.\n\n"
