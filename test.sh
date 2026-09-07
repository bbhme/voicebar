#!/bin/bash
# Teste de fumaça do VoiceBar. Não gasta chamada de API e não toca áudio.
# Uso: ./test.sh          (depois de instalar)

V="$HOME/.claude/voice"
FALHAS=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ok(){   printf "  \033[32m✓\033[0m %s\n" "$*"; }
nao(){  printf "  \033[31m✗\033[0m %s\n" "$*"; FALHAS=$((FALHAS+1)); }
step(){ printf "\n\033[1m%s\033[0m\n" "$*"; }
checa(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else nao "$1"; fi; }

step "1  Pré-requisitos"
checa "macOS"                 '[ "$(uname -s)" = Darwin ]'
checa "jq"                    'command -v jq'
checa "curl"                  'command -v curl'
checa "afplay"                'command -v afplay'

step "2  Instalação"
checa "pasta do VoiceBar"     '[ -d "$V" ]'
checa "app compilado"         '[ -x "$V/voicebar" ]'
checa "comando voice"         '[ -x "$V/voice" ]'
checa "ambiente do Piper"     '[ -x "$V/venv/bin/python" ]'
checa "ambiente do Kokoro"    '[ -x "$V/kvenv/bin/python" ]'
checa "dados de fonemas"      '[ -e "$V/esp/phontab" ]'
checa "gatilho do Claude"     '[ -x "$HOME/.claude/hooks/speak-response.sh" ]'
checa "gatilho registrado"    'jq -e "[.hooks.Stop[]?.hooks[]?.command]|any(.==\"~/.claude/hooks/speak-response.sh\")" "$HOME/.claude/settings.json"'
checa "serviço do sistema"    '[ -f "$HOME/Library/Services/Ler em voz alta.workflow/Contents/document.wflow" ]'
checa "início automático"     '[ -f "$HOME/Library/LaunchAgents/com.claude.voicebar.plist" ]'
checa "pacote de idioma"      '[ -f "$V/lang/pt-BR.conf" ] && [ -f "$V/lang/pt-BR.prompt" ]'

step "3  Vozes declaradas e presentes"
while IFS='|' read -r id motor par _; do
  [ -z "$id" ] && continue
  case "$motor" in
    piper)  [ -s "$V/models/$par.onnx" ] && ok "voz $id (Piper)"  || nao "voz $id: modelo ausente";;
    kokoro) [ -s "$V/kokoro/kokoro.onnx" ] && ok "voz $id (Kokoro)" || nao "voz $id: modelo ausente";;
    *) nao "voz $id: motor '$motor' desconhecido";;
  esac
done < "$V/voices.txt"

step "4  Síntese de verdade, um motor de cada"
for v in cadu dora; do
  if echo "Teste de fumaça do VoiceBar." | "$V/synth.sh" "$v" "$TMP/$v.wav" 2>/dev/null && [ -s "$TMP/$v.wav" ]; then
    B=$(stat -f%z "$TMP/$v.wav" 2>/dev/null || echo 0)
    [ "$B" -gt 10000 ] && ok "voz $v gerou $((B/1024)) KB" || nao "voz $v gerou áudio curto demais"
  else
    nao "voz $v não sintetizou"
  fi
done

step "5  A fala nunca falha em silêncio"
# sem chave, o resumo tem de devolver o texto original intacto
ORIG="Um texto suficientemente longo para passar de qualquer limite mínimo configurado no sistema, servindo para confirmar que o resumidor devolve exatamente o que recebeu quando não existe chave da OpenAI disponível para consultar."
SAIDA=$(printf '%s' "$ORIG" | OPENAI_API_KEY= VOICE_SUM_FORCE=0 "$V/summarize.sh" 2>/dev/null)
if [ -s "$V/openai.env" ]; then
  ok "resumo ignorado no teste (há chave configurada)"
else
  [ "$SAIDA" = "$ORIG" ] && ok "sem chave, o texto passa intacto" || nao "sem chave, o texto foi alterado"
fi
# Motor que morre depois de gravar não pode perder o áudio.
# Saímos com os._exit(134), o mesmo código que um SIGABRT produz, em vez de
# abortar de verdade: a condição observada por quem chama é idêntica, e o
# macOS não registra uma queda no relatório de falhas a cada teste.
cat > "$TMP/aborta.py" <<'PY'
import os, sys, wave, struct, math
sys.stdin.read()
with wave.open(sys.argv[2], "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(22050)
    w.writeframes(b"".join(struct.pack("<h", int(8000*math.sin(i/20))) for i in range(22050)))
os._exit(134)
PY
sed "s|\"\$V/kvenv/bin/python\" \"\$V/speak_kokoro.py\"|python3 $TMP/aborta.py|" "$V/synth.sh" > "$TMP/synth.sh"
chmod +x "$TMP/synth.sh"
if echo x | "$TMP/synth.sh" dora "$TMP/resgate.wav" 2>/dev/null && [ -s "$TMP/resgate.wav" ]; then
  ok "áudio é resgatado quando o motor aborta no fim"
else
  nao "áudio perdido quando o motor aborta"
fi

step "6  Fila"
mkdir -p "$V/run/q"
if ! pgrep -x voicebar >/dev/null; then
  nao "o app da barra não está rodando; inicie com: voice bar"
else
  # o app só puxa da fila quando está ocioso, então limpamos antes e damos tempo
  echo stop  > "$V/run/cmd"; sleep 0.5
  echo clear > "$V/run/cmd"; sleep 0.5
  J="$V/run/q/9999999999-teste.job"
  printf 'wav=%s\nann=\nproj=teste-de-fumaca\nsess=\nts=9999999999\nprio=0\n' "$TMP/cadu.wav" > "$J"
  CONSUMIU=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$J" ] || { CONSUMIU=1; break; }
    sleep 0.5
  done
  if [ "$CONSUMIU" = "1" ]; then ok "o app consumiu o item da fila"
  else rm -f "$J"; nao "o app não consumiu o item da fila em 5 segundos"; fi
  echo stop > "$V/run/cmd"
fi

step "Resultado"
if [ "$FALHAS" -eq 0 ]; then
  printf "  \033[32mtudo certo\033[0m\n\n"; exit 0
else
  printf "  \033[31m%s verificação(ões) falharam\033[0m\n\n" "$FALHAS"; exit 1
fi
