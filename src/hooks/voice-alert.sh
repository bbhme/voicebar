#!/bin/bash
# Fala um aviso curto quando o Claude Code precisa de você.
# Uso, a partir de um hook:  voice-alert.sh <tipo>
#   pergunta   Claude fez uma pergunta (Elicitation)
#   permissao  Claude pede autorização (PermissionRequest)
#   atencao    Claude precisa de você (Notification)
#   erro       o turno terminou em falha (StopFailure)
#
# Um aviso fura a fila, como o texto selecionado: ele existe para te
# interromper. Mas é curto de propósito, e há um intervalo mínimo entre
# avisos iguais do mesmo projeto, para uma sequência de permissões não
# virar uma metralhadora.

TIPO="${1:-atencao}"
V="$HOME/.claude/voice"; R="$V/run"; Q="$R/q"; LOG="$HOME/.claude/hooks/speak-response.log"
mkdir -p "$Q" "$R/alert"
export PATH="/usr/bin:/bin:$PATH"

# interruptor próprio: avisar é independente de ler as respostas
[ "$(cat "$V/alerts" 2>/dev/null || echo 1)" = "1" ] || exit 0

PAYLOAD=$(cat)
CWD=$(jq -r '.cwd // empty' <<< "$PAYLOAD" 2>/dev/null)
if [ -n "$CWD" ]; then PROJ=$(basename "$CWD"); else PROJ="claude"; fi

# projeto silenciado não avisa
grep -qxF "$PROJ" "$V/muted.txt" 2>/dev/null && exit 0

# um aviso igual, do mesmo projeto, no máximo a cada 15 segundos
MARCA="$R/alert/$TIPO-$(printf '%s' "$PROJ" | tr -c 'A-Za-z0-9' '_')"
AGORA=$(date +%s)
if [ -f "$MARCA" ]; then
  ULT=$(cat "$MARCA" 2>/dev/null || echo 0)
  [ $(( AGORA - ULT )) -lt 15 ] && exit 0
fi
echo "$AGORA" > "$MARCA"

# o nome falado é a legenda do projeto, se houver
NOME=$(grep "^$PROJ|" "$V/labels.txt" 2>/dev/null | head -1 | cut -d'|' -f2-)
[ -z "$NOME" ] && NOME=$(printf '%s' "$PROJ" | tr '_.-' '   ' | sed 's/  */ /g; s/^ //; s/ $//')

IDIOMA=$(cat "$V/lang.active" 2>/dev/null); IDIOMA=${IDIOMA:-pt-BR}
CONF="$V/lang/$IDIOMA.conf"; [ -f "$CONF" ] || CONF="$V/lang/pt-BR.conf"
case "$TIPO" in
  pergunta)  CHAVE=SAY_QUESTION;   RESERVA="{PROJ} fez uma pergunta";;
  permissao) CHAVE=SAY_PERMISSION; RESERVA="{PROJ} pede permissão";;
  erro)      CHAVE=SAY_FAILED;     RESERVA="{PROJ} parou com erro";;
  *)         CHAVE=SAY_NEEDS_YOU;  RESERVA="{PROJ} precisa de você";;
esac
MOLDE=$(grep "^$CHAVE=" "$CONF" 2>/dev/null | head -1 | cut -d= -f2-)
[ -z "$MOLDE" ] && MOLDE="$RESERVA"
FRASE=$(printf '%s' "$MOLDE" | sed "s|{PROJ}|$NOME|g")

VOZ=$(cat "$V/current" 2>/dev/null || echo cadu)
WAV="$R/alerta-$$-$AGORA.wav"
printf '%s.' "$FRASE" | "$V/synth.sh" "$VOZ" "$WAV" 2>>"$LOG" || exit 0
[ -s "$WAV" ] || exit 0

BAR=$(cat "$R/bar.pid" 2>/dev/null)
if [ -n "$BAR" ] && kill -0 "$BAR" 2>/dev/null; then
  # prio=1 fura a fila; sem ann porque o aviso já diz o projeto
  printf 'wav=%s\nann=\nproj=%s\nsess=\nts=%s\nprio=1\n' "$WAV" "aviso · $NOME" "$AGORA" \
    > "$Q/$AGORA-alerta-$$.job"
else
  afplay -v "$(cat "$V/volume" 2>/dev/null || echo 1)" "$WAV" >/dev/null 2>&1 &
  disown
fi
echo "$(date '+%F %T') aviso [$TIPO] $NOME" >> "$LOG"
exit 0
