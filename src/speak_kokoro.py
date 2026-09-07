#!/usr/bin/env python3
"""Sintetiza texto (stdin) com Kokoro. Uso: speak_kokoro.py <voz_kokoro> <saida.wav>

Duas defesas contra uma falha do onnxruntime 1.29 no macOS:

1. A telemetria da Microsoft embutida no onnxruntime abre conexões de rede.
   No encerramento, a thread principal destrói o sistema de telemetria enquanto
   uma thread de rede ainda processa a resposta de um envio. Ela trava um mutex
   já destruído, a exceção escapa e o processo aborta com SIGABRT. O áudio já
   está gravado, mas quem chamou vê código 134 e joga o arquivo fora.
   Desligar a telemetria evita a corrida e, de quebra, mantém a promessa de que
   este sistema não fala com a internet.

2. Ainda assim saímos por os._exit, que pula os destrutores estáticos de C++.
   Mesmo que algo reative a telemetria, nunca chegamos ao ponto que quebra.
"""
import os
import sys

V = os.path.expanduser("~/.claude/voice")
os.environ.setdefault("ESPEAK_DATA_PATH", f"{V}/esp")


def idioma() -> str:
    """Código de idioma do pacote ativo, para o motor de síntese."""
    try:
        nome = open(f"{V}/lang.active").read().strip() or "pt-BR"
    except OSError:
        nome = "pt-BR"
    for caminho in (f"{V}/lang/{nome}.conf", f"{V}/lang/pt-BR.conf"):
        try:
            for linha in open(caminho, encoding="utf-8"):
                if linha.startswith("LANG_CODE="):
                    return linha.split("=", 1)[1].strip()
        except OSError:
            continue
    return "pt-br"

import onnxruntime  # noqa: E402
try:
    onnxruntime.disable_telemetry_events()
except Exception:
    pass

import soundfile as sf  # noqa: E402
from kokoro_onnx import Kokoro  # noqa: E402


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("uso: speak_kokoro.py <voz> <saida.wav>\n")
        return 2
    voice, out = sys.argv[1], sys.argv[2]

    text = sys.stdin.read().strip()
    if not text:
        return 1

    modelo = f"{V}/kokoro/kokoro.onnx"
    vozes = f"{V}/kokoro/voices.bin"
    for caminho in (modelo, vozes):
        if not os.path.exists(caminho):
            sys.stderr.write(f"arquivo do Kokoro ausente: {caminho}\n")
            return 2

    k = Kokoro(modelo, vozes)
    samples, sr = k.create(text, voice=voice, speed=1.0, lang=idioma())
    sf.write(out, samples, sr)

    # só declaramos sucesso com áudio real no disco
    if not os.path.exists(out) or os.path.getsize(out) < 1024:
        sys.stderr.write("o arquivo de áudio saiu vazio\n")
        return 3
    return 0


if __name__ == "__main__":
    codigo = 1
    try:
        codigo = main()
    except Exception as e:
        sys.stderr.write(f"kokoro falhou: {e}\n")
        codigo = 4
    sys.stderr.flush()
    sys.stdout.flush()
    os._exit(codigo)   # encerra sem rodar os destrutores que quebram
