# SSHuttleDeck

SSHuttleDeck is an Omarchy bar widget that launches SSHuttle SSH VPN tunnels
through SSH config aliases, Tailscale machines, or a custom host/IP and SSH
port.

Keywords: SSHuttle, SSH, VPN, tunnel, Tailscale, routing.

The panel shows SSHuttle's daemon state, primary-link throughput, and the
current public IP address. Link throughput is intentionally labeled as link
traffic: SSHuttle does not expose exact per-tunnel traffic counters. Opening
the panel requests public-IP and ISP information from `ipwho.is`.

## Requirements

- `sshuttle` on the local machine: `omarchy pkg add sshuttle`
- SSH access to the selected remote machine
- A Python interpreter on the remote machine
- A one-time graphical authorization to install the root-owned launcher

## Usage

Click `SSH-` in the bar, choose an SSH config alias, Tailscale machine, or
enter a custom endpoint. SSHuttleDeck uses Omarchy's graphical polkit prompt
to grant the local firewall privilege without opening a terminal.

Authenticate with the selected host in a terminal once before using it here,
so its host key is trusted. SSHuttleDeck uses a private key under `~/.ssh`
with no interactive passphrase; hosts requiring a remote password, agent-only
keys, `ProxyCommand`, or other executable SSH configuration are intentionally
not supported by the privileged launcher.

The route box accepts normal SSHuttle route syntax, including port-specific
routes such as `10.0.0.0/8:443` and `10.0.0.0/8:8000-9000`. Custom SSH ports
from 1 through 65535 are supported. SSH config aliases preserve their own
configured port and identity settings.

Right-click the bar button or use the Disconnect button to stop the current
SSHuttleDeck tunnel.

## Privileged Helper

The privileged launcher is installed outside the plugin directory so it cannot
be modified by user-level plugin code:

```sh
pkexec install -D -o root -g root -m 700 \
  ~/.config/omarchy/plugins/jaabell.sshuttledeck/sshuttledeck-root \
  /usr/local/libexec/sshuttledeck-root
```

Repeat this command after updating `sshuttledeck-root`. The helper stores its
state under `/run/sshuttledeck/<uid>`, never loads user SSH configuration as
root, and accepts only validated hosts, routes, ports, and private-key paths.
