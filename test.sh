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
  # o app só puxa da fila quando está ocioso. Se houver fala tocando ou
  # esperando, o teste não a descarta: é resposta sua, e não volta mais.
  if ! grep -q 'fase=parado player=nil' "$V/run/estado" 2>/dev/null || ls "$V/run/q"/*.job >/dev/null 2>&1; then
    ok "fila ocupada com falas de verdade; teste da fila pulado para não descartá-las"
  else
    J="$V/run/q/9999999999-teste.job"
    # rep=0: o áudio de teste não pode tomar o lugar da sua última fala
    printf 'wav=%s\nann=\nproj=teste-de-fumaca\nsess=\nts=9999999999\nprio=0\nrep=0\n' "$TMP/cadu.wav" > "$J"
    CONSUMIU=0
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      [ -f "$J" ] || { CONSUMIU=1; break; }
      sleep 0.5
    done
    if [ "$CONSUMIU" = "1" ]; then ok "o app consumiu o item da fila"
    else rm -f "$J"; nao "o app não consumiu o item da fila em 5 segundos"; fi
    echo stop > "$V/run/cmd"
  fi
fi

step "7  Avisos: nada se repete, nada fura a fila"
# Roda os ganchos num HOME falso, com um "app" de mentira vivo, para que
# escrevam na fila em vez de tocar. A fila real não é tocada.
FH="$TMP/home"; FV="$FH/.claude/voice"; FHK="$FH/.claude/hooks"; FQ="$FV/run/q"
mkdir -p "$FQ" "$FHK"
for f in synth.sh speak.py speak_kokoro.py summarize.sh projeto.sh voices.txt venv kvenv models kokoro esp lang lang.active current; do
  [ -e "$V/$f" ] && ln -s "$V/$f" "$FV/$f"
done
echo 1 > "$FV/alerts"; echo 1 > "$FV/announce"
cp "$HOME/.claude/hooks/speak-response.sh" "$HOME/.claude/hooks/speak-response.py" "$HOME/.claude/hooks/voice-alert.sh" "$FHK/"
sleep 120 & FALSO=$!; echo "$FALSO" > "$FV/run/bar.pid"
fila(){ ls "$FQ"/*.job 2>/dev/null | wc -l | tr -d ' '; }
ev(){ printf '{"session_id":"%s","cwd":"/x/teste","notification_type":"%s","transcript_path":"%s"}' "$1" "$2" "$3"; }
ev s1 permission_prompt | HOME="$FH" "$FHK/voice-alert.sh" atencao
[ "$(fila)" = 0 ] && ok "eco do pedido de permissão é ignorado" || nao "eco do pedido de permissão virou aviso"
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"Pronto."}]}}' > "$TMP/t.jsonl"
ev s2 "" "$TMP/t.jsonl" | HOME="$FH" "$FHK/speak-response.sh"
ev s2 idle_prompt | HOME="$FH" "$FHK/voice-alert.sh" atencao
[ "$(fila)" = 1 ] && ok "resposta lida não ganha \"precisa de você\" depois" || nao "resposta lida ganhou aviso de espera ($(fila) na fila)"
ev s3 "" | HOME="$FH" "$FHK/voice-alert.sh" permissao
rm -f "$FV/run/alert/"*
ev s3 "" | HOME="$FH" "$FHK/voice-alert.sh" permissao
[ "$(fila)" = 2 ] && ok "aviso igual esperando na fila não é duplicado" || nao "aviso duplicado na fila ($(fila))"
grep -qx 'prio=0' "$FQ"/*-alerta-*.job 2>/dev/null && ok "aviso espera a vez, sem furar a fila" || nao "aviso fura a fila"
kill "$FALSO" 2>/dev/null; wait "$FALSO" 2>/dev/null

step "Resultado"
if [ "$FALHAS" -eq 0 ]; then
  printf "  \033[32mtudo certo\033[0m\n\n"; exit 0
else
  printf "  \033[31m%s verificação(ões) falharam\033[0m\n\n" "$FALHAS"; exit 1
fi
