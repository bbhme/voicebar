#!/bin/bash
# Lê em voz alta o texto recebido em stdin (usado pelo Serviço "Ler em voz alta").
V="$HOME/.claude/voice"; R="$V/run"; Q="$R/q"; LOG="$HOME/.claude/hooks/speak-response.log"
mkdir -p "$Q"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

TEXT=$(cat | tr -d '\000' | head -c 20000)
TEXT=$(printf '%s' "$TEXT" | tr '\n\r\t' '   ' | sed 's/  */ /g; s/^ //; s/ $//')
[ -z "$TEXT" ] && exit 0

SUM=$(printf '%s' "$TEXT" | "$V/summarize.sh" 2>/dev/null)
[ -n "$SUM" ] && TEXT="$SUM"

VOZ=$(cat "$V/current" 2>/dev/null || echo cadu)
VOL=$(cat "$V/volume"  2>/dev/null || echo 1.0)
STAMP=$(date +%s)
WAV="$R/sel-$$-$STAMP.wav"

if ! printf '%s' "$TEXT" | "$V/synth.sh" "$VOZ" "$WAV" 2>>"$LOG"; then
  echo "$(date '+%F %T') selecao: sintese falhou ($VOZ)" >> "$LOG"; exit 1
fi

ANN=""
if [ "$(cat "$V/announce" 2>/dev/null || echo 1)" = "1" ]; then
  IDIOMA=$(cat "$V/lang.active" 2>/dev/null); IDIOMA=${IDIOMA:-pt-BR}
  CONF="$V/lang/$IDIOMA.conf"; [ -f "$CONF" ] || CONF="$V/lang/pt-BR.conf"
  FRASE=$(grep '^SAY_SELECTION=' "$CONF" 2>/dev/null | cut -d= -f2-)
  FRASE=${FRASE:-Texto selecionado}
  ANN="$R/asel-$$-$STAMP.wav"
  printf '%s.' "$FRASE" | "$V/synth.sh" "$VOZ" "$ANN" 2>>"$LOG" || ANN=""
  [ -s "$ANN" ] || ANN=""
fi

BAR=$(cat "$R/bar.pid" 2>/dev/null)
if [ -n "$BAR" ] && kill -0 "$BAR" 2>/dev/null; then
  # prio=1: o app interrompe o que estiver tocando e devolve aquilo para a fila
  printf 'wav=%s\nann=%s\nproj=seleção\nsess=\nts=%s\nprio=1\n' "$WAV" "$ANN" "$STAMP" > "$Q/$STAMP-sel-$$.job"
else
  afplay -v "$VOL" "$WAV" >/dev/null 2>&1 &
  disown
fi
exit 0
