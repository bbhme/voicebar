# Créditos e licenças de terceiros

O VoiceBar não redistribui nenhum dos componentes abaixo. O instalador os baixa
da fonte original na máquina do usuário. Ainda assim, todos merecem crédito, e
as licenças estão listadas para quem precisar avaliar antes de adotar.

## Por que o VoiceBar é GPL-3.0-or-later

O script `speak.py` importa a biblioteca `piper-tts`, que é GPL-3.0-or-later.
Um programa que importa uma biblioteca GPL fica sujeito à mesma licença. Em vez
de discutir onde está a fronteira, o projeto inteiro adota GPL-3.0-or-later.
Todas as demais dependências são compatíveis com essa escolha.

Na prática, isso não impede ninguém de usar o VoiceBar, inclusive dentro de uma
empresa. Só obriga quem redistribuir uma versão modificada a publicar o código.

## Motores de síntese

| Projeto | Licença | Papel |
|---|---|---|
| [piper-tts](https://github.com/OHF-Voice/piper1-gpl) | GPL-3.0-or-later | motor rápido, quatro vozes |
| [kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx) | MIT | motor natural, três vozes |
| [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) | Apache-2.0 | modelo de voz do Kokoro |
| [onnxruntime](https://github.com/microsoft/onnxruntime) | MIT | execução dos modelos |
| [soundfile](https://github.com/bastibe/python-soundfile) | BSD-3-Clause | gravação dos arquivos de áudio |
| [espeak-ng](https://github.com/espeak-ng/espeak-ng) | GPL-3.0-or-later | fonemas, embutido nos dois motores |

## Vozes em português do Brasil

As quatro vozes do Piper vêm de
[rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices), cujo
repositório é MIT. Cada voz, porém, tem a licença do seu próprio conjunto de
dados:

| Voz | Licença | Origem |
|---|---|---|
| cadu | CC0 | domínio público |
| faber | CC0 | domínio público |
| jeff | CC0 | domínio público |
| edresson | CC BY 4.0 | [TTS-Portuguese-Corpus](https://github.com/Edresson/TTS-Portuguese-Corpus), de Edresson Casanova |

A voz **edresson** exige atribuição. Se você distribuir áudio gerado com ela,
credite o corpus acima.

As três vozes do Kokoro (Dora, Alex, Santa) fazem parte do modelo Kokoro-82M,
sob Apache-2.0.

## Serviço opcional

O resumo por inteligência artificial usa a API da OpenAI e só funciona com uma
chave fornecida pelo usuário. Não há chave embutida no projeto, e a
funcionalidade vem desligada. Veja `SECURITY.md`.

## Problemas encontrados e reportados

Duas falhas de terceiros foram diagnosticadas durante o desenvolvimento e estão
contornadas no código, com o motivo explicado em comentário:

**Telemetria do onnxruntime derruba o processo no encerramento.** A telemetria
da Microsoft embutida no onnxruntime abre conexões de rede. Ao encerrar, a
thread principal destrói o sistema de telemetria enquanto uma thread de rede
ainda processa uma resposta HTTP, que então trava um mutex já destruído e aborta
o processo. O áudio já estava gravado, mas quem chamou via código 134 e o
descartava. Contorno em `speak_kokoro.py`: desligar a telemetria e sair por
`os._exit`. Efeito colateral bem-vindo: o sistema deixa de falar com a internet.

**Caminho de fonemas gravado em tempo de compilação no pacote do Piper.** O
wheel publicado carrega o caminho da máquina que o compilou, que não existe em
lugar nenhum. Contorno no instalador: um diretório de atalhos apontando para os
dados que vieram junto com o pacote.
