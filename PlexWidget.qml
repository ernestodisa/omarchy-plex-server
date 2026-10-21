import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "ernestodisa.plex"

  readonly property string unit: setting("unit", "plexmediaserver.service")
  readonly property int intervalSec: Math.max(3, setting("intervalSec", 10))
  readonly property int httpPort: Math.max(1, Math.min(65535, setting("httpPort", 32400)))
  readonly property string plexToken: setting("plexToken", "")
  readonly property string webUrl: "http://127.0.0.1:" + httpPort + "/web"

  property bool running: false
  property bool busy: false
  property string pendingAction: ""
  property string stateText: "unknown"
  property string menuChoice: ""
  property string scanNote: ""

  // Favicon-style mark: orange (#EBAF00, Plex brand) rounded square + white
  // chevron (assets/plex-chevron.svg, from CoreUI Icons' cib-plex, MIT).
  readonly property color plexOrange: "#EBAF00"
  readonly property color idleGray: "#57534e"

  Component {
    id: plexIcon

    Rectangle {
      anchors.fill: parent
      radius: height * 0.22
      color: root.running ? root.plexOrange : root.idleGray
      opacity: root.busy ? 0.55 : 1.0
      Behavior on color {
        ColorAnimation { duration: 250 }
      }

      Image {
        anchors.fill: parent
        anchors.margins: parent.height * 0.24
        source: Qt.resolvedUrl("./assets/plex-chevron.svg")
        fillMode: Image.Stretch
        asynchronous: false
      }
    }
  }

  function refresh() {
    if (!statusProc.running && !busy) statusProc.running = true
  }

  function control(action) {
    if (busy) return
    busy = true
    pendingAction = action
    ctrlProc.command = ["systemctl", action, unit]
    ctrlProc.running = true
  }

  function actionLabel(action) {
    if (action === "start") return "starting"
    if (action === "stop") return "stopping"
    if (action === "restart") return "restarting"
    return action
  }

  // Right-click menu (omarchy menu select). The chosen label lands on stdout;
  // exit code 0 means a row was picked, 1 means the menu was dismissed.
  function openMenu() {
    if (menuProc.running) return
    var opts = []
    if (root.running) {
      if (root.plexToken !== "") opts.push("Escanear librería")
      opts.push("Detener servidor")
      opts.push("Reiniciar servidor")
      opts.push("Abrir web")
    } else {
      opts.push("Iniciar servidor")
    }
    menuChoice = ""
    menuProc.command = ["omarchy-menu-select", "Plex Media Server"].concat(opts)
    menuProc.running = true
  }

  function dispatchMenu(choice) {
    if (choice === "Iniciar servidor") root.control("start")
    else if (choice === "Detener servidor") root.control("stop")
    else if (choice === "Reiniciar servidor") root.control("restart")
    else if (choice === "Escanear librería") root.scanLibrary()
    else if (choice === "Abrir web") Util.execArgv(["xdg-open", root.webUrl])
  }

  // POST /library/sections/all/refresh enqueues the scan and returns at once;
  // needs an X-Plex-Token (setting plexToken en shell.json) — the local API
  // answers 401 without it. No -f on purpose: %{http_code} is what we parse.
  function scanLibrary() {
    if (root.plexToken === "" || scanProc.running) return
    scanProc.running = true
  }

  function applyState(output) {
    var active = "unknown"
    var sub = "unknown"
    var lines = String(output || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var eq = line.indexOf("=")
      if (eq > 0) {
        if (line.slice(0, eq) === "ActiveState") active = line.slice(eq + 1)
        else if (line.slice(0, eq) === "SubState") sub = line.slice(eq + 1)
      }
    }
    running = active === "active"
    stateText = active + " (" + sub + ")"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "ernestodisa.plex"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: statusProc
    command: ["systemctl", "show", root.unit, "-p", "ActiveState,SubState", "--no-pager"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) root.stateText = "unavailable"
    }
  }

  Process {
    id: ctrlProc

    stdout: StdioCollector {
      waitForEnd: true
    }

    onExited: function(exitCode) {
      root.busy = false
      root.pendingAction = ""
      root.refresh()
    }
  }

  Process {
    id: menuProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.menuChoice = String(text || "").trim()
    }

    onExited: function(exitCode) {
      var choice = root.menuChoice
      root.menuChoice = ""
      if (exitCode === 0 && choice !== "") root.dispatchMenu(choice)
    }
  }

  Process {
    id: scanProc
    command: ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "8", "-X", "POST", "http://127.0.0.1:" + root.httpPort + "/library/sections/all/refresh?X-Plex-Token=" + root.plexToken]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var code = String(text || "").trim()
        root.scanNote = /^2/.test(code)
          ? "Escaneo de librería lanzado"
          : "Escaneo falló (HTTP " + (code === "" || code === "000" ? "sin respuesta" : code) + ")"
      }
    }

    onExited: scanNoteTimer.restart()
  }

  Timer {
    id: scanNoteTimer
    interval: 8000
    onTriggered: root.scanNote = ""
  }

  Timer {
    interval: root.intervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    iconComponent: plexIcon
    active: root.running
    tooltipText: root.busy
      ? "Plex Media Server: " + root.actionLabel(root.pendingAction) + "…"
      : root.running
        ? "Plex Media Server: " + root.stateText
          + (root.scanNote !== "" ? "\n" + root.scanNote : "")
          + "\nWeb: " + root.webUrl
          + (root.plexToken === ""
              ? "\nSin token: escaneo deshabilitado (plexToken en shell.json)"
              : "")
          + "\nClic: detener · Medio: reiniciar · Derecho: menú (escanear, detener, web)"
        : "Plex Media Server: detenido — clic para iniciar · Derecho: menú"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) root.control("restart")
      else if (mouseButton === Qt.RightButton) root.openMenu()
      else root.control(root.running ? "stop" : "start")
    }
  }
}
