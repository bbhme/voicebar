#!/bin/bash
# Fala um aviso curto quando o Claude Code precisa de você.
# Uso, a partir de um hook:  voice-alert.sh <tipo>
#   pergunta   Claude fez uma pergunta (Elicitation)
#   permissao  Claude pede autorização (PermissionRequest)
#   atencao    Claude precisa de você (Notification)
#   erro       o turno terminou em falha (StopFailure)
#
# O aviso entra na fila como qualquer outra fala e espera a atual terminar:
# com várias sessões abertas, interromper no meio de uma resposta confunde
# mais do que ajuda. Ele é curto de propósito, e o mesmo aviso nunca é dito
# duas vezes: nem em sequência, nem enquanto um igual ainda espera na fila.

TIPO="${1:-atencao}"
V="$HOME/.claude/voice"; R="$V/run"; Q="$R/q"; LOG="$HOME/.claude/hooks/speak-response.log"
mkdir -p "$Q" "$R/alert"
export PATH="/usr/bin:/bin:$PATH"

# interruptor próprio: avisar é independente de ler as respostas
[ "$(cat "$V/alerts" 2>/dev/null || echo 1)" = "1" ] || exit 0

PAYLOAD=$(cat)
CWD=$(jq -r '.cwd // empty' <<< "$PAYLOAD" 2>/dev/null)
SESS=$(jq -r '.session_id // empty' <<< "$PAYLOAD" 2>/dev/null)
NTIPO=$(jq -r '.notification_type // empty' <<< "$PAYLOAD" 2>/dev/null)
# mesmo nome que a leitura das respostas usa para esta sessão
if [ -f "$V/projeto.sh" ]; then
  . "$V/projeto.sh"; projeto_da_sessao "$CWD" claude
elif [ -n "$CWD" ]; then PROJ=$(basename "$CWD"); else PROJ="claude"; fi

# O Notification do Claude Code é, quase sempre, o eco de algo já avisado.
# Seis segundos depois de todo pedido de permissão ele manda permission_prompt,
# e um minuto depois de toda resposta manda idle_prompt. Sem este filtro, cada
# permissão virava dois avisos e cada resposta lida ganhava um "precisa de você".
if [ "$TIPO" = atencao ]; then
  case "$NTIPO" in
    permission_prompt|elicitation_*|auth_success) exit 0;;
    # a resposta desta sessão já foi lida, e o anúncio dela já disse o projeto;
    # só avisa se o turno terminou sem nada para ler ou com a leitura desligada
    idle_prompt) [ -n "$SESS" ] && [ -f "$R/lida/$SESS" ] && exit 0;;
  esac
fi

# projeto silenciado não avisa
grep -qxF "$PROJ" "$V/muted.txt" 2>/dev/null && exit 0

PK=$(printf '%s' "$PROJ" | tr -c 'A-Za-z0-9' '_')
# um aviso igual ainda esperando a vez: o segundo não acrescentaria nada
ls "$Q"/*-alerta-"$TIPO"-"$PK"-*.job >/dev/null 2>&1 && exit 0

# um aviso igual, do mesmo projeto, no máximo a cada 15 segundos
MARCA="$R/alert/$TIPO-$PK"
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
  # prio=0: espera a vez como as respostas; sem ann porque o aviso já diz o projeto.
  # O tipo e o projeto no nome do arquivo servem ao teste de repetição acima.
  printf 'wav=%s\nann=\nproj=%s\nsess=%s\nts=%s\nprio=0\nrep=0\n' "$WAV" "aviso · $NOME" "$SESS" "$AGORA" \
    > "$Q/$AGORA-alerta-$TIPO-$PK-$$.job"
else
  afplay -v "$(cat "$V/volume" 2>/dev/null || echo 1)" "$WAV" >/dev/null 2>&1 &
  disown
fi
echo "$(date '+%F %T') aviso [$TIPO] $NOME" >> "$LOG"
exit 0
