# VoiceBar

Reads Claude Code answers out loud on your Mac, plus any text you select.
Speech is generated on your own machine: no internet, no account, no usage cap.

A speaker icon appears in the menu bar with pause, volume, speed, a queue and
seven Brazilian Portuguese voices.

**This is a Brazilian Portuguese project.** The interface, the help and the
voices are all pt-BR. The speech layer is not hardcoded, so another language is
a matter of adding two small files and voices, but nobody has done it yet. See
`CONTRIBUTING.md`.

## What makes it different

Most read-aloud scripts break the moment you run more than one agent. This one
was built around that problem:

- **A real queue.** When several Claude Code sessions finish at once, the
  answers line up instead of cutting each other off.
- **Each answer says where it came from**, at normal speed and slightly louder,
  so you know who is talking without looking at the screen.
- **A longer silence when the project changes**, so your ear registers the
  switch.
- **Per-project muting**, applied before synthesis, so a silenced project costs
  no processing at all.
- **You can browse the queue** and jump to any waiting item; the one playing
  goes back in line instead of being lost.

## Requirements

macOS, tested on 26. Apple Silicon and Intel. The installer checks everything
and stops with the exact command if something is missing.

| Item | If missing |
|---|---|
| Xcode command line tools | `xcode-select --install` |
| Homebrew | https://brew.sh |
| jq | `brew install jq` |
| Python 3.12 | installed automatically |

Python 3.12 is required by one of the speech engines, which does not yet run on
newer versions. It is installed alongside your own Python, never replacing it.

Claude Code itself is optional. Without it, reading selected text still works.

## Install

```bash
./install.sh
```

Takes a few minutes, mostly downloading voices. Safe to run again: it only
redoes what is missing and keeps your settings.

## Voices

Seven, all Brazilian Portuguese, from two engines.

| Voice | Engine | Character |
|---|---|---|
| Dora, Alex, Santa | Kokoro | more natural, about 2 s to generate |
| Cadu, Faber, Jeff, Edresson | Piper | faster, about 1 s |

## Optional AI summary

The text can pass through an AI that shortens it before speaking. This needs an
OpenAI key that you provide. You choose the model, the target size by percentage
or word count, and free-form instructions about tone and what must never be cut.

If the key fails or the network drops, the original text is spoken normally. The
summary never leaves you without audio.

Off by default. Without a key, everything else works offline.

## Before you install

Read `SECURITY.md`. The short version: this installs a hook that reads every
Claude Code answer, which is how it works at all, and the optional summary sends
text to OpenAI.

## Documentation

| File | Contents |
|---|---|
| `LEIA-ME.md` | full guide, in Portuguese |
| `SECURITY.md` | what it touches and what leaves the machine |
| `CREDITS.md` | third-party licenses and two upstream bugs worked around |
| `CONTRIBUTING.md` | how to help, including adding a language |
| `PARA-O-CLAUDE-CODE.md` | instructions for an AI agent to install it for you |

There is also a 20-section guide inside the app, under **Como usar…**, with a
button that reads the explanation aloud.

## License

GPL-3.0-or-later. This is not a free choice: the project depends on `piper-tts`,
which is GPL. See `CREDITS.md` for the reasoning and the full dependency list.
