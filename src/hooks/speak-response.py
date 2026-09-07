#!/usr/bin/env python3
"""Extrai a última resposta de texto do assistente de uma transcrição JSONL do Claude Code
e imprime uma versão limpa para o `say`."""
import json, re, sys

path, max_chars = sys.argv[1], int(sys.argv[2])
last = None
with open(path, encoding="utf-8", errors="ignore") as f:
    for line in f:
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get("type") != "assistant":
            continue
        content = (o.get("message") or {}).get("content") or []
        if isinstance(content, str):
            parts = [content]
        else:
            parts = [c.get("text", "") for c in content
                     if isinstance(c, dict) and c.get("type") == "text"]
        t = "\n".join(p for p in parts if p).strip()
        if t:
            last = t
if not last:
    sys.exit(0)

t = last
t = re.sub(r"```.*?```", " (bloco de código) ", t, flags=re.S)
t = re.sub(r"`[^`]*`", "", t)
t = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", t)
t = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", t)
t = re.sub(r"https?://\S+", "link", t)
t = re.sub(r"^#{1,6}\s*", "", t, flags=re.M)
t = re.sub(r"[*_>|]+", "", t)
t = re.sub(r"^\s*[-•]\s+", "", t, flags=re.M)
t = re.sub(r"\s+", " ", t).strip()
if max_chars and len(t) > max_chars:
    t = t[:max_chars].rsplit(" ", 1)[0] + ". Resposta longa, veja o restante na tela."
print(t)
