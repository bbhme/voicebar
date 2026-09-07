#!/bin/bash
# Hook Stop: enfileira a leitura da resposta, identificada pelo projeto de origem.
# Controles visuais: ícone de alto-falante na barra de menus.
DIR="$(cd "$(dirname "$0")" && pwd)"
V="$HOME/.claude/voice"; R="$V/run"; Q="$R/q"; PIDF="$R/play.pid"; LOG="$DIR/speak-response.log"
mkdir -p "$Q"

[ -f "$DIR/voice.off" ] && exit 0
find "$R" -name 'r-*.wav' -mmin +10 -delete 2>/dev/null

PAYLOAD=$(cat)
echo "$PAYLOAD" > "$R/last-payload.json"          # útil para depurar
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<< "$PAYLOAD")
[ -z "$TRANSCRIPT" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

CWD=$(jq -r  '.cwd // empty'        <<< "$PAYLOAD")
SESS=$(jq -r '.session_id // empty' <<< "$PAYLOAD")
if [ -n "$CWD" ]; then PROJ=$(basename "$CWD"); else PROJ=$(basename "$(dirname "$TRANSCRIPT")"); fi
[ -z "$PROJ" ] && PROJ="claude"

# projeto silenciado neste app? sai sem gastar CPU sintetizando
grep -qxF "$PROJ" "$V/muted.txt" 2>/dev/null && exit 0
# registra o projeto para aparecer no menu
grep -qxF "$PROJ" "$V/projects.txt" 2>/dev/null || echo "$PROJ" >> "$V/projects.txt"

TEXT=$(python3 "$DIR/speak-response.py" "$TRANSCRIPT" "${CLAUDE_SAY_MAX_CHARS:-0}")
[ -z "$TEXT" ] && exit 0

# resume antes de anunciar, para o nome do projeto não entrar no resumo
SUM=$(printf '%s' "$TEXT" | "$V/summarize.sh" 2>/dev/null)
[ -n "$SUM" ] && TEXT="$SUM"

VOZ=$(cat "$V/current" 2>/dev/null || echo cadu)
VOL=$(cat "$V/volume"  2>/dev/null || echo 1.0)
STAMP=$(date +%s)
WAV="$R/r-$$-$STAMP.wav"

if ! printf '%s' "$TEXT" | "$V/synth.sh" "$VOZ" "$WAV" 2>>"$LOG"; then
  echo "$(date '+%F %T') sintese falhou ($VOZ)" >> "$LOG"; exit 0
fi

# O anúncio vai num arquivo próprio: o app o toca em velocidade normal,
# com uma pausa antes e depois, mesmo que o conteúdo esteja acelerado.
ANN=""
if [ "$(cat "$V/announce" 2>/dev/null || echo 1)" = "1" ]; then
  # legenda definida pelo usuário para este projeto; sem ela, o nome da pasta limpo
  NOME=$(grep "^$PROJ|" "$V/labels.txt" 2>/dev/null | head -1 | cut -d'|' -f2-)
  [ -z "$NOME" ] && NOME=$(printf '%s' "$PROJ" | tr '_.-' '   ' | sed 's/  */ /g; s/^ //; s/ $//')
  ANN="$R/a-$$-$STAMP.wav"
  printf '%s.' "$NOME" | "$V/synth.sh" "$VOZ" "$ANN" 2>>"$LOG" || ANN=""
  [ -s "$ANN" ] || ANN=""
fi

BAR=$(cat "$R/bar.pid" 2>/dev/null)
if [ -n "$BAR" ] && kill -0 "$BAR" 2>/dev/null; then
  # entra na fila; o app decide ordem, descarte e reprodução
  JOB="$Q/$STAMP-$$.job"
  printf 'wav=%s\nann=%s\nproj=%s\nsess=%s\nts=%s\n' "$WAV" "$ANN" "$PROJ" "$SESS" "$STAMP" > "$JOB"
else
  # sem app: comportamento simples, a mais nova interrompe
  if [ -f "$PIDF" ]; then P=$(cat "$PIDF"); kill "$P" 2>/dev/null; fi
  afplay -v "$VOL" "$WAV" >/dev/null 2>&1 & echo $! > "$PIDF"; disown
fi
exit 0
