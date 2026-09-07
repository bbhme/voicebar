#!/usr/bin/env python3
"""Sintetiza texto (stdin) com Piper e grava um WAV. Uso: speak.py <voz> <saida.wav>"""
import os, sys, wave
V = os.path.expanduser("~/.claude/voice")
os.environ.setdefault("ESPEAK_DATA_PATH", f"{V}/esp")
from piper import PiperVoice

voice, out = sys.argv[1], sys.argv[2]
text = sys.stdin.read().strip()
if not text:
    sys.exit(1)
model = f"{V}/models/{voice}.onnx"
if not os.path.exists(model):
    sys.stderr.write(f"voz '{voice}' nao encontrada em {V}/models\n"); sys.exit(2)
v = PiperVoice.load(model, config_path=model + ".json")
with wave.open(out, "wb") as w:
    v.synthesize_wav(text, w)
