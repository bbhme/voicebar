#!/bin/bash
# Resume o texto de stdin usando a API da OpenAI e imprime o resultado.
# Regra de ouro: qualquer falha devolve o texto original, a fala nunca quebra.
V="$HOME/.claude/voice"; CONF="$V/summary.conf"; ENVF="$V/openai.env"
LOG="$HOME/.claude/hooks/speak-response.log"
export PATH="/usr/bin:/bin:$PATH"

rm -f "$V/run/summary-error.txt"   # zera antes: só sobra se ESTA execução falhar
TEXT=$(cat); [ -z "$TEXT" ] && exit 0
say_original(){ printf '%s' "$TEXT"; exit 0; }
get(){ grep "^$1=" "$CONF" 2>/dev/null | head -1 | cut -d= -f2-; }

# Pedidos avulsos (a janela Ler um texto) mandam estas variáveis para valer
# só naquela leitura, sem tocar na configuração global:
#   VOICE_SUM_FORCE=1        resume mesmo com o resumo global desligado
#   VOICE_SUM_PCT=40         usa esta redução em vez da global
#   VOICE_SUM_PROMPT="..."   usa estas instruções em vez das globais
FORCE="${VOICE_SUM_FORCE:-0}"

[ "$FORCE" = "1" ] || [ "$(get enabled)" = "1" ] || say_original
[ -f "$ENVF" ] || say_original
KEY=$(grep '^OPENAI_API_KEY=' "$ENVF" 2>/dev/null | cut -d= -f2-)
[ -z "$KEY" ] && say_original

MODEL=$(get model); MODEL=${MODEL:-gpt-4o-mini}
MODE=$(get mode);   MODE=${MODE:-percent}
NW=$(printf '%s' "$TEXT" | wc -w | tr -d ' ')

# num pedido avulso o corte por tamanho é do usuário, não do ajuste global
if [ "$FORCE" != "1" ]; then
  MIN=$(get min_words); MIN=${MIN:-60}
  [ "$NW" -lt "$MIN" ] && say_original
else
  [ "$NW" -lt 25 ] && say_original       # abaixo disso não sobra resumo
fi

if [ -n "${VOICE_SUM_PCT:-}" ]; then
  ALVO=$(( NW * (100 - VOICE_SUM_PCT) / 100 ))
elif [ "$MODE" = "words" ]; then
  ALVO=$(get words); ALVO=${ALVO:-60}
else
  PCT=$(get percent); PCT=${PCT:-25}
  ALVO=$(( NW * (100 - PCT) / 100 ))
fi
[ "$ALVO" -lt 15 ] && ALVO=15

# "aproximadamente N palavras" era ignorado: medindo, o modelo estourava o alvo
# em até 64% nos cortes agressivos. Tratar o número como teto rígido, e dizer que
# caber importa mais do que incluir tudo, traz o resultado para dentro da faixa.
# O texto da instrução vem do pacote de idioma, para outro idioma ser só mais um arquivo.
IDIOMA=$(cat "$V/lang.active" 2>/dev/null); IDIOMA=${IDIOMA:-pt-BR}
MOLDE="$V/lang/$IDIOMA.prompt"
[ -f "$MOLDE" ] || MOLDE="$V/lang/pt-BR.prompt"
INSTR=$(sed "s/{ALVO}/$ALVO/g" "$MOLDE" 2>/dev/null)
[ -z "$INSTR" ] && say_original

# Instruções livres do usuário. Vêm por último e mandam mais que as regras acima,
# para ele poder mudar o tom, tratar símbolos ou proteger o que não pode sumir.
EXTRA="${VOICE_SUM_PROMPT:-$(cat "$V/summary_prompt.txt" 2>/dev/null)}"
if [ -n "$EXTRA" ]; then
  INSTR="$INSTR

Instruções do usuário. Elas têm prioridade sobre as regras acima sempre que houver conflito, exceto o limite de palavras, que é sempre obrigatório:
$EXTRA"
fi

pedir(){   # $1 = JSON com o array de mensagens
  RESP=$(curl -s --max-time 60 https://api.openai.com/v1/chat/completions \
    -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    --data "$(jq -n --arg m "$MODEL" --argjson msgs "$1" '{model:$m, messages:$msgs}')" 2>/dev/null)
  printf '%s' "$RESP" | jq -r '.choices[0].message.content // empty' 2>/dev/null
}

MSGS=$(jq -n --arg s "$INSTR" --arg t "$TEXT" \
  '[{role:"system",content:$s},{role:"user",content:$t}]') || say_original
OUT=$(pedir "$MSGS")

if [ -z "$OUT" ] || [ "$OUT" = "null" ]; then
  ERR=$(printf '%s' "$RESP" | jq -r '.error.message // "sem resposta da API"' 2>/dev/null | head -c 300)
  echo "$(date '+%F %T') resumo falhou ($MODEL): $ERR" >> "$LOG"
  # a janela de ajustes lê este arquivo para mostrar o motivo real
  printf '%s: %s' "$MODEL" "$ERR" > "$V/run/summary-error.txt"
  say_original
fi

# Estourou muito? Uma segunda tentativa, dizendo o tamanho exato que veio.
SAIU=$(printf '%s' "$OUT" | wc -w | tr -d ' ')
TETO=$(( ALVO * 13 / 10 ))
if [ "$SAIU" -gt "$TETO" ]; then
  MSGS2=$(jq -n --arg s "$INSTR" --arg t "$TEXT" --arg a "$OUT" \
    --arg c "Sua resposta teve $SAIU palavras, acima do limite de $ALVO. Reescreva o resumo com no máximo $ALVO palavras, mantendo só o essencial. Responda apenas com o novo resumo." \
    '[{role:"system",content:$s},{role:"user",content:$t},{role:"assistant",content:$a},{role:"user",content:$c}]')
  OUT2=$(pedir "$MSGS2")
  if [ -n "$OUT2" ] && [ "$OUT2" != "null" ]; then
    SAIU2=$(printf '%s' "$OUT2" | wc -w | tr -d ' ')
    echo "$(date '+%F %T') resumo refeito: $SAIU -> $SAIU2 palavras (alvo $ALVO)" >> "$LOG"
    OUT="$OUT2"; SAIU="$SAIU2"
  fi
fi

echo "$(date '+%F %T') resumo ok: $NW -> $SAIU palavras (alvo $ALVO, modelo $MODEL, instrução $([ -n "${VOICE_SUM_PROMPT:-}" ] && echo avulsa || { [ -n "$EXTRA" ] && echo global || echo nenhuma; }))" >> "$LOG"
printf '%s' "$OUT"
