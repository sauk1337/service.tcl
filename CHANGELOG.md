# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [6.1.0] - 2026-10-14

### Added
- `adduser` also adds the user's Q auth host (`*!*@account.users.quakenet.org`)
  next to the host they were added with, and links the account. For users
  without +x whose account Eggdrop doesn't know yet, the bot looks it up with
  a WHOIS (330 "is authed as"). The person who ran `adduser` is told which
  host was added, or that the user isn't authed with Q.

## [6.0.0] - 2026-10-14

First public release by sauk1337, based on r0t3n's `service.tcl` v40.1 (2020).
Ideas were also taken from his modular v5.2 (2016). The version number
continues his modular line (5.x -> 6.0.0).
All credit for the original script goes to r0t3n (aka Eagle).

### Added - QuakeNet and anti-takeover
- **CHALLENGEAUTH** login with Q (HMAC-SHA-256): the password never leaves the
  bot. It is verified against QuakeNet's published test vectors. Plain
  `AUTH` is still available (`qauth(method) auth`).
- **Auth before join** (`qauth(waitjoin)`): channels are joined only after
  the Q login and `+x`, so the bot's IP is never shown. A timeout and crash
  recovery make sure channels are always joined in the end.
- Q notices are only accepted from `Q!TheQBot@CServe.quakenet.org`.
- **Takeover protection** (`takeover.tcl`): N deops, kicks or bans by one
  user within T seconds trigger an immediate response, sent without queue
  (`putnow`):
  - kick-ban the attacker;
  - Q `RECOVER` + `OP`;
  - Q `TEMPBAN` of the attacker;
  - removal of the attacker's Q chanlev;
  - lockdown (`+im`) for a while;
  - re-op of trusted users;
  - alerts to the staff channel and to linked bots.

  Fully configurable (`takeover` array).
- `lockdown on|off|status` and `takeover` (shows the settings) commands.
- **Q commands**: `qban`/`qtempban`, `qpermban`, `qunban`/`qbandel`,
  `qbanlist`, `qbanclear`, `qrecover`, `qdeopall`, `qdevoiceall`,
  `qclearchan`, `qchanflags`, `qchanmode`, `qautolimit`, `qwelcome`,
  `qsettopic`, `qop`, `qvoice`, `qinvite`. Q's answers are relayed to the
  user for 15 seconds. `chanlev` without flags now shows the chanlev.
- **Q accounts**: users can be linked to a Q account (`account` command;
  `adduser` stores it automatically) and are then recognised by the account
  (Eggdrop 1.9 account tracking or the +x host), not only by hostmask. This
  is used for commands, protection and on-join modes.
- **Linked bots** (`botnet.tcl`): bots running service.tcl give each other
  op, invite, unban, the key or a higher limit. Takeovers are shared.
  Requests are only accepted from trusted bots and verified against the
  bot's hostmasks.
- **Saved ops survive restarts** (stored in the `service_saveops` channel
  setting). New `saveop list|clear`; `reop` no longer empties the list.
- **`help <command>`** with syntax, description, aliases and the access
  needed. `help` lists only the commands the user can use, by category.
- **GitHub updater** (`updater.tcl`):
  - checks the latest release every few hours and announces it, but never
    installs by itself;
  - `update apply` (global owners) downloads over verified HTTPS, checks
    every file against `manifest.sha256`, backs up the old files, rolls back
    on error and rehashes;
  - `service.conf` is never touched.
- Pure-Tcl SHA-256 / HMAC-SHA-256 (`crypto.tcl`); tcllib is used when it is
  installed.
- Errors in a command are reported to the user and to the staff channel
  instead of failing silently (idea from v5.2).
- `docs/INSTALL.md` (+ Spanish `docs/INSTALL.es.md`): step-by-step installation and requirements
- `docs/MANUAL.md`, `service.conf.example`, `tools/manifest.tcl` and tests
  for the crypto vectors, all commands and the new features, run by GitHub
  Actions.

### Added - other features
- `enforcemodes <+-modes> ?key? ?limit?|on|off`: keeps channel modes fixed,
  even against ops (the code existed but could never be configured). Also
  applied as soon as the bot gets op. `chanflags` letter `m`.
- `peak`: channel user record, with optional announcement. `chanflags`
  letter `P`. Idea from v5.2.
- The WHOIS for the authban/badchan/vip checks is sent a few seconds after
  the join (`whoischeck(delay)`), once per nick and on the slow queue. A
  join flood no longer floods the server queue with WHOIS. Idea from v5.2.
- `status` also shows takeover protection, lockdown, enforced modes, peak,
  Q presence, the bot's Q login and whether the bot is opped.
- Advert detection also matches domains with hyphens. Spamscan also scores
  bare domains (`site.com`).

### Fixed - protection (rewritten modeprot, kickprot and topicprot)
- **If a user without access opped the bot, the bot deopped itself**
  (protection "reverted" the op).
- Reverting `-k`/`-l` sent `MODE +k`/`MODE +l` without a parameter, and `-k`
  shifted the parameters of the other modes in the same line. The old key
  and limit are now restored.
- **With `topic Q on`, the bot kick-banned Q** when Q set the topic.
- The ban on an attacker who deopped the bot was never stored; now it is
  enforced once the bot has op again.
- QuakeNet modes `+r +N +T +M` were not reverted; `+d` (server-only) was.
- More than 6 modes per line were sent, and QuakeNet ignored the rest.
- When the bot was kicked, the Q requests went out in reverse order
  (OP before RECOVER). The channel's Q `CHANFLAGS` were also changed every
  time.
- Topic protection no longer sets "[TOPICPROT] No topic(s) saved." when no
  topic was saved.

### Fixed - other
- **The bot didn't log in to Q on connect (only with the `auth` command).**
  The event bind used a `*` mask, but Eggdrop matches `evnt` binds against
  the exact event name, so `init-server` (and the rehash cleanup, which was
  also misspelled `pre-rehash`) never ran. This bug came from v40.x. The bot
  now also logs in when the script is loaded while already connected
  (e.g. after `.restart`).
- **Clonescan enabled with `chanflags +C` (no `clonescan set ...` yet) had
  maxclones 0 and kicked everyone who joined.** Users with access and the
  bot itself are no longer kicked as clones.
- **Autolimit only changed the limit when it was off by exactly 3**, so
  bursts of joins/parts left the channel full. It is now updated on joins,
  parts, quits and kicks. Limit 0 is treated as 10.
- **Spamscan never detected adverts**: the caps check overwrote the word
  first.
- `protectedwords` matched the wrong way round (a user typing `*` matched
  everything).
- **`parseflud` always returned 1, which also disabled Eggdrop's own flood
  protection** on channels without the service flood feature.
- **`unban`, `gunban` and `banclear` failed after removing a ban**
  (`ischanban` was called with its arguments swapped).
- **`adduser` with an existing handle changed that other user's access.**
- **`access`: a channel master could change or remove the access of the
  channel owner; a global master could do the same to a global owner.**
- `adduser`/`access` with an unknown `#channel` failed with an error.
- The bot sent a WHOIS for itself on join. VIP skins with braces were mangled.

### Not carried over from v5.2
Reviewed, but not taken over because of these bugs or risks:
- `validbanmask` was inverted (only `*!*@*` counted as valid), so
  protection never banned.
- The `debug` module (enabled by default) evaluated Tcl code from the
  channel.
- `upgrade()` erased the automsg lines on every load (`linsert` without
  using its result).
- `onraw_kick` read `$reop`, which was never set, and failed.
- The updater ran `git pull` through `bash` scripts.

### Changed - modular structure
- The 5700-line single file is now a small loader (`service.tcl`) plus
  modules in `modules/` (see the README for the list).
- Each module registers its own binds and commands. Optional modules can be
  turned off with `disabled_modules` in `service.conf`.
- The 4000-line `switch` in `service::central` is replaced by a command table:
  each command is its own proc (`service::cmd_<name>`), looked up in O(1).
- The statistics code that every command repeated (3 lines each) is now one
  `service::track` helper.
- New install path: `scripts/service/service.tcl`.
- Commands are now case-insensitive (`!OP` works like `!op`).
- A broken module no longer stops the others from loading. A broken or
  missing configuration aborts loading the script instead of killing the
  whole bot (`die`).

### Security
- **Removed the hidden "phone-home".** v40.1 sent `PRIVMSG #secret` on load and
  every 30 minutes, announcing the bot and the configured update account.
- **Removed the old auto-updater.** It sent a username and password in plain text
  over `http://` to two third-party domains that no longer exist, then ran
  (`source`) whatever it downloaded. Anyone who registered those domains could
  run arbitrary Tcl code on the bot.
- Removed the hardcoded update credentials from `service.conf`.
- The `tcl` debug command is now disabled by default (`tcldebug ""`).
- Q authentication now uses `PRIVMSG Q@CServe.quakenet.org :AUTH ...`, so the
  password is only sent to Q's secure address.
- Kick/ban messages no longer imitate network kills (`Killed (*.quakenet.org ...)`).

### Removed
- `SBNC :partall` on connect. It made the bot part every channel when it ran
  behind an sBNC.
- The unused and broken global procs `joinmodes` and `changemodes`, and a
  duplicate `service::enforcedmode` definition.

### Fixed
- Commands and joins from users who are not in the userfile raised Tcl errors
  (`getuser` on `*`). Their lines now go straight to the filters.
- With badwords enabled, anti-advertise and spamscan never ran. All filters
  now run in turn.
- Anti-advertise: IP detection matched any character instead of dots, and
  `https://` links were not detected.
- Rehash: the cleanup of old procs never worked, because the namespace
  pattern was resolved relative to `::service`. Binds with braces in their
  mask were not removed.
- `bind raw` procs now always return 0, so Eggdrop never skips its own
  processing of MODE/TOPIC/INVITE lines.
- On-join login tracking used the joining handle for every user when the bot
  itself joined.
- `/msg bot rejoin` accepted names that were not channels.
- `protect status` printed "disable".
- Anti-flood: `newchanban` was called without a ban mask, so it **banned the
  bot's own nick** instead of the flooder. It now bans the flooder's host.
- Anti-flood join-lock: unlocking sent an invalid mode string (`-mr++ntl 50`).
  It now only removes the modes it added.
- `banclear`: errors whenever temporary bans existed (`incr` on a list,
  `$perll`/`$perm1` typos).
- `spamscan`: channel-flood lock used an undefined variable (`$chan`) and a
  non-existent setting (`spamscan(lockmodes)`). The warning notice applied
  its replacements to the wrong variable. The network name was taken from
  the wrong part of `$network`.
- `spamscan`: timers that unset counters could throw errors. They are now
  wrapped in `catch`.
- `vip authbl add` never saved anything (`lappend $blist`).
- `vip`: the first matching VIP was skipped when no skin was configured yet.
  The auth blacklist check is now case-insensitive.
- `adduser`: the handle length check could never trigger (`<= 2 && > 9`).
- `adduser`/`access ... ban` (global): `channel set` was missing the setting
  name and read the wrong counter (`gkid` → `service_gkid`).
- `gban`: `channel get service::adminchan` was missing the `$`.
- `badword` (trigger path): used a non-existent setting (`service_bwkid`) and
  a typo (`$kicksmg`).
- `badword list`: paging checked the wrong variable.
- `authban`/`badchan`: custom kick messages were ignored. `$nicknane` typos
  broke the kick when no valid ban mask existed.
- WHOIS processing (authban/badchan/vip):
  - leaked memory: whois data was never freed;
  - used an undefined variable (`$chans`);
  - a `return` on a non-matching authban skipped the badchan and VIP checks;
  - multi-line `RPL_WHOISCHANNELS` replies were not handled.
- `kickprot`: the ban mask was built twice, which produced `*!**!*...`.
- Protection: Q commands were sent to an empty target when the service bot
  was unknown. They now fall back to `Q`.
- Topic protection: topics that contained `:` were cut off.
- Invite handler: typo `lidex` broke the notice to the inviting user.
- `checkraw` was never bound and used an undefined `$channel`. It is now bound
  to raws 471/473/474/475/477/479.
- `automsg` was never bound to a timer, so it never ran. Its `+m` check used
  `||` instead of `&&`.
- `rejoin`: `after 2000` froze the whole bot for 2 seconds. It now uses a
  non-blocking `utimer`.
- `welcome set` without arguments now shows the current skin.
- `whois`/`whoami`: overwrote the `channel` variable, checked flags on the
  nickname instead of the handle, and continued after "user not found".
- `mytrigger`/`help`: wrong `setuser` call when a user had no trigger.
- `clonescan off`/`disable` did not work (`"disabled"`). Fixed "bow enabled"
  typo.
- `flood status` printed `disabled:`.
- `baninfo`: `NOTIICE` typo.
- `file mkdir -force` (invalid in Tcl) created a directory named `-force`.
- `return` at the top level of the script while looping channels/users could
  abort loading.
- At load time, the cleanup of catch-all bans now only sends `-b` when the
  bot is opped and the ban really exists.

### Changed
- All user input is now handled as strings (`split`/`join`) instead of being
  parsed as Tcl lists. Text with `{` or `}` no longer causes errors.
- Kick message keywords are now replaced with `string map` instead of `regsub`.
  Reasons containing `&` or `\1` are no longer mangled.
- Files are now UTF-8 with LF line endings (Eggdrop 1.9+ default).
- The configuration ships as `service.conf.example`, with neutral defaults.
  Users copy it to `service.conf`, which is ignored by git and never
  overwritten, so a Q password can't be published by accident.
- The version is read from the `VERSION` file.
- Load time is measured in milliseconds with `clock microseconds`.

### Added - other
- The `auth` command uses the same `qauth` settings and never makes the bot
  leave its channels.
