#!/bin/bash
# Sintetiza stdin no arquivo indicado, escolhendo o motor pela voz.
# Uso: synth.sh <id-da-voz> <saida.wav>
V="$HOME/.claude/voice"
ID="$1"; OUT="$2"
LOG="$HOME/.claude/hooks/speak-response.log"

LINE=$(grep "^$ID|" "$V/voices.txt" 2>/dev/null | head -1)
[ -z "$LINE" ] && { echo "voz '$ID' desconhecida" >&2; exit 2; }
ENGINE=$(echo "$LINE" | cut -d'|' -f2)
PARAM=$(echo  "$LINE" | cut -d'|' -f3)

rm -f "$OUT"
case "$ENGINE" in
  piper)  ESPEAK_DATA_PATH="$V/esp" "$V/venv/bin/python" "$V/speak.py" "$PARAM" "$OUT";;
  kokoro) "$V/kvenv/bin/python" "$V/speak_kokoro.py" "$PARAM" "$OUT";;
  *) echo "motor '$ENGINE' desconhecido" >&2; exit 3;;
esac
CODE=$?

# O onnxruntime já abortou no encerramento com o áudio inteiro gravado.
# Se o arquivo existe e tem tamanho de áudio de verdade, o trabalho foi feito:
# devolver erro faria o chamador descartar uma fala perfeitamente boa.
if [ "$CODE" -ne 0 ] && [ -s "$OUT" ]; then
  BYTES=$(stat -f%z "$OUT" 2>/dev/null || echo 0)
  if [ "$BYTES" -gt 1024 ]; then
    echo "$(date '+%F %T') $ENGINE saiu com código $CODE mas gravou ${BYTES} bytes; áudio aproveitado" >> "$LOG"
    exit 0
  fi
fi
exit "$CODE"
