# Guía de instalación

Paso a paso, desde un servidor vacío hasta un bot protegiendo tu canal en QuakeNet.
🇬🇧 [English version](INSTALL.md)

Si ya tienes un Eggdrop funcionando, salta al [paso 5](#paso-5-cuenta-de-q-para-el-bot).

- [Requisitos](#requisitos)
- [Paso 1: Preparar el servidor](#paso-1-preparar-el-servidor)
- [Paso 2: Compilar e instalar Eggdrop](#paso-2-compilar-e-instalar-eggdrop)
- [Paso 3: Configurar Eggdrop para QuakeNet](#paso-3-configurar-eggdrop-para-quakenet)
- [Paso 4: Primer arranque y hacerte owner](#paso-4-primer-arranque-y-hacerte-owner)
- [Paso 5: Cuenta de Q para el bot](#paso-5-cuenta-de-q-para-el-bot)
- [Paso 6: Instalar service.tcl](#paso-6-instalar-servicetcl)
- [Paso 7: Configurar service.tcl](#paso-7-configurar-servicetcl)
- [Paso 8: Cargar el script](#paso-8-cargar-el-script)
- [Paso 9: Comprobar que funciona](#paso-9-comprobar-que-funciona)
- [Mantener el bot encendido](#mantener-el-bot-encendido)
- [Actualizar](#actualizar)
- [Solución de problemas](#solución-de-problemas)

---

## Requisitos

### Servidor

| | Necesario | Notas |
|---|---|---|
| Sistema operativo | Linux, FreeBSD o macOS | Cualquier VPS pequeño sirve. En Windows funciona con WSL. |
| Eggdrop | **1.9.0 o superior** | Se recomienda 1.10.x. Las versiones antiguas (1.8) no están soportadas. |
| Tcl | **8.5 o superior** | Se recomienda 8.6. Para compilar Eggdrop hacen falta las cabeceras de Tcl (`tcl-dev`). |
| Herramientas de compilación | `gcc`/`make` | Solo para compilar Eggdrop. |
| Cabeceras de OpenSSL | recomendado | `libssl-dev`, para que Eggdrop se compile con soporte TLS. |
| `tcl-tls` | opcional | Lo necesita el actualizador (`update check` / `update apply`). |
| `tcllib` | opcional | SHA-256 más rápido para el login en Q. Si no está, se usa la versión en Tcl puro que lleva el script. |
| `unzip` o `git` | uno de los dos | Para descargar el script. |
| Memoria / disco | ~10 MB de RAM, ~5 MB de disco | |

### QuakeNet

| | Necesario | Notas |
|---|---|---|
| Cuenta de Q para el bot | **sí** (recomendado) | Sin ella el bot no puede ocultar su IP ni pedir ayuda a Q durante un takeover. |
| Acceso del bot en tus canales | **`+amo`** en la chanlev de Q | Con `+m` (master) puede usar `RECOVER`, `TEMPBAN` y `CHANLEV` contra los atacantes. |
| Tú | `+n` o `+m` en el canal | Para dar acceso al bot. |

---

## Paso 1: Preparar el servidor

Los comandos son para **Debian 12 / Ubuntu 22.04 / 24.04**. Ejecútalos como root:

```sh
apt update
apt install -y build-essential tcl tcl-dev libssl-dev tcl-tls tcllib wget unzip nano
```

<details>
<summary>Otros sistemas</summary>

```sh
# Fedora / RHEL / Rocky / Alma
dnf install -y gcc make tcl tcl-devel openssl-devel tcltls tcllib wget unzip nano

# FreeBSD
pkg install -y tcl86 tcltls tcllib gmake wget unzip nano
```
</details>

No ejecutes nunca el bot como root. Crea un usuario para él y cámbiate a ese usuario:

```sh
adduser eggdrop
su - eggdrop
```

A partir de aquí todo se hace como el usuario `eggdrop`.

---

## Paso 2: Compilar e instalar Eggdrop

Busca la última versión de la rama 1.10 en <https://www.eggheads.org/downloads> y ponla en `VER`:

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

El bot queda instalado en `~/eggdrop`. Ya puedes borrar los archivos de compilación:

```sh
cd ~ && rm -rf eggdrop-$VER eggdrop-$VER.tar.gz
```

---

## Paso 3: Configurar Eggdrop para QuakeNet

```sh
cd ~/eggdrop
nano eggdrop.conf
```

Busca y cambia estas líneas (en nano se busca con `Ctrl+W`):

```tcl
set username "mibot"
set admin "TuNick <email: tu@email.com>"
set network "QuakeNet"
set timezone "Europe/Madrid"

listen 3333 all                  ;# puerto de la partyline (telnet)

set nick "MiBot"
set altnick "MiBot-"
set realname "service.tcl bot"

set net-type "QuakeNet"

server add irc.quakenet.org 6667
```

Además:
- Borra los demás `server add …` de ejemplo.
- Si alguna línea empieza por `die`, bórrala. Están para obligarte a leer el archivo e impiden que el bot arranque.
- Comprueba que `set userfile` y `set chanfile` tienen nombre, por ejemplo `MiBot.user` y `MiBot.chan`.

Guarda con `Ctrl+O`, `Enter` y `Ctrl+X`.

---

## Paso 4: Primer arranque y hacerte owner

```sh
cd ~/eggdrop
./eggdrop -m eggdrop.conf
```

`-m` solo se usa la primera vez, porque crea el userfile. Cuando el bot esté conectado, desde tu cliente de IRC:

```
/msg MiBot hello
/msg MiBot pass TuContraseñaDelBot
```

Ya eres owner del bot (`+n`). Para entrar en la partyline:
- **DCC:** `/ctcp MiBot chat`
- **Telnet:** `telnet IP_DEL_SERVIDOR 3333`, y luego tu nick y tu contraseña. Si usas firewall, abre el puerto: `ufw allow 3333/tcp`.

A partir de ahora arranca el bot sin `-m`: `./eggdrop eggdrop.conf`.

---

## Paso 5: Cuenta de Q para el bot

1. Desde tu cliente de IRC, cámbiate el nick por el nombre de cuenta que quieras para el bot (`/nick MiBot`, con el bot desconectado o usando otro nick) y regístrala:
   ```
   /msg Q HELLO tu@email.com tu@email.com
   ```
2. Q te manda la contraseña por email. Puedes cambiarla con:
   ```
   /msg Q@CServe.quakenet.org NEWPASS vieja nueva nueva
   ```
3. Vuelve a tu nick normal. Con **tu propia** cuenta de Q (necesitas `+n` o `+m` en el canal), da acceso al bot:
   ```
   /msg Q CHANLEV #tucanal MiBot +amo
   ```
   Repítelo en cada canal, también en el de staff.

---

## Paso 6: Instalar service.tcl

Elige **una** de estas opciones.

**A) ZIP de la release (recomendado):** descarga el último `.zip` de la [página de Releases](https://github.com/sauk1337/service.tcl/releases), súbelo al servidor y descomprímelo:

```sh
cd ~/eggdrop/scripts
unzip ~/service-*.zip            # crea scripts/service/
```

Para subirlo desde Windows, usa PowerShell (trae `scp`) o WinSCP / FileZilla (SFTP):

```powershell
scp service-6.1.0.zip eggdrop@IP_DEL_SERVIDOR:~/
```

**B) Git:**

```sh
cd ~/eggdrop/scripts
git clone https://github.com/sauk1337/service.tcl.git service
```

En los dos casos debe quedar así:

```
eggdrop/
├── eggdrop.conf
└── scripts/
    └── service/
        ├── service.tcl            ← el único archivo que se carga
        ├── service.conf.example
        ├── modules/
        └── docs/  tests/  tools/
```

---

## Paso 7: Configurar service.tcl

```sh
cd ~/eggdrop/scripts/service
cp service.conf.example service.conf
chmod 600 service.conf             # contiene la contraseña de Q
nano service.conf
```

Cambia como mínimo:

```tcl
variable homechan "#tucanal"
variable adminchan "#tucanal.staff"     ;# avisos de takeover, errores, informes
variable helpchan "#tucanal"

array set qauth {
	"user" "MiBot"                      ;# cuenta de Q del paso 5
	"pass" "la_contraseña_de_Q"
	"method" "challenge"
	"hidehost" "1"
	"waitjoin" "1"
	"timeout" "30"
}
```

El trigger de los comandos es `$` por defecto (`variable trigger`). Todo lo demás puede quedarse con su valor por defecto. El [manual](MANUAL.md) explica cada opción.

Opcional: comprueba que el script funciona con el Tcl del servidor. Tarda unos segundos:

```sh
tclsh tests/crypto.tcl   | tail -1
tclsh tests/smoke.tcl    | tail -2
tclsh tests/features.tcl | tail -1
```

Los tres deben terminar en `failures: 0`.

---

## Paso 8: Cargar el script

```sh
cd ~/eggdrop
echo 'source scripts/service/service.tcl' >> eggdrop.conf
```

> **¿Vienes del `service.tcl` antiguo de r0t3n (v40.x)?** Comenta su línea `source` en `eggdrop.conf` poniendo un `#` delante. No cargues nunca los dos a la vez. Tu userfile y tu chanfile siguen sirviendo.

Después reinicia el bot. En la partyline: `.restart`. La primera vez es mejor reiniciar que hacer `.rehash`, para que no quede nada de un script anterior en memoria.

---

## Paso 9: Comprobar que funciona

En el log (`tail -f ~/eggdrop/logs/*.log`) o en la partyline debe aparecer:

```
service.tcl - v6.1.0 - ... - 15 modules (...) - 101 commands - loaded in X ms
service.tcl - authenticated with Q as MiBot
```

`/whois MiBot` debe mostrar `MiBot.users.quakenet.org`, lo que significa que la IP está oculta.

Después, en IRC (cambia `$` por tu trigger):

| # | Haces | Resultado esperado |
|---|---|---|
| 1 | `$version`, `$help`, `$status` | Responde por notice. `status` muestra `bot auth: authed` |
| 2 | `$protect on`, `$takeover` | Muestra la configuración anti-takeover |
| 3 | Desde un **segundo cliente** con op pero sin acceso en el bot: `/mode #canal +i` | El bot quita el `+i`, y expulsa y banea a ese cliente |
| 4 | Desde ese cliente, quita el op a 3 personas seguidas | Aviso `TAKEOVER` en el canal de staff. Q RECOVER, TEMPBAN y CHANLEV, y bloqueo con `+im` |
| 5 | `$lockdown off` | Quita el `+im` |
| 6 | `$qban Nick 10m prueba`, `$qbanlist`, `$qunban #1` | Las respuestas de Q te llegan como `[Q] …` |
| 7 | `$saveop`, `.restart`, `$saveop list` | La lista sigue después del reinicio |
| 8 | `$enforcemodes +nt` y que un op ponga `-t` | El bot vuelve a poner `+t` |
| 9 | `$account TuNick` | Muestra tu cuenta de Q |

---

## Mantener el bot encendido

Eggdrop incluye `autobotchk`, que añade una tarea de cron para volver a arrancar el bot si se cae o si el servidor se reinicia:

```sh
cd ~/eggdrop
./scripts/autobotchk eggdrop.conf -dir ~/eggdrop -noemail
```

---

## Actualizar

- **Instalación desde una release:** cada pocas horas (`update(interval)`) el bot consulta GitHub y avisa en el canal de staff si hay una versión nueva. No instala nada por su cuenta: un owner global ejecuta `$update check` y luego `$update apply`. Cada archivo se verifica con SHA-256 contra `manifest.sha256`, los archivos antiguos se copian a `backup/` y `service.conf` nunca se toca. Si falla la copia, se restauran los archivos que ya se habían reemplazado.
- **Instalación con git:** `cd ~/eggdrop/scripts/service && git pull` y después `.restart`. (`update apply` no se ejecuta si la instalación es un clon de git.)

Después de actualizar, revisa `CHANGELOG.md` y `service.conf.example` por si hay opciones nuevas.

---

## Solución de problemas

| Problema | Qué revisar |
|---|---|
| `service.conf not found` | Te has saltado `cp service.conf.example service.conf` (paso 7). |
| `ERROR loading module '…'` | Copia esa línea y las siguientes del log y abre un issue. |
| No se autentica en Q | Usuario y contraseña en `service.conf`. Pasados `timeout` segundos el bot entra igualmente, pero sin `+x`. Mira en el log qué contestó Q. |
| La protección anti-takeover no usa Q | El bot necesita `+m` en la chanlev de Q (`/msg Q CHANLEV #canal`). |
| Los comandos no responden | El trigger es otro, o no tienes acceso: compruébalo con `$whoami`. Los owners son los usuarios con `+n` global. |
| `update check` dice que falta tls | `apt install tcl-tls` y luego `.restart`. |
| Detalle del último error de Tcl | `.tcl set errorInfo` en la partyline (necesita el comando `.tcl` activado en Eggdrop). |

**Volver al script antiguo:** comenta la línea `source` nueva, descomenta la antigua y haz `.restart`.

Errores y dudas: [issues de GitHub](https://github.com/sauk1337/service.tcl/issues).
