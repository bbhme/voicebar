# VoiceBar

Faz o seu Mac ler em voz alta as respostas do Claude Code, e qualquer texto que
você selecionar. A voz é gerada dentro do seu próprio computador: não usa
internet, não pede cadastro e não tem limite de uso.

**Antes de instalar, leia o `SECURITY.md`.** Em resumo: isto instala um gatilho
que lê o texto de toda resposta do Claude Code, que é como ele funciona, e o
resumo opcional envia texto para a OpenAI.

Depois de instalado, aparece um ícone de alto-falante na barra de menus, com
pausa, volume, velocidade, fila e sete vozes brasileiras para escolher.

---

## Instalando

Há dois caminhos. Escolha um.

### Caminho 1: peça para o Claude Code instalar

Se você usa o Claude Code, este é o jeito mais fácil. Abra ele na pasta onde
você descompactou este arquivo e diga:

> Leia o arquivo PARA-O-CLAUDE-CODE.md e instale este sistema para mim.

Ele confere o que falta, instala, testa e te avisa o que fazer depois.

### Caminho 2: rode o instalador você mesmo

Abra o Terminal, vá até a pasta e execute:

```bash
./install.sh
```

Leva alguns minutos. A maior parte do tempo é o download das vozes.

---

## O que sua máquina precisa ter

O instalador confere tudo antes de começar e para com uma mensagem clara
dizendo o comando exato se faltar alguma coisa.

| Item | Se faltar |
|---|---|
| macOS | Testado no 26. Funciona em Apple Silicon e Intel. |
| Ferramentas de linha de comando | `xcode-select --install` |
| Homebrew | Instruções em https://brew.sh |
| jq | `brew install jq` |
| Python 3.12 | O instalador coloca sozinho |

O Python 3.12 é exigido por um dos motores de voz, que ainda não roda em
versões mais novas. Ele é instalado em paralelo e **não mexe** no Python que
você já usa.

O Claude Code não é obrigatório. Sem ele, a leitura de texto selecionado
continua funcionando normalmente.

---

## O que é instalado, e onde

Fique à vontade para conferir antes. Na configuração padrão, nada sai da sua
máquina; as duas exceções estão detalhadas no `SECURITY.md`.

| Caminho | O que é |
|---|---|
| `~/.claude/voice/` | programas, vozes e ajustes |
| `~/.claude/hooks/speak-response.*` | o gatilho que dispara a leitura |
| `~/.claude/settings.json` | ganha uma entrada; o resto é preservado |
| `~/Library/Services/Ler em voz alta.workflow` | leitura de texto selecionado |
| `~/Library/LaunchAgents/com.claude.voicebar.plist` | abre o app no login |
| `~/.local/bin/voice` | atalho para o comando de terminal |

Ocupa cerca de 930 MB, quase tudo em modelos de voz.

Sobre o `settings.json`: se você já usa o Claude Code, esse arquivo tem as suas
configurações. O instalador **acrescenta** uma entrada e preserva todo o resto,
guardando um backup com data antes de qualquer mudança. Isso foi testado nos
dois sentidos: instalar e desinstalar devolve o arquivo exatamente como estava.

---

## As sete vozes

Todas em português do Brasil, de dois motores diferentes.

| Voz | Motor | Como é |
|---|---|---|
| Dora, Alex, Santa | Kokoro | mais naturais, cerca de 2 segundos para gerar |
| Cadu, Faber, Jeff, Edresson | Piper | mais rápidas, cerca de 1 segundo |

Troque pelo submenu **Voz**, no ícone da barra.

---

## Primeiros passos

Depois de instalar, clique no ícone da barra de menus e escolha **Como usar…**.
São 22 seções explicando tudo, e há um botão que lê a explicação em voz alta.

No terminal:

```bash
voice say "Testando a voz."   # ouve alguma coisa agora
voice list                    # mostra as sete vozes
voice use dora                # troca de voz
voice status                  # mostra o estado atual
voice                         # manual completo dos comandos
```

---

## Ler um texto qualquer

Quatro caminhos levam ao mesmo lugar:

1. Clique em **Ler um texto…** no menu da barra. Abre uma janela onde você cola
   ou escreve, com contagem de palavras e estimativa de duração. Ali dá para
   resumir só aquele texto, escolhendo um tamanho e uma instrução diferentes
   dos globais, sem alterar a configuração do sistema.
2. Selecione o texto, clique com o botão direito, **Serviços**, **Ler em voz alta**.
3. Selecione o texto e pressione **Control Option Comando L**.
4. Copie com Comando C e clique em **Ler o que está copiado**, no menu da barra.

O atalho e o item em Serviços podem só aparecer depois que você sair e entrar
de novo na conta, porque o macOS guarda essa lista em cache. Aplicativos que já
estavam abertos precisam ser reiniciados para enxergar o novo item. Os caminhos pelo menu,
que são o primeiro e o quarto, funcionam na hora.

---

## Avisos quando o Claude Code precisa de você

Além de ler as respostas, o sistema avisa em quatro situações:

| Situação | O que você ouve |
|---|---|
| Claude fez uma pergunta | `<projeto> fez uma pergunta` |
| Claude pede permissão | `<projeto> pede permissão` |
| Claude está esperando você | `<projeto> precisa de você` |
| O turno terminou em erro | `<projeto> parou com erro` |

O aviso é curto e fura a fila, porque existe para interromper. Avisos iguais do
mesmo projeto respeitam quinze segundos de intervalo, para uma sequência de
permissões não virar metralhadora.

Some no menu pelo item **Avisar quando precisar de você**, separado da leitura
das respostas. Uma resposta que termina em pergunta também é anunciada como tal.

---

## Resumo por IA (opcional, vem desligado)

Se você quiser, o texto pode passar por uma inteligência artificial que o
encurta antes de ser falado. Para isso é preciso colar uma chave da OpenAI em
**Resumo por IA…**, no menu.

Dá para escolher o modelo, definir o tamanho por porcentagem ou por número de
palavras, e escrever instruções livres sobre tom, tratamento de símbolos e o
que nunca pode ser cortado.

Se a chave falhar ou a internet cair, o texto original é falado normalmente.
O resumo nunca deixa você sem áudio.

Sem chave, todo o resto funciona offline.

---

## Desinstalando

```bash
./uninstall.sh          # tira os programas, preserva as vozes e seus ajustes
./uninstall.sh --tudo   # tira tudo
```

O gatilho é retirado do `settings.json` sem tocar em mais nada, e um backup é
guardado antes.

---

## Licença

GPL-3.0-or-later. Não foi uma escolha livre: o projeto depende do `piper-tts`,
que é GPL. O raciocínio completo e a lista de dependências estão no `CREDITS.md`,
junto com as licenças das sete vozes.

A voz **edresson** exige atribuição ao corpus de origem se você distribuir áudio
gerado com ela. As outras seis não exigem nada.

---

## Se algo der errado

Erros ficam registrados em `~/.claude/hooks/speak-response.log`.

### Se o ícone sumir da barra

| Situação | O que acontece |
|---|---|
| O app caiu sozinho | volta em cerca de três segundos, sem você fazer nada |
| Você escolheu **Sair** | fica fechado; use `voice bar` para abrir |
| Alguma coisa estranha | menu, **Reiniciar o app** |
| O menu nem abre | `voice restart` no terminal |
| Você reiniciou o Mac | volta sozinho no login |

O sistema vigia o app e o reinicia **apenas quando a saída foi anormal**. Se você
escolheu Sair, ele respeita a sua decisão e não insiste.

Travamento é o único caso que o vigia não cobre, porque o processo não morreu,
só parou de responder. O `voice restart` derruba o travado e sobe um novo.

Se a fala parar, rode `voice status`. Ele mostra se o gatilho está ligado, qual
voz está ativa e quantas falas estão na fila.

Rode `./test.sh` para uma checagem completa da instalação. Ele confere os
pré-requisitos, sintetiza com os dois motores, exercita a fila e verifica que a
fala não falha em silêncio. Não gasta chamada de API.

Se preferir, mande o Claude Code ler o arquivo `PARA-O-CLAUDE-CODE.md`, que tem
uma seção de diagnóstico.
