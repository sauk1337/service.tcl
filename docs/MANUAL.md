# service.tcl – Manual

This manual explains how to install, configure and use service.tcl on QuakeNet:
Q authentication, takeover protection, Q commands, accounts, linked bots and updates.
All settings live in `service.conf`; every option is also commented there.

- [1. Installation](#1-installation)
- [2. First steps](#2-first-steps)
- [3. Q setup and CHALLENGEAUTH](#3-q-setup-and-challengeauth)
- [4. Channel protection and takeover protection](#4-channel-protection-and-takeover-protection)
- [5. Q commands](#5-q-commands)
- [6. Users and Q accounts](#6-users-and-q-accounts)
- [7. Saved ops](#7-saved-ops)
- [8. Linked bots (botnet)](#8-linked-bots-botnet)
- [9. Updates from GitHub](#9-updates-from-github)
- [10. Help inside IRC](#10-help-inside-irc)
- [11. For maintainers: making a release](#11-for-maintainers-making-a-release)
- [12. Troubleshooting](#12-troubleshooting)

---

## 1. Installation

**Requirements**

| | |
|---|---|
| Eggdrop | 1.9.x or newer (Tcl 8.5+, 8.6 recommended) |
| tcl-tls | only for the updater (`apt install tcl-tls` on Debian/Ubuntu) |
| tcllib | optional – makes SHA-256 faster; a built-in pure-Tcl version is used otherwise |

**Steps**

1. Download the latest release from GitHub, or clone the repository, into your Eggdrop's `scripts/` folder as `scripts/service/`:
   ```sh
   cd ~/eggdrop/scripts
   git clone https://github.com/sauk1337/service.tcl.git service
   ```
2. Create your configuration from the example and protect it:
   ```sh
   cd service
   cp service.conf.example service.conf
   chmod 600 service.conf
   ```
3. Edit `service.conf`: at least `homechan`, `adminchan`, `helpchan` and, on QuakeNet, the `qauth` section (see [section 3](#3-q-setup-and-challengeauth)).
4. Add this line to the end of your `eggdrop.conf`:
   ```tcl
   source scripts/service/service.tcl
   ```
5. Start the bot, or `.rehash` from the partyline. The log should show:
   ```
   service.tcl - v6.1.0 - r0t3n aka Eagle (#r0t3n) - 15 modules (...) - 99 commands - loaded in X ms
   ```

`service.conf` is never overwritten by the updater and is ignored by git, so your settings and your Q password are never published.

## 2. First steps

1. **Become owner.** Create your user on the partyline (`.+user YourNick *!*@youraccount.users.quakenet.org`, then `.chattr YourNick +n`), or use Eggdrop's usual `/msg Bot hello` on a new bot.
2. **Your trigger.** The default trigger is `$`. Change it with `$mytrigger !`.
3. **Add the bot to a channel.** Use `$addchan #channel` (global owners) or `.+chan #channel` on the partyline.
4. **Enable features** on the channel, for example protection, spamscan and clonescan:
   ```
   $chanflags +psC
   $status
   ```
5. **Add your staff:**
   ```
   $adduser Nick handle master
   $adduser Nick2 handle2 op
   ```
6. Type `$help` to see the commands you can use, and `$help <command>` for details.

## 3. Q setup and CHALLENGEAUTH

### 3.1 Give the bot a Q account

1. Register an account for the bot with Q (`/msg Q HELLO email email` from the bot, or register it yourself and use those credentials).
2. Give the bot access in Q on each channel. **+m (master) is needed for takeover protection** (RECOVER, removing an attacker's chanlev). +n (owner) also allows removing masters:
   ```
   /msg Q CHANLEV #channel #BotAccount +amo
   ```

### 3.2 Configure the login

```tcl
array set qauth {
	"user" "BotAccount"
	"pass" "the-password"
	"method" "challenge"
	"hidehost" "1"
	"waitjoin" "1"
	"timeout" "30"
}
```

| Option | Meaning |
|---|---|
| `method` | `challenge` = CHALLENGEAUTH (recommended); `auth` = plain AUTH |
| `hidehost` | `1` = set user mode `+x` after logging in, so the IP is hidden |
| `waitjoin` | `1` = don't join channels until logged in, so the IP is never shown in a channel |
| `timeout` | seconds to wait for Q; after that the bot joins the channels anyway |

### 3.3 What CHALLENGEAUTH does

With plain `AUTH`, the password travels to Q as it is. With **CHALLENGEAUTH**:

1. The bot asks Q for a *challenge*, a random value that changes every time.
2. The bot computes `HMAC-SHA-256(key, challenge)`, where
   `key = SHA256(lowercase(user) + ":" + SHA256(first 10 chars of the password))`.
3. Only that result is sent. **The password never leaves the bot**, and a captured answer is useless because the next challenge is different.

The implementation is checked against QuakeNet's published test vectors (`tclsh tests/crypto.tcl`). Q's notices are only accepted from `Q!TheQBot@CServe.quakenet.org`, so they can't be spoofed by a user called "Q".

**Check it works:** after connecting, the log shows `authenticated with Q as BotAccount`, and `/whois Bot` shows `BotAccount.users.quakenet.org`. If the login fails, the reason is posted in the admin channel.

The `$auth` command (channel masters) repeats the login at any time, without leaving channels.

## 4. Channel protection and takeover protection

### 4.1 Channel protection

`$protect on` enables protection on a channel:

- mode, kick and topic changes by users without access are reverted, and the user is kick-banned;
- if the bot is deopped, kicked or banned, it asks Q to `RECOVER`, `UNBANME` and `OP`;
- `$protect hard on` also protects against channel operators: only masters and owners may change modes.

### 4.2 Takeover protection

Takeover protection is active on every channel with protection on. It watches for **mass actions**: when one user does `deops` deops, `kicks` kicks or `bans` bans within `window` seconds, the bot reacts immediately. Reactions are sent without waiting in the output queue (`putnow`).

| Step | What happens | Needs |
|---|---|---|
| 1 | Deop + ban + kick the attacker | bot opped |
| 2 | Q `RECOVER` + `OP` (if the attack included deops or the bot lost op) | +m in Q |
| 3 | Q `TEMPBAN` of the attacker's mask – Q keeps it even if the bot is gone | +o in Q |
| 4 | Q `CHANLEV #channel #account -aogvt` – the attacker can't re-op through Q | +m in Q (+n for `-mn`) |
| 5 | Lockdown: `+im` for 5 minutes (only the modes that weren't set are removed later) | bot opped |
| 6 | Re-op users with op access and the saved ops after the RECOVER | |
| 7 | Alert in the admin channel, and to linked bots | |

**Settings** (`takeover` array in `service.conf`):

| Option | Default | Meaning |
|---|---|---|
| `deops` / `kicks` / `bans` | 3 / 3 / 3 | actions that trigger the response (0 = off) |
| `window` | 10 | seconds |
| `exempt` | `bn|n` | flags never treated as attackers (bots, global owners, channel owners) |
| `recover` | 1 | use Q RECOVER |
| `qban` / `qban_time` | 1 / 1h | Q TEMPBAN and its duration |
| `qchanlev` | 1 | remove the attacker's Q access |
| `qchanlev_flags` | `-aogvt` | flags removed (a master can remove these) |
| `qchanlev_owner_flags` | `-mn` | also removed when the bot is +n in Q (empty = don't try) |
| `lockdown` / `lockdown_time` | `+im` / 300 | lockdown modes and seconds (`""` = no lockdown) |
| `reop` | 1 | re-op trusted users after RECOVER |
| `ban_time` | 120 | minutes of the bot's own ban |
| `notify` | 1 | report to the admin channel |

`$takeover` shows the active settings, and `$lockdown on|off|status` controls a lockdown by hand.

### 4.3 Enforced modes

`$enforcemodes +nt-i` keeps the channel at `+nt` and without `+i`: any change to those modes is undone, even by ops.
Use `$enforcemodes +ntk key` or `$enforcemodes +ntl 50` to fix a key or a limit.
`$enforcemodes off` stops it, and `$enforcemodes` shows the current setting.
The modes are applied straight away and every time the bot gets op.

### 4.4 On-join checks

Authban, badchan and VIP need a WHOIS of the joining user.
It is sent `whoischeck(delay)` seconds (default 3) after the join, only once per user, and on the slow queue.
A join flood therefore doesn't fill the server queue, and users who leave at once are not checked.

`$peak on` records the channel's user record and announces new records (`peak(announce)`). `$peak` shows the record.

**Testing safely:** use a test channel. Give a second client op (without bot access) and deop three users quickly with it. Watch the admin channel for the `TAKEOVER` report.

**Tips:**
- Keep the bot's Q access at +m or higher, and set Q's channel flags so the bot is protected (for example `/msg Q CHANFLAGS #channel +p`).
- Use `$saveop` to store the ops that must be restored after an attack.
- Two linked bots in the channel make a takeover much harder ([section 8](#8-linked-bots-botnet)).

## 5. Q commands

These commands act through Q, so they keep working even when the bot has lost op. Q's answers (ban lists, chanlev, errors) are forwarded to you for 15 seconds.

| Command | Q command | Access |
|---|---|---|
| `qban <nick\|mask> ?duration? ?reason?` (alias `qtempban`) | TEMPBAN | op |
| `qpermban <nick\|mask> ?reason?` | PERMBAN | master |
| `qunban <mask\|#id>` (alias `qbandel`) | BANDEL | op |
| `qbanlist` / `qbanclear` | BANLIST / BANCLEAR | op / master |
| `qrecover` | RECOVER | master |
| `qdeopall` / `qdevoiceall` / `qclearchan` | DEOPALL / DEVOICEALL / CLEARCHAN | master |
| `qchanflags ?flags?` / `qchanmode ?modes?` | CHANFLAGS / CHANMODE | master |
| `qautolimit ?n?` / `qwelcome ?text?` / `qsettopic <topic>` | AUTOLIMIT / WELCOME / SETTOPIC | master |
| `qop ?nick?` / `qvoice ?nick?` / `qinvite` | OP / VOICE / INVITE | op |
| `chanlev ?nick\|#account? ?flags?` | CHANLEV | master |

`qban` with a nickname bans `*!*@account.users.quakenet.org` for users with +x, and `*!*ident@host` otherwise. Bot owners, protected users and higher channel levels can't be banned. The default duration is `qcmd(bantime)`.

## 6. Users and Q accounts

Users are normally recognised by hostmask. On QuakeNet the best hostmask is `*!*@account.users.quakenet.org` (users with +x), which `adduser` stores automatically.

You can also **link a user to a Q account**. The user is then recognised by the account, even without +x or a matching host:

```
$account Nick                 show the link
$account #handle SomeAccount  link a handle to an account
$account #handle -            remove the link
```

`adduser` links the account automatically when the user is authed, and also adds the account's hidden host `*!*@account.users.quakenet.org` to the user, so someone added with their real host (no +x) is still recognised by hostmask after they set +x. The account is read from Eggdrop's account tracking (Eggdrop 1.9 + WHOX on QuakeNet) or from the +x host; when neither knows it, the bot sends a WHOIS and uses the "is authed as" line. You get a notice with the host added, or one saying the user isn't authed (then only the normal hostmask is stored). Users without +x are otherwise recognised once Eggdrop has learned their account (for example after the bot's WHO on join).

## 7. Saved ops

```
$saveop          save the current ops (kept across restarts)
$saveop list     show the saved list
$saveop clear    empty the list
$reop            re-op the saved ops that are on the channel
```

After a takeover (`takeover(reop) 1`), saved ops are re-opped together with the users who have op access.

## 8. Linked bots (botnet)

Two or more Eggdrops running service.tcl can protect each other. A bot that loses op, or is banned, gets op / invite / unban / the key / a higher limit from a linked bot that is opped. A takeover seen by one bot is shared, so the others ban the attacker too.

**1. Link the bots** (Eggdrop botnet). On BotA's partyline:
```
.+bot BotB botb.example.com 3333
.+host BotB *!botb@botb.users.quakenet.org
.chattr BotB +o
```
On BotB's partyline:
```
.+bot BotA bota.example.com 3333
.+host BotA *!bota@bota.users.quakenet.org
.chattr BotA +o
```
Then `.link BotB` on BotA. The first link sets the passwords automatically. Check the link with `.bots`.

**2. Enable it** in both `service.conf` files:
```tcl
array set botnet {
	"enabled" "1"
	"flag" "o"
	"share_takeover" "1"
}
```

**Security:**
- Requests are only accepted from linked bots that have the bot flag (+b, set by `.+bot`) and the trust flag (`flag`, global or channel).
- Only the nickname that matches that bot's stored hostmasks gets op.
- The channel key is only sent to a verified, trusted bot.

## 9. Updates from GitHub

The updater checks the repository in `update(repo)` every `update(interval)` hours. When a new **release** exists, it announces it in the admin channel. **It never installs anything by itself.**

```
$update          check now
$update status   current/latest version, last check
$update apply    install the new release (global owners only)
```

What `update apply` does:

1. Downloads `manifest.sha256` and every file in it, over HTTPS with certificate verification.
2. Checks the SHA-256 of every file. A single mismatch cancels the update.
3. Copies the current files to `backup/<version>-<date>/`.
4. Installs the new files (rolling back if anything fails) and rehashes the bot.

`service.conf` is never touched; new options appear in `service.conf.example`. To go back to the previous version, copy the files from `backup/` and `.rehash`.

If you installed with `git clone`, update with `git pull` in the script folder instead, then `.rehash`.

**Requirements:** Tcl `tls` 1.7 or newer (`apt install tcl-tls`). If the CA certificates aren't found, set `update(cafile)`, for example `/etc/ssl/certs/ca-certificates.crt`.

## 10. Help inside IRC

- `$help` lists the commands *you* can use on the channel, grouped by category.
- `$help <command>` shows the syntax, the description, the aliases and the access needed.

## 11. For maintainers: making a release

1. Update `VERSION` (for example `6.1.0`) and add a section to `CHANGELOG.md`.
2. Regenerate the manifest, and run the tests:
   ```sh
   tclsh tools/manifest.tcl
   tclsh tests/crypto.tcl && tclsh tests/smoke.tcl && tclsh tests/features.tcl
   ```
3. Commit, tag and push:
   ```sh
   git add -A
   git commit -m "service.tcl v6.1.0"
   git tag v6.1.0
   git push && git push origin v6.1.0
   ```
4. On GitHub: **Releases → Draft a new release**, choose the tag, and paste the CHANGELOG section. Bots running the updater will announce it within `update(interval)` hours.

The GitHub Actions workflow runs all the tests and fails if `manifest.sha256` is out of date.

## 12. Troubleshooting

| Problem | Check |
|---|---|
| `service.conf not found` | `cp service.conf.example service.conf` in the script folder |
| The bot doesn't join channels for 30 s after connecting | `waitjoin` is waiting for Q: check `qauth(user)`/`pass`; the admin channel shows why the login failed |
| `Q auth failed` | Wrong account/password, or the account is suspended. Try `method auth` to compare |
| Takeover protection doesn't react | Protection must be on (`$protect on`). Check `$takeover`; the attacker may have an exempt flag |
| Q ignores RECOVER / CHANLEV | The bot needs +m on the channel in Q (`/msg Q CHANLEV #channel`) |
| `update`: "tls package not installed" | Install tcl-tls, or update manually |
| A command answers "failed" | The error is posted in the admin channel and in the bot's log |
