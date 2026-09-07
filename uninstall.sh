#!/bin/bash
# Remove o VoiceBar. Por padrão preserva os modelos de voz, que são pesados
# e demoram a baixar de novo.  Use --tudo para apagar também.

V="$HOME/.claude/voice"
H="$HOME/.claude/hooks"
TUDO=0
[ "${1:-}" = "--tudo" ] && TUDO=1

ok(){ printf "  \033[32m✓\033[0m %s\n" "$*"; }
info(){ printf "  · %s\n" "$*"; }
step(){ printf "\n\033[1m%s\033[0m\n" "$*"; }

step "Parando o app"
launchctl bootout "gui/$(id -u)/com.claude.voicebar" 2>/dev/null
pkill -x voicebar 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/com.claude.voicebar.plist"
ok "app parado e removido do início automático"

step "Desligando o hook do Claude Code"
S="$HOME/.claude/settings.json"
if [ -f "$S" ] && command -v jq >/dev/null 2>&1; then
  cp "$S" "$S.bak-$(date +%Y%m%d%H%M%S)"
  TMP="$(mktemp)"
  # tira só o nosso hook e limpa entradas que ficarem vazias
  jq '
    if .hooks.Stop then
      .hooks.Stop = [ .hooks.Stop[]
        | .hooks = [ .hooks[]? | select(.command != "~/.claude/hooks/speak-response.sh") ]
        | select((.hooks | length) > 0) ]
      | if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
  ' "$S" > "$TMP" && mv "$TMP" "$S"
  ok "hook removido (backup do settings.json guardado ao lado)"
else
  info "settings.json não encontrado ou jq ausente; remova o bloco Stop à mão"
fi

step "Removendo o serviço de texto selecionado"
rm -rf "$HOME/Library/Services/Ler em voz alta.workflow"
defaults delete pbs NSServicesStatus 2>/dev/null
/System/Library/CoreServices/pbs -flush 2>/dev/null
ok "serviço e atalho removidos"

step "Removendo scripts e comando"
rm -f "$H/speak-response.sh" "$H/speak-response.py" "$H/voice.off"
rm -f "$HOME/.local/bin/voice"
ok "scripts do hook e comando voice removidos"

step "Pasta principal"
if [ "$TUDO" = "1" ]; then
  rm -rf "$V"
  ok "~/.claude/voice apagada por inteiro, incluindo modelos e sua chave da OpenAI"
else
  rm -rf "$V/run" "$V/esp" "$V/voicebar" "$V"/*.sh "$V"/*.py "$V"/*.swift* "$V/voice"
  ok "programas removidos; modelos, vozes e ajustes preservados em $V"
  info "para apagar tudo, rode de novo com  --tudo"
fi

printf "\n\033[1mPronto.\033[0m O Python 3.12 e o jq instalados pelo Homebrew ficaram,\n"
printf "porque outras coisas podem depender deles.\n\n"
