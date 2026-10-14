# Installation guide

Step by step, from an empty server to a bot protecting your channel on QuakeNet.
🇪🇸 [Versión en español](INSTALL.es.md)

If you already have a running Eggdrop, skip to [step 5](#step-5-get-a-q-account-for-the-bot).

- [Requirements](#requirements)
- [Step 1: Prepare the server](#step-1-prepare-the-server)
- [Step 2: Build and install Eggdrop](#step-2-build-and-install-eggdrop)
- [Step 3: Configure Eggdrop for QuakeNet](#step-3-configure-eggdrop-for-quakenet)
- [Step 4: First start and becoming owner](#step-4-first-start-and-becoming-owner)
- [Step 5: Get a Q account for the bot](#step-5-get-a-q-account-for-the-bot)
- [Step 6: Install service.tcl](#step-6-install-servicetcl)
- [Step 7: Configure service.tcl](#step-7-configure-servicetcl)
- [Step 8: Load the script](#step-8-load-the-script)
- [Step 9: Check that it works](#step-9-check-that-it-works)
- [Keeping the bot running](#keeping-the-bot-running)
- [Updating](#updating)
- [Troubleshooting](#troubleshooting)

---

## Requirements

### Server

| | Required | Notes |
|---|---|---|
| Operating system | Linux, FreeBSD or macOS | Any small VPS is enough. Windows works via WSL. |
| Eggdrop | **1.9.0 or newer** | 1.10.x recommended. Older versions (1.8) are not supported. |
| Tcl | **8.5 or newer** | 8.6 recommended. Eggdrop needs the Tcl headers (`tcl-dev`) to compile. |
| Build tools | `gcc`/`make` | Only to compile Eggdrop. |
| OpenSSL headers | recommended | `libssl-dev`, so Eggdrop is built with TLS support. |
| `tcl-tls` | optional | Needed by the updater (`update check` / `update apply`). |
| `tcllib` | optional | Faster SHA-256 for the Q login. A pure Tcl version is built in. |
| `unzip` or `git` | one of them | To get the script. |
| Memory / disk | ~10 MB RAM, ~5 MB disk | |

### QuakeNet

| | Required | Notes |
|---|---|---|
| Q account for the bot | **yes** (recommended) | Without it, the bot can't hide its IP or ask Q for help during a takeover. |
| Bot access on your channels | **`+amo`** in Q's chanlev | `+m` (master) is what allows `RECOVER`, `TEMPBAN` and `CHANLEV` against attackers. |
| You | `+n` or `+m` on the channel | To give the bot its access. |

---

## Step 1: Prepare the server

Commands are for **Debian 12 / Ubuntu 22.04 / 24.04**. Run as root:

```sh
apt update
apt install -y build-essential tcl tcl-dev libssl-dev tcl-tls tcllib wget unzip nano
```

<details>
<summary>Other systems</summary>

```sh
# Fedora / RHEL / Rocky / Alma
dnf install -y gcc make tcl tcl-devel openssl-devel tcltls tcllib wget unzip nano

# FreeBSD
pkg install -y tcl86 tcltls tcllib gmake wget unzip nano
```
</details>

Never run the bot as root. Create a user for it and switch to it:

```sh
adduser eggdrop
su - eggdrop
```

Everything from here on is done as the `eggdrop` user.

---

## Step 2: Build and install Eggdrop

Check the latest 1.10 version on <https://www.eggheads.org/downloads> and put it in `VER`:

```sh
VER=1.10.2
cd ~
wget https://ftp.eggheads.org/pub/eggdrop/source/1.10/eggdrop-$VER.tar.gz
tar xzf eggdrop-$VER.tar.gz
cd eggdrop-$VER
./configure
make config
make
make install
```

The bot is now installed in `~/eggdrop`. You can remove the build files:

```sh
cd ~ && rm -rf eggdrop-$VER eggdrop-$VER.tar.gz
```

---

## Step 3: Configure Eggdrop for QuakeNet

```sh
cd ~/eggdrop
nano eggdrop.conf
```

Find and change these lines (in nano, `Ctrl+W` searches):

```tcl
set username "mybot"
set admin "YourNick <email: you@example.com>"
set network "QuakeNet"
set timezone "Europe/London"

listen 3333 all                  ;# partyline port (telnet)

set nick "MyBot"
set altnick "MyBot-"
set realname "service.tcl bot"

set net-type "QuakeNet"

server add irc.quakenet.org 6667
```

Also:
- Remove the other example `server add …` lines.
- If any line starts with `die`, delete it. Those lines are there to make you read the file and stop the bot from starting.
- Check that `set userfile` and `set chanfile` have names, for example `MyBot.user` and `MyBot.chan`.

Save with `Ctrl+O`, `Enter`, `Ctrl+X`.

---

## Step 4: First start and becoming owner

```sh
cd ~/eggdrop
./eggdrop -m eggdrop.conf
```

`-m` is only used the first time: it creates the user file. When the bot is online, from your IRC client:

```
/msg MyBot hello
/msg MyBot pass YourBotPassword
```

You are now the bot's owner (`+n`). To open the partyline:
- **DCC:** `/ctcp MyBot chat`
- **Telnet:** `telnet SERVER_IP 3333`, then your nick and password. Open the port if you use a firewall: `ufw allow 3333/tcp`.

From now on, start the bot without `-m`: `./eggdrop eggdrop.conf`.

---

## Step 5: Get a Q account for the bot

1. From your own IRC client, change your nick to the account name you want for the bot (`/nick MyBot`, while the bot is offline or using another nick) and register:
   ```
   /msg Q HELLO you@example.com you@example.com
   ```
2. Q emails you the password. You can change it with:
   ```
   /msg Q@CServe.quakenet.org NEWPASS oldpass newpass newpass
   ```
3. Go back to your normal nick. With **your own** Q account (you need `+n` or `+m` on the channel), give the bot access:
   ```
   /msg Q CHANLEV #yourchannel MyBot +amo
   ```
   Repeat for every channel, including the staff channel.

---

## Step 6: Install service.tcl

Choose **one** of these options.

**A) Release ZIP (recommended):** download the latest `.zip` from the [Releases page](https://github.com/sauk1337/service.tcl/releases), upload it to the server and unpack it:

```sh
cd ~/eggdrop/scripts
unzip ~/service-*.zip            # creates scripts/service/
```

To upload it from Windows, use PowerShell (`scp` is built in) or WinSCP / FileZilla (SFTP):

```powershell
scp service-6.0.0.zip eggdrop@SERVER_IP:~/
```

**B) Git:**

```sh
cd ~/eggdrop/scripts
git clone https://github.com/sauk1337/service.tcl.git service
```

Either way, you should end up with:

```
eggdrop/
├── eggdrop.conf
└── scripts/
    └── service/
        ├── service.tcl            ← the only file you load
        ├── service.conf.example
        ├── modules/
        └── docs/  tests/  tools/
```

---

## Step 7: Configure service.tcl

```sh
cd ~/eggdrop/scripts/service
cp service.conf.example service.conf
chmod 600 service.conf             # it contains the Q password
nano service.conf
```

At least change:

```tcl
variable homechan "#yourchannel"
variable adminchan "#yourchannel.staff"   ;# takeover alerts, errors, reports
variable helpchan "#yourchannel"

array set qauth {
	"user" "MyBot"                        ;# Q account from step 5
	"pass" "the_Q_password"
	"method" "challenge"
	"hidehost" "1"
	"waitjoin" "1"
	"timeout" "30"
}
```

The command trigger is `$` by default (`variable trigger`). Everything else can stay at its default value. The [manual](MANUAL.md) explains every option.

Optional: check that the script runs with the server's Tcl. It takes a few seconds:

```sh
tclsh tests/crypto.tcl   | tail -1
tclsh tests/smoke.tcl    | tail -2
tclsh tests/features.tcl | tail -1
```

All three must end with `failures: 0`.

---

## Step 8: Load the script

```sh
cd ~/eggdrop
echo 'source scripts/service/service.tcl' >> eggdrop.conf
```

> **Upgrading from r0t3n's old `service.tcl` (v40.x)?** Comment out its `source` line in `eggdrop.conf` with a `#`. Never load both. Your userfile and chanfile keep working.

Then restart the bot. In the partyline: `.restart`. A restart is better than `.rehash` the first time, so nothing from an older script stays in memory.

---

## Step 9: Check that it works

In the log (`tail -f ~/eggdrop/logs/*.log`) or the partyline you should see:

```
service.tcl - v6.0.0 - ... - 15 modules (...) - 101 commands - loaded in X ms
service.tcl - authenticated with Q as MyBot
```

`/whois MyBot` should show `MyBot.users.quakenet.org`, which means the IP is hidden.

Then, on IRC (replace `$` with your trigger):

| # | Do this | Expected result |
|---|---|---|
| 1 | `$version`, `$help`, `$status` | Answers by notice. `status` shows `bot auth: authed` |
| 2 | `$protect on`, `$takeover` | Shows the anti-takeover settings |
| 3 | From a **second client** with op but no access on the bot: `/mode #channel +i` | The bot removes `+i` and kick-bans that client |
| 4 | From that client, deop 3 people quickly | `TAKEOVER` alert in the staff channel. Q RECOVER, TEMPBAN and CHANLEV, and `+im` lockdown |
| 5 | `$lockdown off` | `+im` is removed |
| 6 | `$qban Nick 10m test`, `$qbanlist`, `$qunban #1` | Q's answers come back as `[Q] …` |
| 7 | `$saveop`, `.restart`, `$saveop list` | The list survives the restart |
| 8 | `$enforcemodes +nt`, then an op sets `-t` | The bot sets `+t` again |
| 9 | `$account YourNick` | Shows your Q account |

---

## Keeping the bot running

Eggdrop includes `autobotchk`, which adds a cron job that restarts the bot if it dies or the server reboots:

```sh
cd ~/eggdrop
./scripts/autobotchk eggdrop.conf -dir ~/eggdrop -noemail
```

---

## Updating

- **Release install:** every few hours (`update(interval)`) the bot checks GitHub and tells the staff channel when a new release exists. Nothing is installed automatically: a global owner runs `$update check` and then `$update apply`. Every file is SHA-256 verified against `manifest.sha256`, the old files are backed up to `backup/`, and `service.conf` is never touched. If copying fails, the files already replaced are restored.
- **Git install:** `cd ~/eggdrop/scripts/service && git pull`, then `.restart`. (`update apply` refuses to run on a git checkout.)

After an update, check `CHANGELOG.md` and `service.conf.example` for new options.

---

## Troubleshooting

| Problem | What to check |
|---|---|
| `service.conf not found` | You skipped `cp service.conf.example service.conf` (step 7). |
| `ERROR loading module '…'` | Copy that line and the following ones from the log and open an issue. |
| Not authenticated with Q | User/password in `service.conf`. After `timeout` seconds the bot joins anyway, without `+x`. Check what Q answered in the log. |
| Takeover protection doesn't use Q | The bot needs `+m` in Q's chanlev (`/msg Q CHANLEV #channel`). |
| Commands don't answer | Wrong trigger, or you have no access: check with `$whoami`. Owners are users with global `+n`. |
| `update check` says tls is missing | `apt install tcl-tls`, then `.restart`. |
| Detail of the last Tcl error | `.tcl set errorInfo` in the partyline (needs the `.tcl` command enabled in Eggdrop). |

**Going back to the old script:** comment out the new `source` line, uncomment the old one and `.restart`.

Bugs and questions: [GitHub issues](https://github.com/sauk1337/service.tcl/issues).
