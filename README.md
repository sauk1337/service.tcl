# service.tcl

A channel service and protection script for [Eggdrop](https://www.eggheads.org/), built for **QuakeNet**.

All credit for the original script goes to **r0t3n** (aka Eagle, #r0t3n), who created it.
Version 6.0.0 continues his work: it has been cleaned up, fixed, split into modules, had its security problems removed, and gained QuakeNet-focused anti-takeover features.

🚀 **[Installation guide](docs/INSTALL.md)** ([español](docs/INSTALL.es.md)) · 📖 **[Manual](docs/MANUAL.md)** · 📝 **[Changelog](CHANGELOG.md)**

## Features

**Protection**
- **Takeover protection**: detects mass deops, kicks or bans, then kick-bans the attacker and asks Q to `RECOVER` the channel. It also has Q `TEMPBAN` the attacker, removes the attacker's Q chanlev, locks the channel (`+im`) and re-ops trusted users. Reactions skip the output queue.
- **Channel protection**: reverts mode, kick and topic changes by users without access. If the bot is deopped, kicked or banned, it asks Q for help. *Hard* mode also protects against channel ops.
- **Linked bots** protect each other: op, invite, unban, key and limit requests, plus shared takeover alerts.
- Spamscan, anti-flood, clonescan, flyby, known-only, bitchmode, badwords, anti-advertise, bad channels and bans by Q account.

**QuakeNet / Q**
- **CHALLENGEAUTH** login (HMAC-SHA-256): the password never leaves the bot. The bot can wait for the login before joining channels, so its IP is never shown.
- Q commands from the channel: `qban`, `qpermban`, `qunban`, `qbanlist`, `qrecover`, `qdeopall`, `qclearchan`, `qchanflags`, `qchanmode`, `qautolimit`, `chanlev`, and more. Q's answers are forwarded to you.
- Users can be recognised by their **Q account**, not only by hostmask.

**Everything else**
- User management with per-channel levels, local and global bans with expiry, and a per-user command trigger.
- Saved ops that survive restarts, auto-op/voice/limit, welcome messages, timed messages, a topic system and VIP.
- `help <command>` inside IRC.
- **Updates from GitHub releases**: SHA-256 verified, with backup and rollback. Updates are only installed when an owner asks.

## Requirements

- Eggdrop **1.9.x** or newer (Tcl 8.5+; 8.6 recommended)
- On QuakeNet: a Q account for the bot, with **+m** on your channels for full takeover protection
- Optional: `tcl-tls` (for the updater), `tcllib` (faster SHA-256)

The full list, and how to install everything from scratch (Eggdrop included), is in the **[installation guide](docs/INSTALL.md)**.

## Quick start

```sh
cd ~/eggdrop/scripts
git clone https://github.com/sauk1337/service.tcl.git service
cd service
cp service.conf.example service.conf
chmod 600 service.conf
# edit service.conf: channels and the qauth section
```

Add to `eggdrop.conf` and rehash:

```tcl
source scripts/service/service.tcl
```

Then, on IRC: `$chanflags +p` (enable protection), `$help` (your commands), `$takeover` (protection settings).
The [manual](docs/MANUAL.md) explains every step, including the Q setup and linking bots.

> **Upgrading from r0t3n's v40.x:**
> - Channel settings (`service_*`) and user data are unchanged, so your chanfile and userfile keep working.
> - Copy your values into the new `service.conf` and change the `source` line to `scripts/service/service.tcl`.
> - The `update` array of the old configuration has a new meaning (see `service.conf.example`). `fullpath` is no longer used.

## Commands

Commands use your personal trigger (default `$`, change it with `$mytrigger !`) or the bot's nickname (`BotNick op nick`).
`$help` lists the commands you can use, and `$help <command>` shows the details.

| Category | Commands |
|---|---|
| Users | `adduser` `access` `deluser` `whois` `whoami` `userlist` `mytrigger` `account` |
| Protection | `protect` `takeover` `lockdown` `enforcemodes` `bitchmode` `known` `clonescan` `flyby` `flood` `spamscan` `badword` `antiadvertise` `badchan` `authban` |
| Settings | `chanflags` `status` `ao` `av` `autolimit` `welcome` `automsg` `topic` `vip` `peak` |
| Channel | `op` `deop` `voice` `devoice` `kick` `ban` `unban` `banlist` `baninfo` `banclear` `invite` `mode` `say` `saveop` `reop` |
| Q | `qban` `qpermban` `qunban` `qbanlist` `qbanclear` `qrecover` `qdeopall` `qdevoiceall` `qclearchan` `qchanflags` `qchanmode` `qautolimit` `qwelcome` `qsettopic` `qop` `qvoice` `qinvite` `chanlev` `auth` |
| Admin | `addchan` `delchan` `channels` `hop` `gban` `gunban` `broadcast` `update` `version` `help` |

Channel feature letters for `chanflags`:

| Flag | Feature | Flag | Feature | Flag | Feature |
|---|---|---|---|---|---|
| `p` | protection | `h` | hard protection | `b` | bitchmode |
| `o` | auto-op | `v` | auto-voice | `l` | auto-limit |
| `s` | spamscan | `B` | badwords | `A` | anti-advertise |
| `C` | clonescan | `F` | flyby | `K` | known-only |
| `w` | welcome | `t` | topic save | `f` | force topic |
| `V` | vip | `a` | auth bans | `c` | bad channels |
| `e` | enforcebans | `d` | dynamicbans | `m` | enforced modes |
| `P` | peak | | | | |

## Structure

```
service/
├── service.tcl            loader (the only file you source)
├── service.conf.example   configuration template (copy to service.conf)
├── VERSION, manifest.sha256
├── modules/
│   ├── core.tcl           dispatcher, filters, settings, accounts, helpers   (required)
│   ├── crypto.tcl         SHA-256 / HMAC-SHA-256                             (required)
│   ├── protect.tcl        mode/kick/topic protection, netsplits
│   ├── takeover.tcl       mass deop/kick/ban detection, lockdown
│   ├── qnet.tcl           Q login (CHALLENGEAUTH), Q requests, Q answer relay
│   ├── spamscan.tcl       spamscan and flood handling
│   ├── onjoin.tcl         welcome, auto modes, clonescan, authban/badchan/vip
│   ├── botnet.tcl         mutual protection between linked bots
│   ├── cmd_*.tcl          commands (users, settings, channel, q, admin)
│   ├── help.tcl           help system
│   └── updater.tcl        GitHub updater
├── docs/                 INSTALL.md (+ INSTALL.es.md), MANUAL.md
├── tests/                 crypto vectors, smoke test, feature tests (simulated Eggdrop)
└── tools/manifest.tcl     generates manifest.sha256 for releases
```

Each module registers its own binds and commands, and optional modules can be turned off with `disabled_modules` in `service.conf`.
Commands are looked up in a hash table, so the number of commands doesn't slow the bot down.

## Known issues

### Fixed in 6.0.0

The most important problems of r0t3n's v40.1 (fixed) and v5.2 (not carried over), see [CHANGELOG.md](CHANGELOG.md) for the full list:

| Issue | Impact |
|-------|--------|
| v40.1: hidden `PRIVMSG #secret` on load and every 30 min | Announced the bot to a third party |
| v40.1: auto-updater sent credentials over plain HTTP, then ran (`source`) the download | Remote code execution if the dead update domains were re-registered |
| v5.2: `validbanmask` inverted | Protection never banned an attacker |
| v5.2: `debug` module enabled by default | Tcl code run from the channel |
| Anti-flood banned the bot's own nick | Flooders were never banned |
| `banclear` crashed with temporary bans | Command unusable |
| WHOIS data never freed; an authban miss skipped badchan/VIP | Memory leak, missed checks |
| `kickprot` built `*!**!*...` ban masks | Bans did not match the attacker |
| `automsg` and `checkraw` never bound | Features silently did nothing |
| `rejoin` used `after 2000` | Whole bot frozen for 2 s |
| `SBNC :partall` on connect | Bot parted every channel behind sBNC |
| A user without access opping the bot made the bot deop itself | Bot lost op |
| With `topic Q on` the bot kick-banned Q | Q kicked from the channel |
| Clonescan via `chanflags +C` had maxclones 0 | Everyone who joined was kicked |
| Autolimit only moved when off by exactly 3 | Channel left full |
| `access`: masters could demote the channel owner | Privilege escalation |
| Text containing `{` / `}` | Tcl errors in commands and filters |

### Still open

- Commands only work in channels (plus `/msg BotNick rejoin`); there is no private-message command interface yet.
- Support for the `L` service bot is minimal; everything is built around `Q`.
- Users without +x are recognised by Q account only once Eggdrop has learned their account.
- v6.0.0 is tested with Tcl 8.6 and simulated Eggdrop commands (`tests/`), but not yet on a live QuakeNet bot. Please report problems in the issue tracker.

## Credits

- Original script and all its features: **r0t3n** aka Eagle (#r0t3n)
- v6.0.0 (fixes, security, modular structure, takeover/Q/botnet features, updater): [sauk1337](https://github.com/sauk1337)
- Help texts partly based on r0t3n's v5 `commands.ini`

## License

[MIT](LICENSE). The copyright notice credits r0t3n as the original author.
