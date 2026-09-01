import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "jaabell.sshuttledeck"
  ipcTarget: "jaabell.sshuttledeck"
  manageIpc: false

  property var sshHosts: []
  property var tailscaleHosts: []
  property string state: "Checking"
  property string connectedTarget: ""
  property string message: ""
  property string sshOutput: ""
  property string tailscaleOutput: ""
  property string statusOutput: ""
  property string linkOutput: ""
  property string publicIpOutput: ""
  property string launchOutput: ""
  property string launchError: ""
  property string resolveOutput: ""
  property string resolveError: ""
  property string requestedTarget: ""
  property string requestedPort: ""
  property string helperInstallOutput: ""
  property string helperInstallError: ""
  property bool rootHelperInstalled: false
  property string disconnectOutput: ""
  property string disconnectError: ""
  property bool sshHostsExpanded: false
  property bool tailscaleHostsExpanded: false
  property string publicIp: "Checking..."
  property string publicIsp: ""
  property string primaryInterface: ""
  property real downloadBps: 0
  property real uploadBps: 0
  property real previousRx: -1
  property real previousTx: -1
  property double previousLinkSampleMs: 0
  property double sessionStartedAtMs: 0
  property int sessionElapsedSec: 0
  property string sessionBaselineInterface: ""
  property real sessionBaselineRx: -1
  property real sessionBaselineTx: -1
  property real sessionDownloadTotal: 0
  property real sessionUploadTotal: 0
  property var binaryStreams: []
  property int phraseIndex: 0
  readonly property var activePhrases: [
    "Braiding packets",
    "Wiring bits",
    "Shuttling bytes",
    "Tuning the tunnel",
    "Encrypting traffic",
    "Polishing routes",
    "Sealing the wire",
    "Threading sockets",
    "Folding latency",
    "Whispering through SSH",
    "Herding datagrams",
    "Mapping the backroads",
    "Carrying secrets",
    "Splicing the uplink",
    "Dodging the open internet",
    "Packing the payload",
    "Handshaking quietly",
    "Bending the route table",
    "Keeping the bits warm"
  ]
  readonly property var inactivePhrases: [
    "Waiting for a route",
    "Watching the wire",
    "Tunnel on standby",
    "Looking for a gateway",
    "Keeping the deck clear",
    "No packets in flight",
    "Listening for a hostname",
    "Routes are taking a nap",
    "The wire is quiet",
    "Waiting on an SSH hop",
    "No tunnel to tend",
    "Holding the keys",
    "Watching the route table",
    "Parking the packets",
    "Gateway not selected",
    "Keeping the socket dry",
    "Idle at the terminal"
  ]

  readonly property string pluginDir: (Quickshell.env("HOME") || "") + "/.config/omarchy/plugins/" + moduleName
  readonly property string scriptPath: pluginDir + "/sshuttledeck"
  readonly property string rootHelperSourcePath: pluginDir + "/sshuttledeck-root"
  readonly property string rootHelperPath: "/usr/local/libexec/sshuttledeck-root"
  readonly property bool connected: state === "Connected"
  readonly property var currentPhrases: connected ? activePhrases : inactivePhrases
  readonly property string heroPhraseText: currentPhrases[phraseIndex % currentPhrases.length]
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") return root.bar.switchPanelFrom(root, direction)
    return false
  }

  function refresh() {
    if (!hostsProcess.running) {
      sshOutput = ""
      hostsProcess.running = true
    }
    if (!tailscaleProcess.running) {
      tailscaleOutput = ""
      tailscaleProcess.running = true
    }
    if (!statusProcess.running) {
      statusOutput = ""
      statusProcess.running = true
    }
    refreshTelemetry()
  }

  function refreshTelemetry() {
    if (!linkProcess.running) {
      linkOutput = ""
      linkProcess.running = true
    }
    if (root.opened && !publicIpProcess.running) {
      publicIpOutput = ""
      publicIpProcess.running = true
    }
  }

  function rateLabel(bytesPerSecond) {
    var value = Math.max(0, Number(bytesPerSecond) || 0)
    var units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
    var index = 0
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024
      index++
    }
    return (value >= 10 || index === 0 ? value.toFixed(0) : value.toFixed(1)) + " " + units[index]
  }

  function bytesLabel(bytes) {
    var value = Math.max(0, Number(bytes) || 0)
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var index = 0
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024
      index++
    }
    return (value >= 10 || index === 0 ? value.toFixed(0) : value.toFixed(1)) + " " + units[index]
  }

  function durationLabel(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var secs = total % 60
    if (hours > 0) return hours + "h " + String(minutes).padStart(2, "0") + "m"
    return minutes + "m " + String(secs).padStart(2, "0") + "s"
  }

  function parseLinkStats(text) {
    var fields = String(text || "").trim().split("\t")
    if (fields.length !== 3) return
    var rx = Number(fields[1])
    var tx = Number(fields[2])
    if (!isFinite(rx) || !isFinite(tx)) return
    var now = Date.now()
    if (previousLinkSampleMs > 0 && now > previousLinkSampleMs) {
      var elapsed = (now - previousLinkSampleMs) / 1000
      downloadBps = Math.max(0, (rx - previousRx) / elapsed)
      uploadBps = Math.max(0, (tx - previousTx) / elapsed)
    }
    primaryInterface = fields[0]
    if (sessionBaselineInterface === fields[0] && sessionBaselineRx >= 0 && sessionBaselineTx >= 0) {
      sessionDownloadTotal = Math.max(0, rx - sessionBaselineRx)
      sessionUploadTotal = Math.max(0, tx - sessionBaselineTx)
    } else if (connected && sessionBaselineRx < 0) {
      sessionBaselineInterface = fields[0]
      sessionBaselineRx = rx
      sessionBaselineTx = tx
      sessionDownloadTotal = 0
      sessionUploadTotal = 0
    }
    previousRx = rx
    previousTx = tx
    previousLinkSampleMs = now
  }

  function parsePublicIp(text) {
    var raw = String(text || "").trim()
    try {
      var payload = JSON.parse(raw)
      if (payload.success === false || !payload.ip) throw new Error("IP lookup failed")
      publicIp = String(payload.ip)
      publicIsp = String((payload.connection && (payload.connection.isp || payload.connection.org)) || "").substring(0, 120)
    } catch (error) {
      publicIp = raw !== "" && raw.length <= 64 ? raw : "Unavailable"
      publicIsp = ""
    }
  }

  function createBinaryStreams() {
    var streams = []
    for (var row = 0; row < 7; row++) {
      var groups = 7 + Math.floor(Math.random() * 15)
      var bits = ""
      for (var group = 0; group < groups; group++) {
        var length = 3 + Math.floor(Math.random() * 12)
        for (var bit = 0; bit < length; bit++) bits += Math.random() > 0.5 ? "1" : "0"
        bits += " "
      }
      streams.push({ bits: bits, y: Style.space(2) + row * Style.space(9), duration: 5600 + Math.floor(Math.random() * 8200) })
    }
    return streams
  }

  function parseSshHosts(text) {
    var result = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var alias = lines[i].trim()
      if (alias !== "") result.push({ address: alias, label: alias, detail: "SSH config alias" })
    }
    sshHosts = result
  }

  function parseTailscaleHosts(text) {
    var result = []
    try {
      var payload = JSON.parse(text)
      var peers = payload.Peer || {}
      for (var id in peers) {
        var peer = peers[id]
        var address = String(peer.DNSName || peer.HostName || "").replace(/\.$/, "")
        if (address === "" && peer.TailscaleIPs && peer.TailscaleIPs.length > 0) address = String(peer.TailscaleIPs[0])
        if (address === "") continue
        var label = String(peer.HostName || address)
        var ip = peer.TailscaleIPs && peer.TailscaleIPs.length > 0 ? String(peer.TailscaleIPs[0]) : ""
        result.push({ address: address, label: label, detail: ip, online: peer.Online === true })
      }
      result.sort(function(a, b) { return a.label.localeCompare(b.label) })
    } catch (error) {
      message = "Tailscale machines could not be read."
    }
    tailscaleHosts = result
  }

  function parseStatus(text) {
    var fields = String(text || "").trim().split("\t")
    var wasConnected = connected
    connectedTarget = fields.length > 1 ? fields[1] : ""
    state = fields[0] === "connected" ? "Connected" : "Disconnected"
    if (!connected) {
      sessionStartedAtMs = 0
      sessionElapsedSec = 0
      sessionBaselineInterface = ""
      sessionBaselineRx = -1
      sessionBaselineTx = -1
      sessionDownloadTotal = 0
      sessionUploadTotal = 0
      return
    }
    var startedSeconds = Number(fields[2])
    if (isFinite(startedSeconds) && startedSeconds > 0) sessionStartedAtMs = startedSeconds * 1000
    if (!wasConnected) {
      sessionBaselineInterface = ""
      sessionBaselineRx = -1
      sessionBaselineTx = -1
    }
    if (fields.length >= 6 && Number(fields[4]) >= 0 && Number(fields[5]) >= 0) {
      sessionBaselineInterface = String(fields[3] || "")
      sessionBaselineRx = Number(fields[4])
      sessionBaselineTx = Number(fields[5])
    }
    if (sessionStartedAtMs > 0) sessionElapsedSec = Math.max(0, Math.floor((Date.now() - sessionStartedAtMs) / 1000))
  }

  function launch(target, port) {
    var routes = routesField.text.trim()
    if (!rootHelperInstalled) {
      message = "Install the secure root helper before starting a tunnel."
      return
    }
    if (connected) {
      message = "A tunnel is already active through " + connectedTarget + "."
      return
    }
    if (target.trim() === "") {
      message = "Enter a host, IP address, or SSH alias."
      return
    }
    if (routes === "") {
      message = "Enter at least one route, such as 0/0."
      return
    }
    if (resolveProcess.running || launchProcess.running) return
    requestedTarget = target.trim()
    requestedPort = port.trim()
    resolveOutput = ""
    resolveError = ""
    message = "Resolving SSH settings for " + requestedTarget + "..."
    resolveProcess.command = [scriptPath, "resolve", requestedTarget, requestedPort]
    resolveProcess.running = true
  }

  function disconnect() {
    if (!rootHelperInstalled) {
      message = "Install the secure root helper before managing a tunnel."
      return
    }
    if (disconnectProcess.running) return
    message = "Requesting permission to disconnect..."
    disconnectOutput = ""
    disconnectError = ""
    disconnectProcess.command = ["pkexec", rootHelperPath, "stop"]
    disconnectProcess.running = true
  }

  function installRootHelper() {
    if (rootHelperInstallProcess.running) return
    helperInstallOutput = ""
    helperInstallError = ""
    message = "Authorize installation of the root-owned SSHuttleDeck helper..."
    rootHelperInstallProcess.command = [
      "pkexec", "/usr/bin/install", "-D", "-o", "root", "-g", "root", "-m", "700",
      rootHelperSourcePath, rootHelperPath
    ]
    rootHelperInstallProcess.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function stop(): string { root.disconnect(); return "ok" }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : Style.space(54)
    fixedHeight: vertical ? Style.space(54) : -1
    tooltipText: root.connected
      ? "SSHuttle tunnel active: " + root.connectedTarget + " | " + root.publicIp + (root.publicIsp !== "" ? " via " + root.publicIsp : "")
      : "SSHuttle tunnel disconnected"

    Rectangle {
      id: statusPill
      anchors.centerIn: parent
      width: parent.vertical ? Style.space(22) : Style.space(48)
      height: parent.vertical ? Style.space(48) : Style.space(22)
      radius: height / 2
      color: root.connected ? "#16a34a" : "#3f4854"
      border.width: root.connected ? 1 : 0
      border.color: root.connected ? "#86efac" : "transparent"

      Behavior on color { ColorAnimation { duration: 180 } }

      Item {
        anchors.fill: parent
        clip: true
        visible: root.connected

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(3)
          height: 1
          color: "#86efac"
          opacity: 0.35
        }

        Repeater {
          model: 3
          Rectangle {
            id: packet
            required property int index
            width: Style.space(10)
            height: Style.space(2)
            radius: height / 2
            x: -width
            y: statusPill.height - Style.space(5)
            color: "#f0fdf4"

            SequentialAnimation on x {
              running: root.connected
              loops: Animation.Infinite
              PropertyAction { target: packet; property: "x"; value: -packet.width }
              PauseAnimation { duration: 180 + index * 260 }
              NumberAnimation {
                to: statusPill.width + Style.space(2)
                duration: 720
                easing.type: Easing.InOutQuad
              }
              PauseAnimation { duration: 260 }
            }
          }
        }
      }

      Row {
        anchors.centerIn: parent
        spacing: Style.space(4)

        Rectangle {
          id: liveDot
          width: Style.space(7)
          height: width
          radius: width / 2
          color: root.connected ? "#dcfce7" : "#a6b0bd"

          SequentialAnimation on opacity {
            running: root.connected
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 850 }
            NumberAnimation { to: 1.0; duration: 850 }
          }
        }

        Text {
          text: "SSH"
          color: "#ffffff"
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && root.connected) root.disconnect()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: content
          width: parent.width
          spacing: Style.space(10)

          PanelHero {
            id: hero
            Layout.fillWidth: true
            title: "SSHuttleDeck"
            meta: root.connected
              ? root.heroPhraseText + " through " + root.connectedTarget
              : root.heroPhraseText
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Item {
                width: Style.space(40)
                height: width

                Rectangle {
                  anchors.centerIn: parent
                  width: Style.space(38)
                  height: width
                  radius: width / 2
                  color: root.connected ? "#14532d" : "#303946"
                  border.width: 1
                  border.color: root.connected ? "#4ade80" : root.muted
                }

                Rectangle {
                  id: tunnelPortal
                  anchors.centerIn: parent
                  width: Style.space(26)
                  height: width
                  radius: width / 2
                  color: "transparent"
                  border.width: 2
                  border.color: root.connected ? "#86efac" : root.muted

                  SequentialAnimation on scale {
                    running: root.connected
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.15; duration: 950; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 950; easing.type: Easing.InOutQuad }
                  }
                }

                Text {
                  anchors.centerIn: parent
                  text: ">_"
                  color: root.connected ? "#dcfce7" : root.foreground
                  font.family: "monospace"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }
            trailingControl: Component {
              Button {
                text: root.connected ? "Disconnect" : "Refresh"
                onClicked: root.connected ? root.disconnect() : root.refresh()
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            visible: !root.rootHelperInstalled
            implicitHeight: securitySetup.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: "#493617"
            border.width: 1
            border.color: "#fbbf24"

            ColumnLayout {
              id: securitySetup
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(12)
              spacing: Style.space(6)

              Text {
                Layout.fillWidth: true
                text: "SECURITY SETUP REQUIRED"
                color: "#fef3c7"
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                Layout.fillWidth: true
                text: "Install the immutable root-owned helper once before launching a VPN. The following password dialog authorizes only that installation."
                color: "#fde68a"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Button {
                text: rootHelperInstallProcess.running ? "Installing..." : "Install secure helper"
                enabled: !rootHelperInstallProcess.running
                onClicked: root.installRootHelper()
              }
            }
          }

          Rectangle {
            id: tunnelBeaconSurface
            Layout.fillWidth: true
            implicitHeight: Style.space(68)
            radius: Style.cornerRadius
            clip: true
            color: root.connected ? "#14532d" : "#303946"
            border.width: 1
            border.color: root.connected ? "#4ade80" : "#596575"

            Item {
              anchors.fill: parent
              visible: root.connected
              opacity: 0.3

              Repeater {
                model: root.binaryStreams

                Text {
                  id: bitstream
                  required property var modelData
                  y: modelData.y
                  x: -width
                  text: modelData.bits
                  color: "#dcfce7"
                  font.family: "monospace"
                  font.pixelSize: Style.space(7)

                  NumberAnimation on x {
                    running: root.connected
                    from: -bitstream.width
                    to: tunnelBeaconSurface.width
                    duration: modelData.duration
                    loops: Animation.Infinite
                    easing.type: Easing.Linear
                  }
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(14)
              spacing: Style.space(12)

              Item {
                id: beacon
                Layout.preferredWidth: Style.space(66)
                Layout.preferredHeight: Style.space(48)
                clip: true

                Repeater {
                  model: 2
                  Rectangle {
                    id: signalRing
                    required property int index
                    anchors.centerIn: parent
                    width: Style.space(24)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#bbf7d0"
                    opacity: root.connected ? 0.72 : 0
                    scale: 0.45

                    SequentialAnimation {
                      running: root.connected
                      loops: Animation.Infinite
                      PropertyAction { target: signalRing; property: "scale"; value: 0.45 }
                      PropertyAction { target: signalRing; property: "opacity"; value: 0.72 }
                      PauseAnimation { duration: index * 620 }
                      ParallelAnimation {
                        NumberAnimation { target: signalRing; property: "scale"; to: 1.8; duration: 1350; easing.type: Easing.OutQuad }
                        NumberAnimation { target: signalRing; property: "opacity"; to: 0; duration: 1350; easing.type: Easing.OutQuad }
                      }
                    }
                  }
                }

                Rectangle {
                  id: beaconCore
                  anchors.centerIn: parent
                  width: Style.space(28)
                  height: width
                  radius: width / 2
                  color: root.connected ? "#4ade80" : "#94a3b8"
                  border.width: root.connected ? 2 : 0
                  border.color: root.connected ? "#dcfce7" : "transparent"

                  SequentialAnimation on scale {
                    running: root.connected
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.12; duration: 760; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 760; easing.type: Easing.InOutQuad }
                  }

                  Text {
                    anchors.centerIn: parent
                    text: "SSH"
                    color: "#14532d"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                  Layout.fillWidth: true
                  text: root.connected ? "TUNNEL LIVE" : "TUNNEL DISCONNECTED"
                  color: root.connected ? "#dcfce7" : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  text: root.connected
                    ? "Routing configured traffic through " + root.connectedTarget
                    : "No SSHuttle routes are installed"
                  color: root.connected ? "#bbf7d0" : root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "LINK " + (root.primaryInterface !== "" ? root.primaryInterface : "...")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              Layout.fillWidth: true
              text: "down " + root.rateLabel(root.downloadBps) + " | up " + root.rateLabel(root.uploadBps)
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "SESSION " + (root.connected ? root.durationLabel(root.sessionElapsedSec) : "--")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              Layout.fillWidth: true
              text: root.connected
                ? "down " + root.bytesLabel(root.sessionDownloadTotal) + " | up " + root.bytesLabel(root.sessionUploadTotal)
                : "No link traffic recorded"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideRight
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "PUBLIC IP"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              Layout.fillWidth: true
              text: root.publicIp + (root.publicIsp !== "" ? "  |  " + root.publicIsp : "")
              textFormat: Text.PlainText
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
              elide: Text.ElideMiddle
            }
          }

          Text {
            Layout.fillWidth: true
            visible: root.message !== ""
            text: root.message
            textFormat: Text.PlainText
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

          PanelSectionHeader { text: "TUNNEL SETTINGS"; foreground: root.foreground; fontFamily: root.fontFamily }

          TextField {
            id: routesField
            Layout.fillWidth: true
            text: "0/0"
            placeholderText: "Routes, e.g. 10.0.0.0/8:443 0/0"
            selectByMouse: true
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            CheckBox { id: dnsCheck; text: "Tunnel DNS" }
            CheckBox { id: autoNetsCheck; text: "Discover remote routes" }
          }

          Text {
            Layout.fillWidth: true
            text: "Routes accept SSHuttle port selectors, including 10.0.0.0/8:443 and 10.0.0.0/8:8000-9000."
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

          Button {
            Layout.fillWidth: true
            text: (root.sshHostsExpanded ? "Hide" : "Show") + " SSH config hosts (" + root.sshHosts.length + ")"
            onClicked: root.sshHostsExpanded = !root.sshHostsExpanded
          }

          ColumnLayout {
            Layout.fillWidth: true
            visible: root.sshHostsExpanded
            spacing: Style.space(6)

            Text {
              Layout.fillWidth: true
              visible: root.sshHosts.length === 0
              text: "No aliases found in ~/.ssh/config or its Include files."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.sshHosts
              Button {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label + "    " + modelData.detail
                onClicked: root.launch(modelData.address, "")
              }
            }
          }

          Button {
            Layout.fillWidth: true
            text: (root.tailscaleHostsExpanded ? "Hide" : "Show") + " Tailscale machines (" + root.tailscaleHosts.length + ")"
            onClicked: root.tailscaleHostsExpanded = !root.tailscaleHostsExpanded
          }

          ColumnLayout {
            Layout.fillWidth: true
            visible: root.tailscaleHostsExpanded
            spacing: Style.space(6)

            RowLayout {
              Layout.fillWidth: true
              TextField {
                id: tailscalePortField
                Layout.preferredWidth: Style.space(110)
                text: "22"
                placeholderText: "SSH port"
                inputMethodHints: Qt.ImhDigitsOnly
                selectByMouse: true
              }
              Text {
                Layout.fillWidth: true
                text: "Port used for selected Tailscale machines"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            Text {
              Layout.fillWidth: true
              visible: root.tailscaleHosts.length === 0
              text: "No Tailscale machines found, or Tailscale is not running."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.tailscaleHosts
              Button {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label + (modelData.online ? "" : " (offline)") + (modelData.detail !== "" ? "    " + modelData.detail : "")
                onClicked: root.launch(modelData.address, tailscalePortField.text)
              }
            }
          }

          PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

          PanelSectionHeader { text: "CUSTOM ENDPOINT"; foreground: root.foreground; fontFamily: root.fontFamily }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            TextField {
              id: customHostField
              Layout.fillWidth: true
              placeholderText: "Host, IP, or user@host"
              selectByMouse: true
              onAccepted: root.launch(text, customPortField.text)
            }
            TextField {
              id: customPortField
              Layout.preferredWidth: Style.space(84)
              text: "22"
              placeholderText: "Port"
              inputMethodHints: Qt.ImhDigitsOnly
              selectByMouse: true
              onAccepted: root.launch(customHostField.text, text)
            }
            Button { text: "Launch"; onClicked: root.launch(customHostField.text, customPortField.text) }
          }

          Text {
            Layout.fillWidth: true
            text: "Ports from 1 to 65535 are supported. IPv6 endpoints are accepted with or without brackets."
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            Layout.fillWidth: true
            text: "A graphical authorization prompt grants the SSHuttle firewall privilege. Key-based SSH hosts should be loaded in your SSH agent. Right-click the bar button to disconnect."
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  Process {
    id: rootHelperCheckProcess
    command: ["test", "-e", root.rootHelperPath]
    onExited: function(exitCode) { root.rootHelperInstalled = exitCode === 0 }
  }

  Process {
    id: rootHelperInstallProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.helperInstallOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.helperInstallError = text }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        message = "Secure root helper installed."
        rootHelperCheckProcess.running = true
      } else {
        message = String(root.helperInstallError || root.helperInstallOutput || "Secure helper installation was denied or failed.").trim()
      }
    }
  }

  Process {
    id: hostsProcess
    command: [root.scriptPath, "hosts"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.sshOutput = text }
    onExited: function(exitCode) { root.parseSshHosts(root.sshOutput) }
  }

  Process {
    id: tailscaleProcess
    command: ["tailscale", "status", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.tailscaleOutput = text }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseTailscaleHosts(root.tailscaleOutput)
      else root.tailscaleHosts = []
    }
  }

  Process {
    id: statusProcess
    command: [root.scriptPath, "status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.statusOutput = text }
    onExited: function(exitCode) { root.parseStatus(root.statusOutput) }
  }

  Process {
    id: linkProcess
    command: [root.scriptPath, "link-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.linkOutput = text }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseLinkStats(root.linkOutput)
    }
  }

  Process {
    id: publicIpProcess
    command: [root.scriptPath, "public-ip"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.publicIpOutput = text }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parsePublicIp(root.publicIpOutput)
      else root.publicIp = "Unavailable"
    }
  }

  Process {
    id: resolveProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.resolveOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.resolveError = text }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        message = String(root.resolveError || root.resolveOutput || "Could not resolve SSH settings.").trim()
        return
      }
      var fields = String(root.resolveOutput || "").trim().split("\t")
      if (fields.length !== 4) {
        message = "SSH settings returned an invalid connection plan."
        return
      }
      launchOutput = ""
      launchError = ""
      message = "Requesting permission to start " + requestedTarget + "..."
      launchProcess.command = [
        "pkexec", rootHelperPath, "start", fields[0], fields[2], fields[1], fields[3], routesField.text.trim(),
        dnsCheck.checked ? "1" : "0", autoNetsCheck.checked ? "1" : "0"
      ]
      launchProcess.running = true
    }
  }

  Process {
    id: launchProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.launchOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.launchError = text }
    onExited: function(exitCode) {
      message = exitCode === 0 ? String(root.launchOutput || "Tunnel started.").trim()
        : String(root.launchError || root.launchOutput || "Tunnel launch was denied or failed.").trim()
      statusDelay.restart()
    }
  }

  Process {
    id: disconnectProcess
    command: []
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.disconnectOutput = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.disconnectError = text }
    onExited: function(exitCode) {
      message = exitCode === 0 ? String(root.disconnectOutput || "Tunnel stopped.").trim()
        : String(root.disconnectError || root.disconnectOutput || "Tunnel stop was denied or failed.").trim()
      statusDelay.restart()
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: if (!statusProcess.running) statusProcess.running = true
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!linkProcess.running) linkProcess.running = true
  }

  Timer {
    interval: 1000
    running: root.connected
    repeat: true
    onTriggered: {
      if (root.sessionStartedAtMs > 0)
        root.sessionElapsedSec = Math.max(0, Math.floor((Date.now() - root.sessionStartedAtMs) / 1000))
    }
  }

  Timer {
    interval: 60000
    running: root.opened
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!publicIpProcess.running) publicIpProcess.running = true
  }

  Timer {
    id: statusDelay
    interval: 800
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 2800
    running: root.opened
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: hero
      property: "metaOpacity"
      to: 0
      duration: 160
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.currentPhrases.length
    }
    PropertyAnimation {
      target: hero
      property: "metaOpacity"
      to: 1
      duration: 240
      easing.type: Easing.InQuad
    }
  }

  Component.onCompleted: {
    binaryStreams = createBinaryStreams()
    rootHelperCheckProcess.running = true
    refresh()
  }
}
