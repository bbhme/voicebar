#!/bin/bash
# Hook Stop: enfileira a leitura da resposta, identificada pelo projeto de origem.
# Controles visuais: ícone de alto-falante na barra de menus.
DIR="$(cd "$(dirname "$0")" && pwd)"
V="$HOME/.claude/voice"; R="$V/run"; Q="$R/q"; PIDF="$R/play.pid"; LOG="$DIR/speak-response.log"
mkdir -p "$Q" "$R/lida"

# áudios órfãos; a folga é bem maior que a espera máxima da fila (10 min)
find "$R" -maxdepth 1 \( -name 'r-*.wav' -o -name 'a-*.wav' -o -name 'alerta-*.wav' \) \
  -mmin +30 -delete 2>/dev/null
find "$R/lida" -type f -mtime +1 -delete 2>/dev/null

PAYLOAD=$(cat)
echo "$PAYLOAD" > "$R/last-payload.json"          # útil para depurar
SESS=$(jq -r '.session_id // empty' <<< "$PAYLOAD")

# Marca de "a resposta desta sessão foi lida". O aviso de sessão parada
# (voice-alert.sh) consulta a marca para não repetir o que a leitura já disse.
# Some a cada turno e só volta se esta leitura de fato entrar na fila.
LIDA=""; [ -n "$SESS" ] && { LIDA="$R/lida/$SESS"; rm -f "$LIDA"; }

[ -f "$DIR/voice.off" ] && exit 0
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<< "$PAYLOAD")
[ -z "$TRANSCRIPT" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

CWD=$(jq -r  '.cwd // empty'        <<< "$PAYLOAD")
# nome estável da sessão: a pasta onde ela foi aberta, ou o worktree
if [ -f "$V/projeto.sh" ]; then
  . "$V/projeto.sh"; projeto_da_sessao "$CWD" "$(basename "$(dirname "$TRANSCRIPT")")"
else
  PROJ=$(basename "${CWD:-$(dirname "$TRANSCRIPT")}"); [ -z "$PROJ" ] && PROJ="claude"
fi

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

  # Resposta que termina em pergunta é anunciada como tal: você percebe que
  # a sessão está esperando por você sem precisar ouvir até o fim.
  if printf '%s' "$TEXT" | sed 's/[[:space:]]*$//' | grep -q '?$'; then
    IDIOMA=$(cat "$V/lang.active" 2>/dev/null); IDIOMA=${IDIOMA:-pt-BR}
    LCONF="$V/lang/$IDIOMA.conf"; [ -f "$LCONF" ] || LCONF="$V/lang/pt-BR.conf"
    MOLDE=$(grep '^SAY_QUESTION=' "$LCONF" 2>/dev/null | head -1 | cut -d= -f2-)
    [ -n "$MOLDE" ] && NOME=$(printf '%s' "$MOLDE" | sed "s|{PROJ}|$NOME|g")
  fi
  ANN="$R/a-$$-$STAMP.wav"
  printf '%s.' "$NOME" | "$V/synth.sh" "$VOZ" "$ANN" 2>>"$LOG" || ANN=""
  [ -s "$ANN" ] || ANN=""
fi

BAR=$(cat "$R/bar.pid" 2>/dev/null)
if [ -n "$BAR" ] && kill -0 "$BAR" 2>/dev/null; then
  # entra na fila; o app decide ordem, descarte e reprodução
  JOB="$Q/$STAMP-$$.job"
  printf 'wav=%s\nann=%s\nproj=%s\nsess=%s\nts=%s\n' "$WAV" "$ANN" "$PROJ" "$SESS" "$STAMP" > "$JOB"
  [ -n "$LIDA" ] && : > "$LIDA"
else
  # sem app: comportamento simples, a mais nova interrompe
  if [ -f "$PIDF" ]; then P=$(cat "$PIDF"); kill "$P" 2>/dev/null; fi
  afplay -v "$VOL" "$WAV" >/dev/null 2>&1 & echo $! > "$PIDF"; disown
  [ -n "$LIDA" ] && : > "$LIDA"
fi
exit 0
