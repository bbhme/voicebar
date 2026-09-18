# Nome falado de uma sessão do Claude Code. Carregado pelos dois ganchos.
#
# O nome é a pasta onde a sessão foi aberta, e não a pasta atual. A atual muda
# cada vez que o Claude entra numa subpasta, e a mesma sessão acabava anunciada
# como "src", "backend" ou "09" conforme o momento. A exceção é o worktree:
# entrar num worktree é mudar de tarefa, então vale o nome dele.
#
# O nome também é anotado em run/sessoes/<pid>, para o menu Projetos que falam
# listar só as sessões abertas, cada uma com o nome que ela de fato usa.
#
# Uso:  . "$V/projeto.sh"; projeto_da_sessao "<cwd do payload>" "<reserva>"
#       define PROJ; a reserva vale quando não há cwd nem registro

nome_do_worktree() {   # imprime o nome se o caminho estiver dentro de um worktree
  case "$1" in
    */.claude/worktrees/*) local n=${1#*/.claude/worktrees/}; printf '%s' "${n%%/*}";;
  esac
}

projeto_da_sessao() {
  local cwd="$1" reserva="${2:-claude}" pid=$PPID reg="" base="" i
  # sobe pelos processos pais até o Claude Code que chamou o gancho;
  # ele registra cada sessão aberta em ~/.claude/sessions/<pid>.json
  for i in 1 2 3 4 5; do
    { [ -z "$pid" ] || [ "$pid" -le 1 ]; } && break
    [ -f "$HOME/.claude/sessions/$pid.json" ] && { reg="$HOME/.claude/sessions/$pid.json"; break; }
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  [ -n "$reg" ] && base=$(jq -r '.cwd // empty' "$reg" 2>/dev/null)

  PROJ=$(nome_do_worktree "$cwd")
  [ -z "$PROJ" ] && PROJ=$(nome_do_worktree "$base")
  [ -z "$PROJ" ] && [ -n "$base" ] && PROJ=$(basename "$base")
  [ -z "$PROJ" ] && [ -n "$cwd" ] && PROJ=$(basename "$cwd")   # sem registro: como antes
  { [ -z "$PROJ" ] || [ "$PROJ" = "/" ]; } && PROJ="$reserva"

  if [ -n "$reg" ]; then
    mkdir -p "$R/sessoes" && printf '%s\n' "$PROJ" > "$R/sessoes/$pid"
  fi
}
