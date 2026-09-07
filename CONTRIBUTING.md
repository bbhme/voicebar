# Contribuindo

Contribuições são bem-vindas. Este arquivo diz onde as coisas estão e quais são
as decisões já tomadas, para você não gastar tempo propondo algo que será
recusado por um motivo que dava para saber antes.

## Antes de tudo

O projeto é **GPL-3.0-or-later**, e isso não é negociável: o `piper-tts`, do qual
dependemos, é GPL. Ao enviar código você concorda em licenciá-lo assim.

## O código

| Arquivo | O que faz |
|---|---|
| `src/VoiceBar.swift` | o app da barra de menus, com todas as janelas |
| `src/voice` | o mesmo controle pela linha de comando |
| `src/synth.sh` | escolhe o motor pela voz e resgata áudio de motor que aborta |
| `src/speak.py` | motor Piper |
| `src/speak_kokoro.py` | motor Kokoro |
| `src/summarize.sh` | resumo opcional pela API da OpenAI |
| `src/read-selection.sh` | leitura de texto selecionado |
| `src/hooks/speak-response.*` | o gatilho do Claude Code e o extrator de texto |
| `src/lang/` | pacotes de idioma da camada de fala |
| `install.sh` / `uninstall.sh` | instalação e remoção |
| `test.sh` | teste de fumaça |

O app e os scripts conversam por arquivos em `~/.claude/voice`. Não há banco de
dados nem servidor. Isso é proposital: dá para depurar tudo com `cat`.

## Rodando o teste

```bash
./test.sh
```

Ele verifica os pré-requisitos, sintetiza com os dois motores, exercita a fila e
confere que o resumo devolve o texto original quando não há chave. Não gasta API.

## Adicionar um idioma

A camada de fala já é traduzível. A interface não.

Para um idioma novo:

1. Copie `src/lang/pt-BR.conf` e `src/lang/pt-BR.prompt` com o novo nome. O
   `en-US` já está lá como exemplo pronto.
2. Ajuste `LANG_CODE` para o código que os motores entendem.
3. Acrescente vozes daquele idioma em `src/voices.txt`, no formato
   `id|motor|parâmetro|rótulo`.
4. Escreva o nome do pacote em `~/.claude/voice/lang.active`.

A interface do app continuará em português. Traduzi-la é um trabalho maior e
seria bem-vindo, mas exige extrair os textos do Swift, o que ninguém fez ainda.

## Decisões já tomadas

Não são imutáveis, mas mude-as com argumento, não por preferência.

- **Arquivos em vez de banco.** Cada ajuste é um arquivo de uma linha, legível e
  editável à mão.
- **A fala nunca pode falhar em silêncio.** Se o resumo, a rede ou um motor
  falharem, o texto original é falado. Qualquer código novo deve manter isso.
- **Nada de rede por padrão.** Só o resumo opcional fala com a internet, e só
  com chave do usuário. Já removemos uma telemetria de terceiros por esse
  princípio.
- **O instalador nunca sobrescreve o `settings.json`.** Ele mescla com `jq` e
  guarda backup. Há teste dos dois sentidos.
- **Português brasileiro é o idioma de origem**, e o projeto assume isso em vez
  de fingir neutralidade.

## Enviando uma mudança

Descreva o que muda e como você testou. Se corrigir um erro, diga como
reproduzi-lo. Mudanças na síntese precisam dizer em qual Mac e qual macOS foram
testadas, porque o comportamento varia.

Se for mexer no resumo, meça. A instrução atual foi escolhida comparando três
formulações e medindo a diferença entre o alvo e o resultado real.

## Coisas úteis para fazer

- Traduzir a interface do app.
- Vozes de outros idiomas, com a licença verificada.
- Colar automático no ditado para Windows e Linux, que hoje não existe.
- Substituir o arquivo da chave da OpenAI pelo Chaveiro do macOS.
- Testes de verdade, além do teste de fumaça.
