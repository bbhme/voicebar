import AppKit
import AVFoundation

let HOME = NSHomeDirectory()
let VDIR = HOME + "/.claude/voice"
let RDIR = VDIR + "/run"
let QDIR = RDIR + "/q"
let CMDF = RDIR + "/cmd"
let VOLF = VDIR + "/volume"
let SPDF = VDIR + "/speed"
let CURF = VDIR + "/current"
let MODEF = VDIR + "/mode"
let MUTEDF = VDIR + "/muted.txt"
let PROJF = VDIR + "/projects.txt"
let ANNF = VDIR + "/announce"
let OFFF = HOME + "/.claude/hooks/voice.off"
let BARPID = RDIR + "/bar.pid"
let CONFF = VDIR + "/summary.conf"
let KEYF = VDIR + "/openai.env"
let PAUSEF = VDIR + "/pause"
let ALERTSF = VDIR + "/alerts"
let PROMPTF = VDIR + "/summary_prompt.txt"
let LABELSF = VDIR + "/labels.txt"

let MAX_AGE: Double = 180     // descarta fala com mais de 3 min de espera
let MAX_QUEUE = 4             // guarda no máximo 4 na fila

func readf(_ p: String) -> String? {
    guard let s = try? String(contentsOfFile: p, encoding: .utf8) else { return nil }
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t
}
func lines(_ p: String) -> [String] {
    (readf(p) ?? "").split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}
func writef(_ p: String, _ s: String) { try? s.write(toFile: p, atomically: true, encoding: .utf8) }
func mmss(_ t: TimeInterval) -> String { let s = max(0, Int(t.rounded())); return String(format: "%d:%02d", s/60, s%60) }
func rm(_ p: String) { try? FileManager.default.removeItem(atPath: p) }

/// Frase falada vinda do pacote de idioma ativo, com reserva embutida.
func fala(_ chave: String, _ reserva: String) -> String {
    let nome = readf(VDIR + "/lang.active") ?? "pt-BR"
    for arq in ["\(VDIR)/lang/\(nome).conf", "\(VDIR)/lang/pt-BR.conf"] {
        for l in lines(arq) where l.hasPrefix(chave + "=") {
            let v = String(l.dropFirst(chave.count + 1)).trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { return v }
        }
    }
    return reserva
}


// MARK: ajuda
let AJUDA: [(String, String)] = [
 ("O que este app faz",
  "Ele lê em voz alta a resposta final de cada sessão do Claude Code, e também qualquer texto que você mandar. Todo o áudio é gerado aqui no seu Mac, sem internet, sem conta e sem limite de uso. Os controles vivem no ícone de alto-falante da barra de menus, no canto superior direito da tela."),

 ("O ícone mostra o estado sem você abrir nada",
  "Alto-falante normal: parado.  Alto-falante cheio: lendo.  Onda menor: num silêncio entre partes.  Símbolo de pausa: você pausou.  Alto-falante riscado: a leitura das respostas está desligada."),

 ("As duas primeiras linhas do menu",
  "A primeira diz o que acontece agora: Anunciando com o nome do projeto, Pausa durante os silêncios, Lendo com o tempo que ainda falta, ou Parado. A segunda só aparece quando há espera, e mostra quantas falas estão na fila e de quais projetos."),

 ("Ouvir, pausar, pular e parar",
  "Pausar congela no ponto exato e vira Retomar.  Pular esta abandona a fala atual e chama a próxima da fila.  Parar descarta a fala atual inteira.  Limpar a fila joga fora tudo que espera, sem interromper a que está tocando."),

 ("Volume e velocidade",
  "Os dois controles deslizantes valem na hora, no meio da frase, não apenas na próxima fala. A velocidade vai de 0,6x até 1,8x e preserva o tom da voz, então acelerar não deixa ela fina. Perto do normal o controle encaixa exatamente em 1x sozinho, e o item Velocidade normal devolve para 1x com um clique."),

 ("Escolher a voz",
  "São sete vozes brasileiras, de dois motores. Dora, Alex e Santa vêm do Kokoro: soam mais naturais, saem em 24 kHz e levam cerca de dois segundos para gerar. Cadu, Faber, Jeff e Edresson vêm do Piper: são mais rápidas, cerca de um segundo. A troca vale a partir da próxima fala."),

 ("A fila, quando várias sessões terminam juntas",
  "Em vez de se atropelarem, as falas entram na fila e tocam uma depois da outra. A fila guarda até quatro e descarta o que passou de três minutos esperando, porque uma resposta velha já não interessa."),

 ("Ver a fila e escolher o que ouvir",
  "O submenu Fila mostra quem está falando, marcado com um triângulo, e quem espera, numerado e com o tempo de espera de cada um. Clique em qualquer item da espera para ouvi-lo agora. O que estava tocando volta para a fila na posição dele, então nada se perde."),

 ("Silenciar um projeto",
  "O submenu Projetos que falam lista cada projeto que já falou, com uma marca de seleção. Desmarque para silenciar. O bloqueio acontece antes de gerar o áudio, então um projeto silenciado não consome processamento nenhum. Ativar todos religa tudo de uma vez."),

 ("Dar um nome falado a cada projeto",
  "No mesmo submenu, Como cada um é falado abre uma janela com um campo por projeto. O que você escrever ali é o que a voz diz antes da resposta, no lugar do nome da pasta. Serve para acrescentar uma explicação a uma sigla, ou para substituir um nome técnico difícil de ouvir, cheio de pontos e hifens, por algo curto e claro. Cada linha tem um botão de ouvir, para conferir antes de salvar. Deixando em branco, volta a valer o nome da pasta."),

 ("Fila ou só a mais recente",
  "No submenu Quando chegam juntas, Entram na fila é o padrão e não perde nada. Só a mais recente fala descarta as anteriores na hora, útil quando você só quer saber do último resultado."),

 ("O anúncio de origem",
  "Antes de cada leitura o app diz de onde ela veio: o nome do projeto, ou Texto selecionado, ou Texto copiado. O nome vai num áudio próprio e é sempre falado em velocidade normal, um pouco mais alto que o conteúdo, mesmo que você tenha acelerado a leitura. É esse contraste que faz o nome se destacar. Desmarque Anunciar a origem antes para desligar."),

 ("Pausa ao trocar de projeto",
  "Há um silêncio antes do nome e outro entre o nome e o conteúdo. Quando a fala seguinte vem de outro projeto, o silêncio de abertura fica bem maior, para o ouvido registrar a troca. Os perfis são Sem pausa, Curta, Média e Longa."),

 ("Resumo por IA",
  "Em Resumo por IA você cola sua chave da OpenAI, clica em Buscar para listar os modelos da sua conta e escolhe um. O tamanho pode ser uma redução em porcentagem ou um número fixo de palavras. Textos curtos passam inteiros, sem gastar chamada de API. Se a chave falhar ou o modelo tiver sido descontinuado, o texto original é falado normalmente e a janela mostra o motivo exato que a API devolveu. Use Testar agora antes de ativar."),

 ("Instruções para a IA",
  "O campo de texto livre na mesma janela manda mais que as regras internas do resumidor, então serve para o que você quiser: mudar o tom, dizer como tratar símbolos e siglas, proteger números e nomes que nunca podem sumir, ou pedir que a resposta comece pelo resultado. O botão Exemplos abre oito instruções prontas, que você pode inserir e depois editar. Deixe em branco para usar só o padrão."),

 ("Avisos quando o Claude Code precisa de você",
  "Além de ler as respostas, o sistema avisa em quatro situações: quando o Claude faz uma pergunta, quando pede permissão para executar algo, quando fica parado esperando você, e quando o turno termina em erro. O aviso é curto, diz o nome do projeto e fura a fila, porque existe para interromper. Avisos iguais do mesmo projeto respeitam um intervalo de quinze segundos, para uma sequência de permissões não virar metralhadora. O item Avisar quando precisar de você liga e desliga isso, separado da leitura das respostas. Uma resposta que termina em pergunta também é anunciada como pergunta."),

 ("Ler qualquer texto, não só as respostas",
  "Quatro caminhos levam ao mesmo lugar. Ler um texto abre uma janela onde você cola ou escreve, com contagem de palavras e estimativa de duração. Ou selecione o texto em qualquer aplicativo e use o botão direito, Serviços, Ler em voz alta. Ou pressione Control, Option, Comando e L com o texto selecionado. Ou copie com Comando C e clique em Ler o que está copiado. Em todos, a leitura fura a fila e o que estava tocando volta para a fila em vez de se perder."),

 ("A janela Ler um texto",
  "O botão Colar acrescenta o que estiver na área de transferência sem apagar o que já está escrito, então dá para juntar vários trechos. A contagem embaixo mostra as palavras e quanto tempo o áudio deve durar na velocidade atual, e ela se ajusta quando você move o controle de velocidade. O botão Ler responde ao Enter."),

 ("Resumir só um texto, do seu jeito",
  "Marcando Resumir antes de ler, dois campos ao lado passam a valer. O menu de tamanho deixa você usar uma redução diferente da global só nesta leitura, e o campo de instrução aceita um pedido diferente do global, também só desta vez. Deixando o menu em Tamanho do ajuste global e o campo em branco, ele usa exatamente o que está configurado em Resumo por IA. Nada do que você escolher aqui altera os ajustes globais. Marcar esta opção também resume mesmo que o resumo esteja desligado no menu, porque foi um pedido explícito seu."),

 ("Desligar, sair e voltar",
  "Ler as respostas desmarcado silencia as respostas do Claude Code, mas você continua podendo mandar ler um texto. Sair fecha o app: a leitura das respostas continua funcionando, só que sem controles, sem fila e sem anúncio."),

 ("Se o app cair ou travar",
  "Se ele cair sozinho, volta em cerca de três segundos: o sistema o vigia e o reinicia, mas só quando a saída foi anormal. Quando você escolhe Sair, ele fica fechado, como deve. O item Reiniciar o app derruba e sobe de novo na hora, útil depois de qualquer coisa estranha; a fila sobrevive, porque ela são arquivos em disco, e só a fala que estava tocando se perde. Se ele travar a ponto de o menu não abrir, o mesmo efeito vem de voice restart no terminal. Para abrir depois de ter saído, use voice bar. E ele sempre volta sozinho quando você faz login."),

 ("Tudo isso também funciona no terminal",
  "Pelo comando voice.  Reprodução: pause, resume, toggle, skip, stop, clear.  Ajustes: vol, speed, use, list.  Fila: fila, pick, mode, mute, unmute, projetos.  Extras: pausa, announce, resumo, say, status.  Sem argumento, cada um mostra o valor atual."),
]

let AJUDA_FALADA = """
Este app lê em voz alta as respostas do Claude Code e qualquer texto que você mandar. \
Todo o áudio é gerado no seu próprio Mac, sem internet e sem limite. \
Os controles ficam no ícone de alto-falante da barra de menus. \
Lá você pausa, retoma, pula a fala atual ou para de vez, \
e os dois controles deslizantes, de volume e de velocidade, funcionam no meio da frase. \
São sete vozes brasileiras de dois motores diferentes, todas trocáveis pelo menu. \
Quando várias sessões terminam ao mesmo tempo, elas entram numa fila em vez de se atropelar. \
Abra o submenu Fila para ver quem fala e quem espera, e clique em qualquer item para ouvi-lo na hora. \
Antes de cada leitura o app anuncia a origem, sempre em velocidade normal, para o nome do projeto se destacar. \
Quando a fala seguinte vem de outro projeto, o silêncio de abertura fica maior. \
No submenu Projetos que falam, desmarque quem você não quer ouvir. \
Em Resumo por IA você pode encurtar os textos antes de ouvi-los, usando sua chave da OpenAI. \
E para ler um texto qualquer, selecione, clique com o botão direito e escolha Serviços, Ler em voz alta. \
Tudo isso também funciona pelo terminal, com o comando voice.
"""

struct Job { let job: String; let wav: String; let ann: String; let proj: String; let ts: Double; let prio: Bool }
enum Fase { case parado, anuncio, conteudo }

/// Pausas, em segundos. A do "trocou" é maior de propósito: dá tempo ao ouvido
/// de registrar que quem fala agora é outro projeto.
let PAUSAS: [String: (mesmo: Double, trocou: Double, apos: Double)] = [
  "sem":   (0.00, 0.00, 0.15),
  "curta": (0.20, 0.60, 0.35),
  "media": (0.35, 1.20, 0.55),
  "longa": (0.60, 2.00, 0.90),
]

final class Controller: NSObject, NSApplicationDelegate, AVAudioPlayerDelegate, NSTextViewDelegate {
    var item: NSStatusItem!
    var player: AVAudioPlayer?
    var volume: Float = 1.0
    var speed: Float = 1.0
    var nowProj = ""
    var nowWav = ""
    var nowAnn = ""
    var nowTs: Double = 0
    var fase: Fase = .parado
    var geracao = 0          // invalida reproduções agendadas que ficaram obsoletas
    var ultimoProj = ""      // para saber se houve troca de projeto
    var queueSig = ""
    var helpWin: NSWindow?
    var queued: [Job] = []
    var stateItem, queueItem, ppItem, skipItem, stopItem, clearItem, offItem, annItem, alertItem: NSMenuItem!
    var voiceMenu, projMenu, modeMenu, queueMenu, pauseMenu: NSMenu!
    var volLabel, spdLabel: NSTextField!
    var volSlider, spdSlider: NSSlider!
    var projSig = ""
    var iconeAtual = ""      // evita recriar e redesenhar o ícone 3x por segundo
    // ajustes do resumo por IA
    var cfgWin: NSWindow?
    var keyField: NSSecureTextField!
    var wordsField, minField, wordsUnit, keyStatus, modelStatus, testOut: NSTextField!
    var modelPop, pctPop: NSPopUpButton!
    var modeSeg: NSSegmentedControl!
    var promptView: NSTextView!
    // janela de texto avulso
    var textoWin: NSWindow?
    var textoView: NSTextView!
    var textoInfo, textoInstrLabel: NSTextField!
    var textoResumir: NSButton!
    var textoPct: NSPopUpButton!
    var textoInstr: NSTextView!
    var textoInstrBox: NSScrollView!
    // janela de legendas dos projetos
    var labelsWin: NSWindow?
    var labelFields: [(String, NSTextField)] = []
    var enableBox: NSButton!

    /// Um app de barra de menus não tem menu principal, e é dele que vêm os atalhos
    /// de edição. Sem este menu, Comando C, V, X, Z e A não funcionam em campo nenhum.
    /// O menu fica invisível, por ser um app acessório: serve só para os atalhos.
    func montarMenuDeEdicao() {
        let principal = NSMenu()

        let itemApp = NSMenuItem(); principal.addItem(itemApp)
        itemApp.submenu = NSMenu(title: "VoiceBar")

        let itemEditar = NSMenuItem(); principal.addItem(itemEditar)
        let editar = NSMenu(title: "Editar")
        itemEditar.submenu = editar

        func add(_ titulo: String, _ acao: String, _ tecla: String,
                 _ mods: NSEvent.ModifierFlags = [.command]) {
            let mi = NSMenuItem(title: titulo, action: Selector((acao)), keyEquivalent: tecla)
            mi.keyEquivalentModifierMask = mods
            editar.addItem(mi)
        }
        add("Desfazer", "undo:", "z")
        add("Refazer", "redo:", "z", [.command, .shift])
        editar.addItem(.separator())
        add("Recortar", "cut:", "x")
        add("Copiar", "copy:", "c")
        add("Colar", "paste:", "v")
        add("Colar sem formatação", "pasteAsPlainText:", "v", [.command, .shift, .option])
        add("Apagar", "delete:", "", [])   // sem atalho, só para a ação existir
        editar.addItem(.separator())
        add("Selecionar Tudo", "selectAll:", "a")

        NSApp.mainMenu = principal
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        montarMenuDeEdicao()
        try? FileManager.default.createDirectory(atPath: QDIR, withIntermediateDirectories: true)
        writef(BARPID, String(ProcessInfo.processInfo.processIdentifier))
        volume = Float(readf(VOLF) ?? "1.0") ?? 1.0
        speed = min(1.8, max(0.6, Float(readf(SPDF) ?? "1.0") ?? 1.0))
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        icone("speaker.wave.2")
        buildMenu()
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in self?.tick() }
    }
    /// Troca o ícone da barra só quando o símbolo muda. Sem isto o app
    /// recriava um NSImage e redesenhava a barra de menus a cada 0,3 s, para sempre.
    func icone(_ n: String) {
        guard n != iconeAtual else { return }
        iconeAtual = n
        item.button?.image = sym(n)
    }

    func sym(_ n: String) -> NSImage? {
        let i = NSImage(systemSymbolName: n, accessibilityDescription: "voz"); i?.isTemplate = true; return i
    }

    func sliderRow(_ cap: String, _ lo: String, _ hi: String, _ mn: Double, _ mx: Double,
                   _ v: Float, _ act: Selector, ticks: Bool) -> (NSView, NSSlider, NSTextField) {
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 244, height: 44))
        let c = NSTextField(labelWithString: cap)
        c.font = .systemFont(ofSize: 11, weight: .medium); c.textColor = .secondaryLabelColor
        c.frame = NSRect(x: 14, y: 25, width: 90, height: 14); box.addSubview(c)
        let val = NSTextField(labelWithString: "")
        val.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        val.textColor = .secondaryLabelColor; val.alignment = .right
        val.frame = NSRect(x: 165, y: 25, width: 62, height: 14); box.addSubview(val)
        let l = NSImageView(frame: NSRect(x: 14, y: 6, width: 15, height: 14))
        l.image = sym(lo); l.contentTintColor = .secondaryLabelColor; box.addSubview(l)
        let r = NSImageView(frame: NSRect(x: 212, y: 6, width: 16, height: 14))
        r.image = sym(hi); r.contentTintColor = .secondaryLabelColor; box.addSubview(r)
        let s = NSSlider(frame: NSRect(x: 34, y: 4, width: 172, height: 18))
        s.minValue = mn; s.maxValue = mx; s.floatValue = v
        s.target = self; s.action = act; s.isContinuous = true
        if ticks { s.numberOfTickMarks = 7 }
        box.addSubview(s)
        return (box, s, val)
    }

    func buildMenu() {
        let m = NSMenu(); m.autoenablesItems = false
        stateItem = NSMenuItem(title: "Parado", action: nil, keyEquivalent: ""); stateItem.isEnabled = false
        m.addItem(stateItem)
        queueItem = NSMenuItem(title: "", action: nil, keyEquivalent: ""); queueItem.isEnabled = false
        m.addItem(queueItem)
        m.addItem(.separator())

        ppItem = NSMenuItem(title: "Pausar", action: #selector(togglePlay), keyEquivalent: ""); ppItem.target = self
        skipItem = NSMenuItem(title: "Pular esta", action: #selector(skip), keyEquivalent: ""); skipItem.target = self
        stopItem = NSMenuItem(title: "Parar", action: #selector(stopPlay), keyEquivalent: ""); stopItem.target = self
        clearItem = NSMenuItem(title: "Limpar a fila", action: #selector(clearQueue), keyEquivalent: ""); clearItem.target = self
        [ppItem, skipItem, stopItem, clearItem].forEach { m.addItem($0!) }
        m.addItem(.separator())

        let (vB, vS, vL) = sliderRow("Volume", "speaker.fill", "speaker.wave.3.fill", 0, 1, volume, #selector(volChanged), ticks: false)
        volSlider = vS; volLabel = vL; let vI = NSMenuItem(); vI.view = vB; m.addItem(vI)
        let (sB, sS, sL) = sliderRow("Velocidade", "tortoise.fill", "hare.fill", 0.6, 1.8, speed, #selector(spdChanged), ticks: true)
        spdSlider = sS; spdLabel = sL; let sI = NSMenuItem(); sI.view = sB; m.addItem(sI)
        let rst = NSMenuItem(title: "Velocidade normal", action: #selector(resetSpeed), keyEquivalent: ""); rst.target = self
        m.addItem(rst)
        m.addItem(.separator())

        queueMenu = NSMenu(); let qi = NSMenuItem(title: "Fila", action: nil, keyEquivalent: "")
        m.addItem(qi); m.setSubmenu(queueMenu, for: qi)
        voiceMenu = NSMenu(); let vi = NSMenuItem(title: "Voz", action: nil, keyEquivalent: "")
        m.addItem(vi); m.setSubmenu(voiceMenu, for: vi)
        projMenu = NSMenu(); let pi = NSMenuItem(title: "Projetos que falam", action: nil, keyEquivalent: "")
        m.addItem(pi); m.setSubmenu(projMenu, for: pi)
        modeMenu = NSMenu(); let mi = NSMenuItem(title: "Quando chegam juntas", action: nil, keyEquivalent: "")
        m.addItem(mi); m.setSubmenu(modeMenu, for: mi)
        pauseMenu = NSMenu(); let pzi = NSMenuItem(title: "Pausa ao trocar de projeto", action: nil, keyEquivalent: "")
        m.addItem(pzi); m.setSubmenu(pauseMenu, for: pzi)
        m.addItem(.separator())

        annItem = NSMenuItem(title: "Anunciar a origem antes", action: #selector(toggleAnn), keyEquivalent: "")
        annItem.target = self; m.addItem(annItem)
        alertItem = NSMenuItem(title: "Avisar quando precisar de você", action: #selector(toggleAlerts), keyEquivalent: "")
        alertItem.target = self; m.addItem(alertItem)
        m.addItem(.separator())
        let txt = NSMenuItem(title: "Ler um texto…", action: #selector(showTexto), keyEquivalent: "t")
        txt.target = self; m.addItem(txt)
        let clip = NSMenuItem(title: "Ler o que está copiado", action: #selector(readClipboard), keyEquivalent: "")
        clip.target = self; m.addItem(clip)
        m.addItem(.separator())
        offItem = NSMenuItem(title: "Ler as respostas", action: #selector(toggleOff), keyEquivalent: ""); offItem.target = self
        m.addItem(offItem)
        m.addItem(.separator())
        let si = NSMenuItem(title: "Resumo por IA…", action: #selector(showSettings), keyEquivalent: ","); si.target = self
        m.addItem(si)
        let hi = NSMenuItem(title: "Como usar…", action: #selector(showHelp), keyEquivalent: "?"); hi.target = self
        m.addItem(hi)
        m.addItem(.separator())
        let rei = NSMenuItem(title: "Reiniciar o app", action: #selector(reiniciar), keyEquivalent: "r")
        rei.target = self; m.addItem(rei)
        let q = NSMenuItem(title: "Sair", action: #selector(quit), keyEquivalent: "q"); q.target = self; m.addItem(q)
        item.menu = m
        rebuildVoices(); rebuildProjects(); rebuildMode(); rebuildPause(); rebuildQueue(); refreshMenu()
    }

    func rebuildVoices() {
        voiceMenu.removeAllItems()
        let cur = readf(CURF) ?? "cadu"
        for line in lines(VDIR + "/voices.txt") {
            let f = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 4 else { continue }
            let mi = NSMenuItem(title: f[3], action: #selector(pickVoice(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = f[0]; mi.state = (f[0] == cur) ? .on : .off
            voiceMenu.addItem(mi)
        }
    }
    func rebuildQueue() {
        queueMenu.removeAllItems()
        let now = Date().timeIntervalSince1970
        if player != nil {
            let mi = NSMenuItem(title: "▶  \(nowProj)  ·  tocando agora", action: nil, keyEquivalent: "")
            mi.isEnabled = false; queueMenu.addItem(mi)
        }
        if queued.isEmpty {
            let e = NSMenuItem(title: player == nil ? "A fila está vazia" : "Nada esperando", action: nil, keyEquivalent: "")
            e.isEnabled = false; queueMenu.addItem(e)
        } else {
            if player != nil { queueMenu.addItem(.separator()) }
            let hdr = NSMenuItem(title: "Clique para ouvir agora:", action: nil, keyEquivalent: "")
            hdr.isEnabled = false; queueMenu.addItem(hdr)
            for (i, j) in queued.enumerated() {
                let idade = Int(now - j.ts)
                let quando = idade < 60 ? "há \(idade)s" : "há \(idade/60)min"
                let mi = NSMenuItem(title: "\(i+1).  \(j.proj)  ·  \(quando)",
                                    action: #selector(playPicked(_:)), keyEquivalent: "")
                mi.target = self; mi.representedObject = j.job
                queueMenu.addItem(mi)
            }
            queueMenu.addItem(.separator())
            let c = NSMenuItem(title: "Descartar a fila", action: #selector(clearQueue), keyEquivalent: "")
            c.target = self; queueMenu.addItem(c)
        }
    }

    /// Toca o item escolhido. O que estava tocando volta para a fila, no lugar dele.
    @objc func playPicked(_ s: NSMenuItem) {
        guard let jobPath = s.representedObject as? String else { return }
        pularPara(jobPath)
    }
    func pularPara(_ jobPath: String) {
        guard let alvo = scanQueue().first(where: { $0.job == jobPath }) else { return }
        if player != nil, !nowWav.isEmpty {
            let volta = QDIR + "/\(Int(nowTs))-devolvido.job"
            writef(volta, "wav=\(nowWav)\nann=\(nowAnn)\nproj=\(nowProj)\nsess=\nts=\(Int(nowTs))\nprio=0\n")
            player?.stop(); player = nil; nowWav = ""
        }
        rm(alvo.job)
        play(alvo)
        queueSig = ""
    }

    func rebuildProjects() {
        projMenu.removeAllItems()
        let muted = Set(lines(MUTEDF))
        let projs = lines(PROJF).sorted()
        if projs.isEmpty {
            let e = NSMenuItem(title: "Nenhum projeto visto ainda", action: nil, keyEquivalent: "")
            e.isEnabled = false; projMenu.addItem(e); return
        }
        for p in projs {
            let mi = NSMenuItem(title: p, action: #selector(toggleProj(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = p
            mi.state = muted.contains(p) ? .off : .on
            projMenu.addItem(mi)
        }
        projMenu.addItem(.separator())
        let ed = NSMenuItem(title: "Como cada um é falado…", action: #selector(showLabels), keyEquivalent: "")
        ed.target = self; projMenu.addItem(ed)
        let all = NSMenuItem(title: "Ativar todos", action: #selector(unmuteAll), keyEquivalent: ""); all.target = self
        projMenu.addItem(all)
    }
    func rebuildMode() {
        modeMenu.removeAllItems()
        let cur = readf(MODEF) ?? "fila"
        for (k, t) in [("fila", "Entram na fila"), ("ultima", "Só a mais recente fala")] {
            let mi = NSMenuItem(title: t, action: #selector(pickMode(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = k; mi.state = (k == cur) ? .on : .off
            modeMenu.addItem(mi)
        }
    }
    func rebuildPause() {
        pauseMenu.removeAllItems()
        let cur = readf(PAUSEF) ?? "media"
        for (k, t) in [("sem", "Sem pausa"), ("curta", "Curta"), ("media", "Média"), ("longa", "Longa")] {
            let mi = NSMenuItem(title: t, action: #selector(pickPause(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = k; mi.state = (k == cur) ? .on : .off
            pauseMenu.addItem(mi)
        }
        pauseMenu.addItem(.separator())
        let n = NSMenuItem(title: "O nome do projeto é sempre falado em 1x", action: nil, keyEquivalent: "")
        n.isEnabled = false; pauseMenu.addItem(n)
    }
    @objc func pickPause(_ s: NSMenuItem) {
        if let v = s.representedObject as? String { writef(PAUSEF, v); rebuildPause() }
    }

    // MARK: acoes
    @objc func togglePlay() { guard let p = player else { return }
        if p.isPlaying { p.pause() } else { p.play() }; refreshMenu() }
    @objc func stopPlay() {
        geracao += 1                 // cancela qualquer fala agendada dentro de uma pausa
        player?.stop(); encerrarFala()
    }
    @objc func skip() { stopPlay() }
    @objc func clearQueue() {
        for j in scanQueue() { rm(j.job); rm(j.wav); if !j.ann.isEmpty { rm(j.ann) } }
        queued = []; refreshMenu()
    }
    @objc func volChanged() { setVolume(volSlider.floatValue) }
    @objc func spdChanged() { setSpeed(spdSlider.floatValue) }
    @objc func resetSpeed() { setSpeed(1.0) }
    @objc func pickVoice(_ s: NSMenuItem) { if let v = s.representedObject as? String { writef(CURF, v); rebuildVoices() } }
    @objc func pickMode(_ s: NSMenuItem) { if let v = s.representedObject as? String { writef(MODEF, v); rebuildMode() } }
    @objc func toggleProj(_ s: NSMenuItem) {
        guard let p = s.representedObject as? String else { return }
        var muted = lines(MUTEDF)
        if let i = muted.firstIndex(of: p) { muted.remove(at: i) } else { muted.append(p) }
        writef(MUTEDF, muted.joined(separator: "\n")); rebuildProjects()
    }
    @objc func unmuteAll() { writef(MUTEDF, ""); rebuildProjects() }
    @objc func toggleOff() {
        let fm = FileManager.default
        if fm.fileExists(atPath: OFFF) { try? fm.removeItem(atPath: OFFF) }
        else { fm.createFile(atPath: OFFF, contents: nil); stopPlay(); clearQueue() }
        refreshMenu()
    }

    @objc func showHelp() {
        if let w = helpWin { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 680),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = "Como usar a voz"
        w.center(); w.isReleasedWhenClosed = false

        let root = NSView(frame: w.contentView!.bounds)
        root.autoresizingMask = [.width, .height]

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 52, width: 580, height: 628))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 580, height: 628))
        tv.isEditable = false; tv.isSelectable = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 22, height: 20)
        tv.autoresizingMask = [.width]

        let out = NSMutableAttributedString()
        let pTitle = NSMutableParagraphStyle(); pTitle.paragraphSpacingBefore = 18; pTitle.paragraphSpacing = 5
        let pBody = NSMutableParagraphStyle();  pBody.lineSpacing = 3; pBody.paragraphSpacing = 2
        for (h, b) in AJUDA {
            out.append(NSAttributedString(string: h + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor, .paragraphStyle: pTitle]))
            out.append(NSAttributedString(string: b + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 12.5),
                .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: pBody]))
        }
        tv.textStorage?.setAttributedString(out)
        scroll.documentView = tv
        root.addSubview(scroll)

        let bar = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 52))
        bar.autoresizingMask = [.width]
        let ouvir = NSButton(title: "  Ouvir esta explicação", target: self, action: #selector(speakHelp))
        ouvir.image = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: nil)
        ouvir.imagePosition = .imageLeading
        ouvir.bezelStyle = .rounded
        ouvir.frame = NSRect(x: 18, y: 11, width: 190, height: 30)
        bar.addSubview(ouvir)
        let fechar = NSButton(title: "Fechar", target: w, action: #selector(NSWindow.performClose(_:)))
        fechar.bezelStyle = .rounded
        fechar.frame = NSRect(x: 478, y: 11, width: 88, height: 30)
        fechar.autoresizingMask = [.minXMargin]
        bar.addSubview(fechar)
        root.addSubview(bar)

        w.contentView = root
        helpWin = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func toggleAlerts() {
        writef(ALERTSF, (readf(ALERTSF) ?? "1") == "1" ? "0" : "1"); refreshMenu()
    }

    @objc func toggleAnn() {
        let on = (readf(ANNF) ?? "1") == "1"
        writef(ANNF, on ? "0" : "1"); refreshMenu()
    }

    // MARK: janela de texto avulso
    @objc func showTexto() {
        if let w = textoWin { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
                              textoView.window?.makeFirstResponder(textoView); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 540),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = "Ler um texto"; w.center(); w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 460, height: 430)
        let v = NSView(frame: w.contentView!.bounds)
        v.autoresizingMask = [.width, .height]

        let lede = NSTextField(labelWithString: "Cole ou escreva. A leitura fura a fila e começa na hora.")
        lede.font = .systemFont(ofSize: 11); lede.textColor = .secondaryLabelColor
        lede.frame = NSRect(x: 24, y: 508, width: 492, height: 15)
        lede.autoresizingMask = [.width, .minYMargin]
        v.addSubview(lede)

        let scroll = NSScrollView(frame: NSRect(x: 24, y: 240, width: 492, height: 260))
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.autoresizingMask = [.width, .height]
        textoView = NSTextView(frame: NSRect(x: 0, y: 0, width: 492, height: 260))
        textoView.isEditable = true; textoView.isRichText = false
        textoView.font = .systemFont(ofSize: 13)
        textoView.textContainerInset = NSSize(width: 8, height: 8)
        textoView.isAutomaticQuoteSubstitutionEnabled = false
        textoView.delegate = self
        scroll.documentView = textoView
        v.addSubview(scroll)

        textoInfo = NSTextField(labelWithString: "")
        textoInfo.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        textoInfo.textColor = .secondaryLabelColor
        textoInfo.frame = NSRect(x: 24, y: 216, width: 492, height: 15)
        textoInfo.autoresizingMask = [.width, .maxYMargin]
        v.addSubview(textoInfo)

        let semChave = apiKey().isEmpty
        textoResumir = NSButton(checkboxWithTitle: "Resumir antes de ler", target: self,
                                action: #selector(resumirMudou))
        textoResumir.frame = NSRect(x: 24, y: 184, width: 190, height: 20)
        textoResumir.autoresizingMask = [.maxYMargin]
        textoResumir.isEnabled = !semChave
        if semChave { textoResumir.title = "Resumir antes de ler (exige chave da OpenAI)"
                      textoResumir.frame = NSRect(x: 24, y: 184, width: 330, height: 20) }
        v.addSubview(textoResumir)

        // sobrescreve o tamanho só nesta leitura
        textoPct = NSPopUpButton(frame: NSRect(x: 222, y: 181, width: 190, height: 26))
        textoPct.autoresizingMask = [.maxYMargin]
        textoPct.addItems(withTitles: ["Tamanho do ajuste global",
                                       "Reduzir 15%", "Reduzir 25%", "Reduzir 40%",
                                       "Reduzir 50%", "Reduzir 60%", "Reduzir 75%"])
        textoPct.isHidden = semChave
        v.addSubview(textoPct)

        let lblInstr = NSTextField(labelWithString: "Instrução só para esta leitura. Em branco, usa a global.")
        lblInstr.font = .systemFont(ofSize: 11); lblInstr.textColor = .secondaryLabelColor
        lblInstr.frame = NSRect(x: 24, y: 152, width: 492, height: 15)
        lblInstr.autoresizingMask = [.width, .maxYMargin]
        lblInstr.isHidden = semChave
        v.addSubview(lblInstr)

        let instrScroll = NSScrollView(frame: NSRect(x: 24, y: 92, width: 492, height: 52))
        instrScroll.hasVerticalScroller = true; instrScroll.borderType = .bezelBorder
        instrScroll.autoresizingMask = [.width, .maxYMargin]
        textoInstr = NSTextView(frame: NSRect(x: 0, y: 0, width: 492, height: 52))
        textoInstr.isEditable = true; textoInstr.isRichText = false
        textoInstr.font = .systemFont(ofSize: 12)
        textoInstr.textContainerInset = NSSize(width: 6, height: 5)
        textoInstr.isAutomaticQuoteSubstitutionEnabled = false
        instrScroll.documentView = textoInstr
        instrScroll.isHidden = semChave
        v.addSubview(instrScroll)
        textoInstrBox = instrScroll
        textoInstrLabel = lblInstr

        func botao(_ t: String, _ x: CGFloat, _ larg: CGFloat, _ sel: Selector, _ padrao: Bool = false) -> NSButton {
            let b = NSButton(title: t, target: self, action: sel)
            b.bezelStyle = .rounded
            b.frame = NSRect(x: x, y: 24, width: larg, height: 32)
            b.autoresizingMask = padrao ? [.minXMargin, .maxYMargin] : [.maxYMargin]
            if padrao { b.keyEquivalent = "\r" }
            v.addSubview(b); return b
        }
        _ = botao("Colar", 24, 84, #selector(colarTexto))
        _ = botao("Limpar", 116, 84, #selector(limparTexto))
        let bParar = botao("Parar", 330, 84, #selector(stopPlay))
        bParar.autoresizingMask = [.minXMargin, .maxYMargin]
        _ = botao("Ler", 422, 94, #selector(lerTexto), true)

        w.contentView = v; textoWin = w
        atualizaContagem(); resumirMudou()
        w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        w.makeFirstResponder(textoView)
    }

    /// Os campos de tamanho e instrução só fazem sentido com o resumo marcado.
    @objc func resumirMudou() {
        let ligado = textoResumir?.state == .on
        textoPct?.isEnabled = ligado
        textoInstr?.isEditable = ligado
        textoInstrBox?.alphaValue = ligado ? 1.0 : 0.45
        textoInstrLabel?.alphaValue = ligado ? 1.0 : 0.45
    }

    func textDidChange(_ n: Notification) { atualizaContagem() }

    func atualizaContagem() {
        guard let tv = textoView else { return }
        let n = tv.string.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
        if n == 0 { textoInfo.stringValue = "Nada escrito ainda."; return }
        // medido nestas vozes: 2,67 · 2,96 · 2,77 palavras por segundo em 1x
        let seg = Double(n) / 2.8 / Double(speed)
        textoInfo.stringValue = "\(n) palavra\(n == 1 ? "" : "s")  ·  cerca de \(mmss(seg)) de áudio a \(String(format: "%.2fx", speed).replacingOccurrences(of: ".", with: ","))"
    }

    @objc func colarTexto() {
        guard let t = NSPasteboard.general.string(forType: .string) else { return }
        let atual = textoView.string
        textoView.string = atual.isEmpty ? t : atual + "\n" + t
        atualizaContagem()
    }
    @objc func limparTexto() { textoView.string = ""; atualizaContagem() }

    @objc func lerTexto() {
        let t = textoView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { textoInfo.stringValue = "Escreva ou cole algo antes."; return }
        let resumir = textoResumir.state == .on
        textoInfo.stringValue = resumir ? "Resumindo e gerando o áudio…" : "Gerando o áudio…"
        // "Reduzir 40%" -> "40"; a primeira opção deixa valer o ajuste global
        var pct: String? = nil
        if let t = textoPct.titleOfSelectedItem, t.hasPrefix("Reduzir") {
            pct = t.filter { $0.isNumber }
        }
        let instr = textoInstr.string.trimmingCharacters(in: .whitespacesAndNewlines)
        falar(String(t.prefix(20000)), origem: fala("SAY_PASTED", "Texto colado"), resumir: resumir,
              pct: pct, prompt: instr.isEmpty ? nil : instr)
    }

    @objc func readClipboard() {
        guard let t = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            let a = NSAlert(); a.messageText = "Nada copiado"
            a.informativeText = "Copie um texto com Comando C e clique aqui de novo."
            a.addButton(withTitle: "OK"); a.runModal(); return
        }
        falar(String(t.prefix(20000)), origem: fala("SAY_CLIPBOARD", "Texto copiado"), resumir: false)
    }

    /// Roda um dos nossos scripts passando texto pela entrada padrão.
    /// Devolve a saída, ou nil se o script falhar.
    func rodar(_ script: String, _ args: [String], entrada: String,
               env: [String: String]? = nil) -> String? {
        let pr = Process()
        pr.executableURL = URL(fileURLWithPath: script)
        pr.arguments = args
        if let extra = env, !extra.isEmpty {
            var e = ProcessInfo.processInfo.environment
            for (k, v) in extra { e[k] = v }
            pr.environment = e
        }
        let ent = Pipe(), sai = Pipe()
        pr.standardInput = ent; pr.standardOutput = sai; pr.standardError = FileHandle.nullDevice
        do { try pr.run() } catch { return nil }
        ent.fileHandleForWriting.write(entrada.data(using: .utf8) ?? Data())
        ent.fileHandleForWriting.closeFile()
        let d = sai.fileHandleForReading.readDataToEndOfFile()
        pr.waitUntilExit()
        guard pr.terminationStatus == 0 else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// Sintetiza um texto avulso e toca na frente da fila, com anúncio próprio.
    /// `pct` e `prompt`, quando dados, valem só nesta leitura e não tocam nos ajustes globais.
    func falar(_ texto: String, origem: String, resumir: Bool,
               pct: String? = nil, prompt: String? = nil) {
        let carimbo = Int(Date().timeIntervalSince1970)
        let out = RDIR + "/avulso-\(carimbo).wav"
        let outAnn = RDIR + "/avulso-a-\(carimbo).wav"
        let voz = readf(CURF) ?? "cadu"
        let anuncia = (readf(ANNF) ?? "1") == "1"
        var amb: [String: String] = ["VOICE_SUM_FORCE": "1"]
        if let p = pct, !p.isEmpty { amb["VOICE_SUM_PCT"] = p }
        if let i = prompt, !i.isEmpty { amb["VOICE_SUM_PROMPT"] = i }
        if resumir {   // deixa rastro do que a janela realmente mandou
            let d = DateFormatter(); d.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let quanto = prompt == nil ? "global" : "avulsa, \(prompt!.count) caracteres"
            let linha = "\(d.string(from: Date())) janela pediu resumo: corte=\(pct ?? "global") instrucao=\(quanto)\n"
            let cam = HOME + "/.claude/hooks/speak-response.log"
            if let f = FileHandle(forWritingAtPath: cam) {
                f.seekToEndOfFile(); f.write(linha.data(using: .utf8) ?? Data()); try? f.close()
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var corpo = texto
            if resumir, let r = self.rodar(VDIR + "/summarize.sh", [], entrada: texto, env: amb),
               !r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { corpo = r }

            guard self.rodar(VDIR + "/synth.sh", [voz, out], entrada: corpo) != nil else {
                DispatchQueue.main.async { self.textoInfo?.stringValue = "Não consegui gerar o áudio." }
                return
            }
            // o anúncio vai separado, para tocar em 1x e um pouco mais alto
            var ann = ""
            if anuncia, self.rodar(VDIR + "/synth.sh", [voz, outAnn], entrada: origem + ".") != nil,
               FileManager.default.fileExists(atPath: outAnn) { ann = outAnn }

            DispatchQueue.main.async {
                if let tv = self.textoView, self.textoInfo != nil {
                    let n = tv.string.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
                    if n > 0 { self.atualizaContagem() }
                }
                let j = Job(job: "", wav: out, ann: ann, proj: origem,
                            ts: Date().timeIntervalSince1970, prio: true)
                if self.player != nil, !self.nowWav.isEmpty {
                    let volta = QDIR + "/\(Int(self.nowTs))-devolvido.job"
                    writef(volta, "wav=\(self.nowWav)\nann=\(self.nowAnn)\nproj=\(self.nowProj)\nsess=\nts=\(Int(self.nowTs))\nprio=0\n")
                    self.player?.stop(); self.player = nil; self.nowWav = ""
                }
                self.play(j)
            }
        }
    }

    @objc func speakHelp() {
        let out = RDIR + "/ajuda.wav"
        let voz = readf(CURF) ?? "cadu"
        DispatchQueue.global(qos: .userInitiated).async {
            let pr = Process()
            pr.executableURL = URL(fileURLWithPath: VDIR + "/synth.sh")
            pr.arguments = [voz, out]
            let pipe = Pipe(); pr.standardInput = pipe
            pr.standardOutput = FileHandle.nullDevice; pr.standardError = FileHandle.nullDevice
            do { try pr.run() } catch { return }
            pipe.fileHandleForWriting.write(AJUDA_FALADA.data(using: .utf8) ?? Data())
            pipe.fileHandleForWriting.closeFile()
            pr.waitUntilExit()
            guard pr.terminationStatus == 0 else { return }
            DispatchQueue.main.async {
                self.play(Job(job: "", wav: out, ann: "", proj: "ajuda", ts: Date().timeIntervalSince1970, prio: true))
            }
        }
    }

    // MARK: ajustes do resumo por IA
    func conf(_ k: String) -> String {
        for l in lines(CONFF) where l.hasPrefix(k + "=") { return String(l.dropFirst(k.count + 1)) }
        return ""
    }
    func setConf(_ pairs: [String: String]) {
        var d: [String: String] = [:]
        for l in lines(CONFF) {
            let kv = l.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 { d[kv[0]] = kv[1] } else if kv.count == 1 { d[kv[0]] = "" }
        }
        for (k, v) in pairs { d[k] = v }
        writef(CONFF, d.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n") + "\n")
    }
    func apiKey() -> String {
        for l in lines(KEYF) where l.hasPrefix("OPENAI_API_KEY=") {
            return String(l.dropFirst("OPENAI_API_KEY=".count))
        }
        return ""
    }

    // MARK: como cada projeto é falado
    func legenda(_ proj: String) -> String {
        for l in lines(LABELSF) where l.hasPrefix(proj + "|") {
            return String(l.dropFirst(proj.count + 1))
        }
        return ""
    }
    /// O nome da pasta com separadores virando espaço: o padrão quando não há legenda.
    func nomeLimpo(_ proj: String) -> String {
        let t = proj.map { "_.-".contains($0) ? " " : $0 }
        return String(t).split(separator: " ").joined(separator: " ")
    }

    @objc func showLabels() {
        if let w = labelsWin { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let projs = lines(PROJF).sorted()
        let alturaLista = min(CGFloat(max(projs.count, 1)) * 56 + 8, 336)
        let altura = alturaLista + 148

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: altura),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Como cada projeto é falado"; w.center(); w.isReleasedWhenClosed = false
        let v = NSView(frame: w.contentView!.bounds)

        let lede = NSTextField(wrappingLabelWithString:
            "O texto abaixo é falado antes de cada resposta, em velocidade normal. Deixe em branco para usar o nome da pasta.")
        lede.font = .systemFont(ofSize: 11); lede.textColor = .secondaryLabelColor
        lede.frame = NSRect(x: 24, y: altura - 52, width: 492, height: 32)
        v.addSubview(lede)

        let scroll = NSScrollView(frame: NSRect(x: 24, y: 76, width: 492, height: alturaLista))
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        scroll.drawsBackground = false
        let dentro = NSView(frame: NSRect(x: 0, y: 0, width: 476,
                                          height: max(alturaLista, CGFloat(projs.count) * 56 + 8)))
        labelFields = []
        if projs.isEmpty {
            let e = NSTextField(labelWithString: "Nenhum projeto falou ainda. Eles aparecem aqui sozinhos.")
            e.font = .systemFont(ofSize: 12); e.textColor = .secondaryLabelColor
            e.frame = NSRect(x: 16, y: alturaLista / 2 - 10, width: 440, height: 17)
            dentro.addSubview(e)
        }
        for (i, p) in projs.enumerated() {
            let topo = dentro.frame.height - CGFloat(i + 1) * 56
            let nome = NSTextField(labelWithString: p)
            nome.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
            nome.textColor = .secondaryLabelColor
            nome.lineBreakMode = .byTruncatingMiddle
            nome.frame = NSRect(x: 14, y: topo + 34, width: 448, height: 14)
            dentro.addSubview(nome)

            let campo = NSTextField(frame: NSRect(x: 14, y: topo + 6, width: 400, height: 24))
            campo.stringValue = legenda(p)
            campo.placeholderString = nomeLimpo(p)
            campo.font = .systemFont(ofSize: 12.5)
            dentro.addSubview(campo)
            labelFields.append((p, campo))

            let ouvir = NSButton(title: "", target: self, action: #selector(ouvirLegenda(_:)))
            ouvir.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "ouvir")
            ouvir.bezelStyle = .rounded; ouvir.isBordered = false
            ouvir.tag = i
            ouvir.toolTip = "Ouvir como vai soar"
            ouvir.frame = NSRect(x: 424, y: topo + 5, width: 30, height: 26)
            dentro.addSubview(ouvir)
        }
        scroll.documentView = dentro
        v.addSubview(scroll)

        let bOk = NSButton(title: "Salvar", target: self, action: #selector(salvarLegendas))
        bOk.bezelStyle = .rounded; bOk.keyEquivalent = "\r"
        bOk.frame = NSRect(x: 416, y: 24, width: 100, height: 32)
        v.addSubview(bOk)
        let bLimpar = NSButton(title: "Limpar todas", target: self, action: #selector(limparLegendas))
        bLimpar.bezelStyle = .rounded
        bLimpar.frame = NSRect(x: 24, y: 24, width: 130, height: 32)
        v.addSubview(bLimpar)

        w.contentView = v; labelsWin = w
        w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    @objc func ouvirLegenda(_ b: NSButton) {
        guard b.tag < labelFields.count else { return }
        let (proj, campo) = labelFields[b.tag]
        let t = campo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let fala = t.isEmpty ? nomeLimpo(proj) : t
        let out = RDIR + "/legenda.wav"
        let voz = readf(CURF) ?? "cadu"
        DispatchQueue.global(qos: .userInitiated).async {
            guard self.rodar(VDIR + "/synth.sh", [voz, out], entrada: fala + ".") != nil else { return }
            DispatchQueue.main.async {
                self.play(Job(job: "", wav: out, ann: "", proj: proj,
                              ts: Date().timeIntervalSince1970, prio: true))
            }
        }
    }

    @objc func salvarLegendas() {
        var linhas: [String] = []
        for (p, campo) in labelFields {
            let t = campo.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { linhas.append("\(p)|\(t)") }
        }
        writef(LABELSF, linhas.joined(separator: "\n"))
        labelsWin?.performClose(nil)
    }
    @objc func limparLegendas() {
        for (_, campo) in labelFields { campo.stringValue = "" }
    }

    @objc func showSettings() {
        if let w = cfgWin { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 646),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Resumo por IA"; w.center(); w.isReleasedWhenClosed = false
        let v = NSView(frame: w.contentView!.bounds)

        func label(_ t: String, _ y: CGFloat, _ bold: Bool = false, _ small: Bool = false) -> NSTextField {
            let l = NSTextField(labelWithString: t)
            l.font = bold ? .systemFont(ofSize: 12, weight: .semibold)
                          : .systemFont(ofSize: small ? 11 : 12.5)
            if small { l.textColor = .secondaryLabelColor }
            l.frame = NSRect(x: 24, y: y, width: 472, height: small ? 15 : 17)
            v.addSubview(l); return l
        }

        _ = label("Antes de falar, o texto passa por uma IA que o encurta.", 610, false, true)

        _ = label("Chave da OpenAI", 580, true)
        keyField = NSSecureTextField(frame: NSRect(x: 24, y: 552, width: 360, height: 24))
        keyField.placeholderString = "sk-..."
        keyField.stringValue = apiKey()
        v.addSubview(keyField)
        let bSave = NSButton(title: "Guardar", target: self, action: #selector(saveKey))
        bSave.bezelStyle = .rounded; bSave.frame = NSRect(x: 392, y: 550, width: 104, height: 28)
        v.addSubview(bSave)
        keyStatus = label(apiKey().isEmpty ? "Nenhuma chave guardada." : "Chave guardada no seu Mac, com leitura restrita a você.", 530, false, true)

        _ = label("Modelo", 496, true)
        modelPop = NSPopUpButton(frame: NSRect(x: 24, y: 466, width: 360, height: 26))
        v.addSubview(modelPop)
        let bMod = NSButton(title: "Buscar", target: self, action: #selector(refreshModels))
        bMod.bezelStyle = .rounded; bMod.frame = NSRect(x: 392, y: 465, width: 104, height: 28)
        v.addSubview(bMod)
        modelStatus = label("Clique em Buscar para listar os modelos da sua conta.", 444, false, true)
        loadModelsIntoPopup(nil)

        _ = label("Tamanho do resumo", 410, true)
        modeSeg = NSSegmentedControl(labels: ["Reduzir em", "Número de palavras"],
                                     trackingMode: .selectOne, target: self, action: #selector(modeChanged))
        modeSeg.frame = NSRect(x: 24, y: 380, width: 300, height: 26)
        modeSeg.selectedSegment = conf("mode") == "words" ? 1 : 0
        v.addSubview(modeSeg)

        pctPop = NSPopUpButton(frame: NSRect(x: 336, y: 380, width: 100, height: 26))
        pctPop.addItems(withTitles: ["15%", "25%", "40%", "50%", "60%", "75%"])
        pctPop.selectItem(withTitle: (conf("percent").isEmpty ? "25" : conf("percent")) + "%")
        v.addSubview(pctPop)

        wordsField = NSTextField(frame: NSRect(x: 336, y: 381, width: 70, height: 24))
        wordsField.stringValue = conf("words").isEmpty ? "60" : conf("words")
        wordsField.alignment = .right
        v.addSubview(wordsField)
        wordsUnit = NSTextField(labelWithString: "palavras")
        wordsUnit.font = .systemFont(ofSize: 12); wordsUnit.textColor = .secondaryLabelColor
        wordsUnit.frame = NSRect(x: 412, y: 384, width: 84, height: 17)
        v.addSubview(wordsUnit)
        modeChanged()

        _ = label("Não resumir textos curtos", 346, true)
        minField = NSTextField(frame: NSRect(x: 24, y: 318, width: 70, height: 24))
        minField.stringValue = conf("min_words").isEmpty ? "60" : conf("min_words")
        minField.alignment = .right
        v.addSubview(minField)
        _ = { let l = NSTextField(labelWithString: "palavras ou menos passam inteiras, sem custo de API.")
              l.font = .systemFont(ofSize: 12); l.textColor = .secondaryLabelColor
              l.frame = NSRect(x: 100, y: 321, width: 396, height: 17); v.addSubview(l) }()

        // instruções livres: estilo, tratamento de símbolos, o que preservar, o que cortar
        _ = label("Instruções para a IA", 284, true)
        let promptScroll = NSScrollView(frame: NSRect(x: 24, y: 176, width: 472, height: 102))
        promptScroll.hasVerticalScroller = true
        promptScroll.borderType = .bezelBorder
        promptScroll.drawsBackground = true
        promptView = NSTextView(frame: NSRect(x: 0, y: 0, width: 472, height: 102))
        promptView.isEditable = true; promptView.isRichText = false
        promptView.font = .systemFont(ofSize: 12)
        promptView.textContainerInset = NSSize(width: 6, height: 6)
        promptView.isAutomaticQuoteSubstitutionEnabled = false
        promptView.string = readf(PROMPTF) ?? ""
        promptScroll.documentView = promptView
        v.addSubview(promptScroll)
        _ = label("Opcional. Vale mais que as regras internas, então serve para mudar o tom, tratar símbolos ou dizer o que nunca cortar.", 156, false, true)

        enableBox = NSButton(checkboxWithTitle: "Resumir antes de falar", target: nil, action: nil)
        enableBox.state = conf("enabled") == "1" ? .on : .off
        enableBox.frame = NSRect(x: 24, y: 126, width: 300, height: 20)
        v.addSubview(enableBox)

        let bTest = NSButton(title: "Testar agora", target: self, action: #selector(testSummary))
        bTest.bezelStyle = .rounded; bTest.frame = NSRect(x: 24, y: 16, width: 130, height: 30)
        v.addSubview(bTest)
        let bEx = NSButton(title: "Exemplos", target: self, action: #selector(exemplosPrompt))
        bEx.bezelStyle = .rounded; bEx.frame = NSRect(x: 162, y: 16, width: 100, height: 30)
        v.addSubview(bEx)
        let bOk = NSButton(title: "Salvar", target: self, action: #selector(saveSettings))
        bOk.bezelStyle = .rounded; bOk.keyEquivalent = "\r"
        bOk.frame = NSRect(x: 396, y: 16, width: 100, height: 30)
        v.addSubview(bOk)

        testOut = NSTextField(wrappingLabelWithString: "")
        testOut.font = .systemFont(ofSize: 11.5); testOut.textColor = .secondaryLabelColor
        testOut.frame = NSRect(x: 24, y: 54, width: 472, height: 62)
        v.addSubview(testOut)

        w.contentView = v; cfgWin = w
        w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    @objc func modeChanged() {
        let porPct = modeSeg.selectedSegment == 0
        pctPop.isHidden = !porPct
        wordsField.isHidden = porPct
        wordsUnit.isHidden = porPct
    }

    @objc func saveKey() {
        let k = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        writef(KEYF, k.isEmpty ? "" : "OPENAI_API_KEY=\(k)\n")
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: KEYF)
        keyStatus.stringValue = k.isEmpty ? "Chave removida."
            : "Chave guardada no seu Mac, com leitura restrita a você."
    }

    @objc func saveSettings() {
        saveKey()
        let pct = pctPop.titleOfSelectedItem?.replacingOccurrences(of: "%", with: "") ?? "25"
        setConf([
            "enabled": enableBox.state == .on ? "1" : "0",
            "mode": modeSeg.selectedSegment == 1 ? "words" : "percent",
            "percent": pct,
            "words": wordsField.stringValue.isEmpty ? "60" : wordsField.stringValue,
            "min_words": minField.stringValue.isEmpty ? "60" : minField.stringValue,
            "model": modelPop.titleOfSelectedItem ?? "",
        ])
        writef(PROMPTF, promptView.string.trimmingCharacters(in: .whitespacesAndNewlines))
        cfgWin?.performClose(nil)
    }

    func loadModelsIntoPopup(_ list: [String]?) {
        let atual = conf("model")
        var itens = list ?? lines(VDIR + "/models.txt")
        if itens.isEmpty { itens = ["gpt-4o-mini", "gpt-4o"] }
        if !atual.isEmpty && !itens.contains(atual) { itens.insert(atual, at: 0) }
        modelPop.removeAllItems(); modelPop.addItems(withTitles: itens)
        if !atual.isEmpty { modelPop.selectItem(withTitle: atual) }
    }

    @objc func refreshModels() {
        let k = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { modelStatus.stringValue = "Cole a chave primeiro."; return }
        modelStatus.stringValue = "Buscando na sua conta…"
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        req.setValue("Bearer \(k)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 25
        URLSession.shared.dataTask(with: req) { data, _, err in
            var nomes: [String] = []
            var msg = "Não consegui buscar a lista."
            if let d = data,
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                if let arr = o["data"] as? [[String: Any]] {
                    nomes = arr.compactMap { $0["id"] as? String }
                        .filter { $0.hasPrefix("gpt") || $0.hasPrefix("o1") || $0.hasPrefix("o3")
                                  || $0.hasPrefix("o4") || $0.hasPrefix("chatgpt") }
                        .filter { !$0.contains("audio") && !$0.contains("realtime")
                                  && !$0.contains("image") && !$0.contains("tts")
                                  && !$0.contains("transcribe") && !$0.contains("embedding") }
                        .sorted()
                    msg = nomes.isEmpty ? "A conta não listou modelos de texto." : "\(nomes.count) modelos disponíveis."
                } else if let e = o["error"] as? [String: Any], let m = e["message"] as? String {
                    msg = String(m.prefix(90))
                }
            } else if let e = err { msg = String(e.localizedDescription.prefix(90)) }
            DispatchQueue.main.async {
                self.modelStatus.stringValue = msg
                if !nomes.isEmpty {
                    writef(VDIR + "/models.txt", nomes.joined(separator: "\n"))
                    self.loadModelsIntoPopup(nomes)
                }
            }
        }.resume()
    }

    @objc func testSummary() {
        saveSettings2()
        testOut.stringValue = "Resumindo um texto de exemplo…"
        let exemplo = """
        Corrigi o bug do hook de voz que deixava arquivos temporários para trás a cada resposta falada, \
        apaguei os vinte e dois arquivos órfãos que já existiam no sistema e troquei o comando que \
        interrompia a reprodução, porque o antigo derrubava qualquer áudio da máquina em vez de apenas o nosso. \
        Também instalei o motor Kokoro em paralelo ao Piper, o que exigiu um Python 3.12 separado, e liguei \
        as três vozes brasileiras novas ao menu. Os testes de fila, de silenciamento por projeto e de \
        prioridade do texto selecionado passaram todos. Falta apenas ativar o ditado nos Ajustes do Sistema.
        """
        DispatchQueue.global(qos: .userInitiated).async {
            let pr = Process()
            pr.executableURL = URL(fileURLWithPath: VDIR + "/summarize.sh")
            let inp = Pipe(), outp = Pipe()
            pr.standardInput = inp; pr.standardOutput = outp; pr.standardError = FileHandle.nullDevice
            do { try pr.run() } catch {
                DispatchQueue.main.async { self.testOut.stringValue = "Não consegui executar o resumidor." }; return
            }
            inp.fileHandleForWriting.write(exemplo.data(using: .utf8) ?? Data())
            inp.fileHandleForWriting.closeFile()
            let d = outp.fileHandleForReading.readDataToEndOfFile()
            pr.waitUntilExit()
            let r = String(data: d, encoding: .utf8) ?? ""
            let orig = exemplo.split(separator: " ").count
            let novo = r.split(separator: " ").count
            DispatchQueue.main.async {
                if r.trimmingCharacters(in: .whitespacesAndNewlines) == exemplo.trimmingCharacters(in: .whitespacesAndNewlines) || r.isEmpty {
                    if let motivo = readf(RDIR + "/summary-error.txt") {
                        self.testOut.stringValue = "A API recusou: \(motivo)\nEscolha outro modelo na lista acima. O texto original seria falado normalmente."
                    } else if self.apiKey().isEmpty {
                        self.testOut.stringValue = "Nenhuma chave guardada. Cole a chave e clique em Guardar."
                    } else if self.enableBox.state != .on {
                        self.testOut.stringValue = "Marque Resumir antes de falar para o resumo entrar em ação."
                    } else {
                        self.testOut.stringValue = "O texto de exemplo é curto demais para o mínimo configurado, então passou inteiro."
                    }
                } else {
                    self.testOut.stringValue = "\(orig) palavras viraram \(novo).\n\(r.prefix(240))"
                }
            }
        }
    }
    /// Igual a saveSettings, mas sem fechar a janela (usado pelo teste).
    func saveSettings2() {
        saveKey()
        let pct = pctPop.titleOfSelectedItem?.replacingOccurrences(of: "%", with: "") ?? "25"
        setConf([
            "enabled": enableBox.state == .on ? "1" : "0",
            "mode": modeSeg.selectedSegment == 1 ? "words" : "percent",
            "percent": pct,
            "words": wordsField.stringValue.isEmpty ? "60" : wordsField.stringValue,
            "min_words": minField.stringValue.isEmpty ? "60" : minField.stringValue,
            "model": modelPop.titleOfSelectedItem ?? "",
        ])
        writef(PROMPTF, promptView.string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Menu de instruções prontas, para não partir da folha em branco.
    @objc func exemplosPrompt(_ sender: NSButton) {
        let sugestoes = [
            "Comece dizendo se deu certo ou não, antes de qualquer detalhe.",
            "Fale em tom informal, como um colega explicando de cabeça.",
            "Nunca corte números, prazos, nomes de pessoas ou valores.",
            "Não leia caminhos de arquivo nem nomes de variáveis: diga só o que mudou.",
            "Leia siglas letra por letra, separadas por espaço.",
            "Troque símbolos e emoji por palavras, ou omita-os.",
            "Se houver uma pergunta pendente para mim, termine por ela.",
            "Não repita o que eu pedi. Diga apenas o resultado.",
        ]
        let m = NSMenu()
        for s in sugestoes {
            let mi = NSMenuItem(title: s, action: #selector(inserirExemplo(_:)), keyEquivalent: "")
            mi.target = self; mi.representedObject = s
            m.addItem(mi)
        }
        m.addItem(.separator())
        let lim = NSMenuItem(title: "Limpar o campo", action: #selector(limparPrompt), keyEquivalent: "")
        lim.target = self; m.addItem(lim)
        m.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }
    @objc func inserirExemplo(_ s: NSMenuItem) {
        guard let t = s.representedObject as? String else { return }
        let atual = promptView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        promptView.string = atual.isEmpty ? t : atual + "\n" + t
    }
    @objc func limparPrompt() { promptView.string = "" }

    /// Solta um processo que continua vivo depois que este morrer.
    func solto(_ caminho: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: caminho)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }

    /// Reinicia o app. A fila sobrevive, porque ela são arquivos em disco;
    /// só a fala que estava tocando se perde.
    @objc func reiniciar() {
        player?.stop(); player = nil
        if !nowWav.isEmpty { rm(nowWav) }
        if !nowAnn.isEmpty { rm(nowAnn) }
        rm(BARPID)
        let agente = HOME + "/Library/LaunchAgents/com.claude.voicebar.plist"
        if FileManager.default.fileExists(atPath: agente) {
            // o launchd derruba e sobe de novo sozinho
            solto("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/com.claude.voicebar"])
            // se em dois segundos ele não nos matou, saímos por conta própria
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.terminate(nil) }
        } else {
            solto("/bin/sh", ["-c", "sleep 1; exec '\(VDIR)/voicebar'"])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
        }
    }

    @objc func quit() { rm(BARPID); NSApp.terminate(nil) }

    func setVolume(_ v: Float) { volume = max(0, min(1, v)); player?.volume = volume
        writef(VOLF, String(format: "%.2f", volume)); refreshMenu() }
    func setSpeed(_ v: Float) { speed = max(0.6, min(1.8, v))
        if abs(speed - 1.0) < 0.04 { speed = 1.0 }
        player?.rate = speed; writef(SPDF, String(format: "%.2f", speed)); refreshMenu() }

    // MARK: fila
    func scanQueue() -> [Job] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(atPath: QDIR)) ?? []
        var out: [Job] = []
        for f in files where f.hasSuffix(".job") {
            let path = QDIR + "/" + f
            guard let txt = readf(path) else { continue }
            var d: [String: String] = [:]
            for l in txt.split(separator: "\n") {
                let kv = l.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 { d[kv[0]] = kv[1] }
            }
            guard let w = d["wav"], let ts = Double(d["ts"] ?? "") else { continue }
            out.append(Job(job: path, wav: w, ann: d["ann"] ?? "", proj: d["proj"] ?? "?", ts: ts, prio: (d["prio"] ?? "0") == "1"))
        }
        return out.sorted { $0.ts < $1.ts }
    }

    func tick() {
        if let cmd = readf(CMDF) {
            rm(CMDF)
            let p = cmd.split(separator: " ").map(String.init)
            switch p.first ?? "" {
            case "pause": player?.pause()
            case "resume": player?.play()
            case "toggle": togglePlay()
            case "stop": stopPlay()
            case "skip": skip()
            case "clear": clearQueue()
            case "quit":  quit()
            case "restart": reiniciar()
            case "pick":
                if p.count > 1, let n = Int(p[1]), n >= 1, n <= queued.count {
                    pularPara(queued[n-1].job)
                }
            case "vol": if p.count > 1, let v = Float(p[1]) { setVolume(v) }
            case "speed": if p.count > 1, let v = Float(p[1]) { setSpeed(v) }
            default: break
            }
        }

        var jobs = scanQueue()
        let now = Date().timeIntervalSince1970
        let muted = Set(lines(MUTEDF))
        // descarta o que envelheceu ou foi silenciado depois de entrar
        for j in jobs where now - j.ts > MAX_AGE || muted.contains(j.proj) { rm(j.job); rm(j.wav) }
        jobs = jobs.filter { now - $0.ts <= MAX_AGE && !muted.contains($0.proj) }

        let mode = readf(MODEF) ?? "fila"
        if mode == "ultima", jobs.count > 1 {
            for j in jobs.dropLast() { rm(j.job); rm(j.wav) }
            jobs = [jobs.last!]
        }
        if mode == "ultima", let last = jobs.last, player != nil, last.ts > 0 {
            player?.stop(); if !nowWav.isEmpty { rm(nowWav); nowWav = "" }; player = nil
        }
        if jobs.count > MAX_QUEUE {
            for j in jobs.prefix(jobs.count - MAX_QUEUE) { rm(j.job); rm(j.wav) }
            jobs = Array(jobs.suffix(MAX_QUEUE))
        }
        queued = jobs

        // texto selecionado é pedido explícito: fura a fila
        if let urgente = jobs.first(where: { $0.prio }) {
            if player != nil { pularPara(urgente.job) } else { rm(urgente.job); play(urgente) }
            queued = scanQueue().filter { now - $0.ts <= MAX_AGE && !muted.contains($0.proj) }
            refreshMenu(); return
        }
        // fase != .parado significa que estamos no meio de um anúncio ou de uma pausa;
        // não puxe o próximo da fila enquanto isso.
        if player == nil, fase == .parado, let next = jobs.first {
            rm(next.job)
            queued = Array(jobs.dropFirst())
            play(next)
        }
        refreshMenu()
    }

    func pausas() -> (mesmo: Double, trocou: Double, apos: Double) {
        PAUSAS[readf(PAUSEF) ?? "media"] ?? PAUSAS["media"]!
    }

    /// Toca um job em duas fases: primeiro o nome do projeto em velocidade normal,
    /// depois o conteúdo na velocidade escolhida, com pausas entre as partes.
    func play(_ j: Job) {
        player?.stop()
        geracao += 1
        let gen = geracao
        let p = pausas()
        let trocou = !ultimoProj.isEmpty && ultimoProj != j.proj
        let antes = trocou ? p.trocou : p.mesmo

        nowProj = j.proj; nowWav = j.wav; nowAnn = j.ann; nowTs = j.ts
        ultimoProj = j.proj

        let temAnuncio = !j.ann.isEmpty && FileManager.default.fileExists(atPath: j.ann)
        fase = temAnuncio ? .anuncio : .conteudo
        refreshMenu()

        DispatchQueue.main.asyncAfter(deadline: .now() + antes) {
            guard gen == self.geracao else { return }
            if temAnuncio {
                // o nome sempre em 1x, e um pouco acima no volume, para destacar
                self.tocarArquivo(j.ann, rate: 1.0, vol: min(1.0, self.volume * 1.15))
            } else {
                self.tocarArquivo(j.wav, rate: self.speed, vol: self.volume)
            }
        }
    }

    func tocarArquivo(_ path: String, rate: Float, vol: Float) {
        guard let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) else {
            rm(path); encerrarFala(); return
        }
        p.delegate = self; p.enableRate = true; p.volume = vol
        p.prepareToPlay(); p.rate = rate; p.play()
        player = p
        refreshMenu()
    }

    func encerrarFala() {
        player = nil; fase = .parado
        if !nowWav.isEmpty { rm(nowWav); nowWav = "" }
        if !nowAnn.isEmpty { rm(nowAnn); nowAnn = "" }
        nowProj = ""
        refreshMenu()
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully f: Bool) {
        if fase == .anuncio {
            // terminou o nome: pausa curta e entra o conteúdo, na velocidade do usuário
            let gen = geracao
            let conteudo = nowWav
            fase = .conteudo
            player = nil
            if !nowAnn.isEmpty { rm(nowAnn); nowAnn = "" }
            refreshMenu()
            DispatchQueue.main.asyncAfter(deadline: .now() + pausas().apos) {
                guard gen == self.geracao else { return }
                self.tocarArquivo(conteudo, rate: self.speed, vol: self.volume)
            }
            return
        }
        encerrarFala()
    }

    func porTitulo(_ mi: NSMenuItem?, _ t: String) {
        if mi?.title != t { mi?.title = t }
    }

    func refreshMenu() {
        let isOff = FileManager.default.fileExists(atPath: OFFF)
        offItem?.state = isOff ? .off : .on
        annItem?.state = (readf(ANNF) ?? "1") == "1" ? .on : .off
        alertItem?.state = (readf(ALERTSF) ?? "1") == "1" ? .on : .off
        volLabel?.stringValue = "\(Int(volume*100))%"; volSlider?.floatValue = volume
        spdLabel?.stringValue = String(format: "%.2fx", speed).replacingOccurrences(of: ".", with: ",")
        spdSlider?.floatValue = speed

        if queued.isEmpty { queueItem.title = ""; queueItem.isHidden = true }
        else {
            queueItem.isHidden = false
            let names = queued.map { $0.proj }.joined(separator: ", ")
            queueItem.title = "Na fila: \(queued.count) · \(names)"
        }
        clearItem.isEnabled = !queued.isEmpty
        skipItem.isEnabled = player != nil || fase != .parado

        let who = nowProj.isEmpty ? "" : " · \(nowProj)"
        if let p = player {
            // o anúncio toca sempre em 1x, então o tempo restante dele não escala
            let taxa = fase == .anuncio ? 1.0 : Double(speed)
            let restante = (p.duration - p.currentTime) / taxa
            if p.isPlaying {
                icone("speaker.wave.2.fill")
                stateItem.title = fase == .anuncio
                    ? "Anunciando\(who)"
                    : "Lendo\(who)  faltam \(mmss(restante))"
                ppItem.title = "Pausar"
            } else {
                icone("pause.fill")
                stateItem.title = "Pausado\(who)  faltam \(mmss(restante))"; ppItem.title = "Retomar"
            }
            ppItem.isEnabled = true; stopItem.isEnabled = true
        } else if fase != .parado {
            // silêncio proposital entre as partes
            icone("speaker.wave.1")
            stateItem.title = "Pausa\(who)"
            ppItem.title = "Pausar"; ppItem.isEnabled = false; stopItem.isEnabled = true
        } else {
            icone(isOff ? "speaker.slash.fill" : "speaker.wave.2")
            stateItem.title = isOff ? "Leitura desligada" : "Parado"
            ppItem.title = "Pausar"; ppItem.isEnabled = false; stopItem.isEnabled = false
        }
        let sig = (readf(PROJF) ?? "") + "|" + (readf(MUTEDF) ?? "")
        if sig != projSig { projSig = sig; rebuildProjects() }
        let qsig = queued.map { $0.job }.joined(separator: ",") + "|" + (player != nil ? nowProj : "-")
        if qsig != queueSig { queueSig = qsig; rebuildQueue() }
    }
}

let app = NSApplication.shared
let c = Controller()
app.delegate = c
app.run()
