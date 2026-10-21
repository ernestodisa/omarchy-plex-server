# Plex Server — Omarchy bar widget

Status icon for the Omarchy bar showing the local Plex Media Server systemd
service, with server control and library scan. English below · Español al final.

| Input | Action |
|---|---|
| Left click | Start (stopped) / Stop (running) |
| Middle click | Restart |
| Right click | Menu: Scan library · Stop server · Restart server · Open web |

Starting or stopping a system unit may ask for your password (polkit).

The scan sends `POST /library/sections/all/refresh` and returns at once; the
server scans in the background. The result (launched or the failing HTTP code)
shows in the tooltip for 8 seconds.

## Install

```bash
omarchy plugin add https://github.com/ernestodisa/omarchy-plex-server.git --enable
```

## Removal

Delete the widget entry from `~/.config/omarchy/shell.json`, then:

```bash
omarchy plugin remove ernestodisa.plex
```

## Settings

Optional — set them on the widget entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "ernestodisa.plex", "settings": { "plexToken": "XXXXXXXXXXXXXXXXXXXX" } }
```

| Key | Default | Note |
|---|---|---|
| `unit` | `plexmediaserver.service` | systemd unit |
| `intervalSec` | `10` | status refresh interval |
| `httpPort` | `32400` | local API/web port |
| `plexToken` | `""` | X-Plex-Token; without it there is no scan (the local API answers 401) |

### Getting the token

1. In Plex Web: open any item → `…` → *Get Info* → *View XML*; the token is in
   the URL as `X-Plex-Token=…`.
2. Or via plex.tv: `curl -su email:password -H 'X-Plex-Client-Identifier: omarchy-bar' 'https://plex.tv/api/resources?includeHttps=1' | grep -o 'accessToken="[^"]*"' | head -1`

## External dependencies

`systemctl` (system units, with polkit), `curl`, `ip`, `xdg-open`, and
`omarchy-menu-select` (bundled with Omarchy). No root access; the plugin never
writes user configuration.

## License

MIT — see [LICENSE](LICENSE).

---

# Plex Server — widget de la barra Omarchy (español)

Ícono de estado para la barra de Omarchy con el servicio systemd de Plex Media
Server local, control del servidor y escaneo de librería.

| Entrada | Acción |
|---|---|
| Clic izquierdo | Iniciar (detenido) / Detener (activo) |
| Clic medio | Reiniciar |
| Clic derecho | Menú: Escanear librería · Detener servidor · Reiniciar servidor · Abrir web |

El escaneo manda `POST /library/sections/all/refresh` y devuelve al instante;
el servidor escanea en segundo plano. El resultado aparece 8 s en el tooltip.

## Instalación

```bash
omarchy plugin add https://github.com/ernestodisa/omarchy-plex-server.git --enable
```

## Desinstalación

Borra la entrada del widget de `~/.config/omarchy/shell.json` y corre:

```bash
omarchy plugin remove ernestodisa.plex
```

## Settings

Opcionales, en la entrada del widget en `~/.config/omarchy/shell.json`
(mismas claves que la tabla en inglés). El escaneo requiere `plexToken`;
se obtiene en Plex Web → `…` → Obtener información → Ver XML (sale en la URL).

Dependencias externas: `systemctl` (unidades de sistema, con polkit), `curl`,
`ip`, `xdg-open` y `omarchy-menu-select` (incluido en Omarchy). Sin acceso
root; el plugin nunca escribe tu configuración.
