# O que o VoiceBar toca na sua máquina

Este documento existe para você decidir com informação, não para tranquilizar.
Leia antes de instalar, principalmente se a máquina for de trabalho.

## O ponto mais importante

**O VoiceBar instala um gatilho que lê o texto de toda resposta do Claude Code.**

É assim que ele funciona: sem ler a resposta, não há o que falar. O gatilho é o
arquivo `~/.claude/hooks/speak-response.sh`, registrado como hook do tipo `Stop`
no seu `~/.claude/settings.json`.

Se você trabalha com código ou dados sob acordo de confidencialidade, entenda o
que isso significa antes de seguir.

## O que sai da máquina

Na configuração padrão, **nada**. A síntese de voz é local e não usa rede.

Há exatamente duas situações em que dados saem, e as duas dependem de ação sua:

| Quando | O que sai | Para onde |
|---|---|---|
| Você ativa o Resumo por IA | o texto que seria falado | API da OpenAI |
| O instalador roda | nada seu; só baixa modelos | Hugging Face e GitHub |

Sem chave da OpenAI, o resumo não funciona e nenhum texto sai. Não existe chave
embutida no projeto.

Uma terceira saída existia e foi eliminada: o `onnxruntime` traz telemetria da
Microsoft ligada por padrão, que abria conexões a cada síntese. O VoiceBar a
desliga explicitamente. Veja `CREDITS.md`.

## Onde ficam suas coisas

| Arquivo | Conteúdo | Permissão |
|---|---|---|
| `~/.claude/voice/openai.env` | sua chave da OpenAI | `600`, só você lê |
| `~/.claude/voice/projects.txt` | nomes das pastas dos seus projetos | padrão |
| `~/.claude/voice/labels.txt` | as legendas que você escreveu | padrão |
| `~/.claude/voice/summary_prompt.txt` | suas instruções para a IA | padrão |
| `~/.claude/voice/run/` | áudios temporários, apagados após tocar | padrão |
| `~/.claude/voice/run/sessoes/` | o nome de projeto de cada sessão aberta | padrão |
| `~/.claude/hooks/speak-response.log` | erros e um resumo de cada leitura | padrão |

**A chave da OpenAI fica num arquivo comum, não no Chaveiro do macOS.** A
permissão impede outros usuários da máquina de lê-la, mas qualquer programa
rodando com a sua conta consegue. Se isso não for aceitável no seu contexto, não
use o resumo por IA.

O log registra o tamanho dos textos e o nome dos projetos, não o conteúdo das
respostas.

Para listar só os projetos abertos, o app e os gatilhos leem o registro de
sessões que o próprio Claude Code mantém em `~/.claude/sessions/`. Usam apenas o
número do processo, a pasta e o horário de início de cada sessão; nada é
gravado ali e nada sai da máquina.

## O que o instalador altera

- Acrescenta uma entrada ao `~/.claude/settings.json`, preservando o resto e
  guardando um backup com data antes.
- Instala um serviço em `~/Library/Services` e um item de início automático em
  `~/Library/LaunchAgents`.
- Cria um atalho de teclado do sistema, gravado em `defaults` no domínio `pbs`.
- Se faltar o Python 3.12, instala pelo Homebrew, em paralelo ao seu Python.

Nada pede senha de administrador. Tudo fica dentro da sua pasta pessoal.

## Como remover por completo

```bash
./uninstall.sh --tudo
```

Isso apaga a pasta inteira, incluindo a chave da OpenAI, e retira o gatilho do
`settings.json` sem tocar em mais nada.

## Relatando um problema de segurança

Abra uma issue descrevendo a classe do problema, sem incluir dados reais nem um
roteiro de exploração. Se o problema envolver vazamento de dados de terceiros,
prefira contato direto com o mantenedor antes de publicar.
