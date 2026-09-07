# Instruções para o Claude Code instalar o VoiceBar

Você está lendo isto porque a pessoa pediu que você instalasse este sistema no
Mac dela. Siga os passos abaixo. Fale com ela em português.

O VoiceBar faz o Mac ler em voz alta as respostas do Claude Code e qualquer
texto selecionado, com síntese local, sem internet e sem limite de uso.

---

## Antes de começar, avise

Diga à pessoa, em uma frase cada, o que a instalação vai fazer:

- Instala cerca de 930 MB em `~/.claude/voice`, quase tudo em modelos de voz.
- Acrescenta uma entrada ao `~/.claude/settings.json`, preservando o resto e
  guardando um backup com data.
- Instala um serviço do sistema e um item de início automático no login.
- Se faltar o Python 3.12, instala pelo Homebrew, sem mexer no Python padrão.

Peça confirmação antes de rodar o instalador. Depois disso, siga sem
interromper a cada passo.

---

## Passo 1: conferir os pré-requisitos

```bash
sw_vers -productVersion
uname -m
command -v swiftc jq brew python3
xcode-select -p
```

O que fazer se faltar algo:

| Faltando | Ação |
|---|---|
| `swiftc` ou `xcode-select -p` falha | Peça para a pessoa rodar `xcode-select --install` e avisar quando terminar. Isso abre uma janela do sistema e você não consegue completar por ela. |
| `brew` | Aponte https://brew.sh e peça para instalar. Não instale o Homebrew por conta própria. |
| `jq` | Rode `brew install jq`. |
| Python 3.12 | Não faça nada, o instalador resolve. |

Se não for macOS, pare e explique que o sistema é só para Mac.

---

## Passo 2: rodar o instalador

A partir da pasta onde este arquivo está:

```bash
./install.sh
```

Ele tem nove etapas e imprime o progresso. Pode levar vários minutos, quase
tudo baixando as vozes. É seguro rodar de novo se algo falhar no meio: ele
refaz apenas o que estiver faltando.

Se a pessoa já tiver as vozes de uma instalação anterior, use
`./install.sh --sem-modelos` para pular o download.

Se o instalador parar com erro, leia a mensagem: ela diz exatamente o que
falta. Resolva e rode de novo.

---

## Passo 3: verificar que ficou tudo certo

```bash
pgrep -x voicebar >/dev/null && echo "app rodando" || echo "app parado"
jq -r '[.hooks.Stop[]?.hooks[]?.command] | join(", ")' ~/.claude/settings.json
~/.claude/voice/voice status
~/.claude/voice/voice list
```

O esperado:

- O app aparece como rodando.
- O comando do hook `~/.claude/hooks/speak-response.sh` aparece uma vez só.
- O status mostra voz, volume, velocidade e o hook ligado.
- A lista traz sete vozes.

Se o app não subiu, abra com `~/.claude/voice/voicebar &` e investigue depois.

---

## Passo 4: testar o som

```bash
~/.claude/voice/voice say "Instalação concluída. Escolha uma voz no menu."
```

Pergunte se a pessoa ouviu. Se não ouviu, confira o volume do sistema e rode
`~/.claude/voice/voice status` para ver se o volume interno não está baixo.

---

## Passo 5: contar o que fazer agora

Diga à pessoa, nesta ordem:

1. Apareceu um ícone de alto-falante na barra de menus, no canto superior direito.
2. Clicando nele e escolhendo **Como usar…** ela vê o guia completo, com um
   botão que lê a explicação em voz alta.
3. Para experimentar as vozes, o submenu **Voz** tem sete. As do Kokoro (Dora,
   Alex, Santa) soam mais naturais; as do Piper são mais rápidas.
4. Para ler um texto qualquer: selecionar, botão direito, Serviços, Ler em voz
   alta. Ou copiar e usar **Ler o que está copiado** no menu.
5. O atalho Control Option Comando L pode só funcionar depois que ela sair e
   entrar de novo na conta, porque o macOS guarda essa lista em cache.
6. Se `~/.local/bin` não estiver no PATH dela, o comando `voice` só funciona
   pelo caminho completo. Ofereça acrescentar ao `~/.zshrc`.

---

## Diagnóstico, se algo não funcionar

**A voz não sai quando o Claude Code responde**

```bash
jq -r '[.hooks.Stop[]?.hooks[]?.command] | join(", ")' ~/.claude/settings.json
ls -l ~/.claude/hooks/speak-response.sh
tail -5 ~/.claude/hooks/speak-response.log
```

O hook precisa estar registrado e o script precisa ser executável. O log mostra
falhas de síntese. Sessões abertas antes da instalação só passam a falar depois
de reiniciadas.

**A síntese falha**

```bash
echo "teste" | ~/.claude/voice/synth.sh cadu /tmp/t.wav && afplay /tmp/t.wav
```

Se falhar, o problema é no motor. Confira se os modelos existem:

```bash
ls -lh ~/.claude/voice/models/ ~/.claude/voice/kokoro/
```

**O ícone não aparece na barra**

```bash
launchctl list | grep voicebar
~/.claude/voice/voicebar &
```

**Ler texto selecionado não aparece em Serviços**

```bash
ls -d ~/Library/Services/*.workflow
/System/Library/CoreServices/pbs -flush
```

Explique que aplicativos já abertos precisam ser reiniciados, e que às vezes é
preciso sair e entrar na conta.

---

## Se a pessoa quiser remover

```bash
./uninstall.sh          # tira os programas, preserva vozes e ajustes
./uninstall.sh --tudo   # tira tudo
```

O desinstalador retira o hook do `settings.json` sem tocar em mais nada, e
guarda um backup antes. O Python e o jq instalados pelo Homebrew permanecem,
porque outras coisas podem depender deles.

---

## Regras que você deve seguir

- **Nunca sobrescreva o `~/.claude/settings.json`.** O instalador já faz a
  mesclagem correta com `jq`. Não escreva esse arquivo por conta própria.
- **Não instale o Homebrew nem as ferramentas do Xcode sem pedir.** As duas
  coisas abrem janelas do sistema ou pedem senha, e a decisão é da pessoa.
- **Não desative outros hooks** que já existam na máquina dela.
- Se o instalador falhar, mostre a mensagem de erro real em vez de tentar
  contornar por conta própria.
