# SSHuttleDeck

SSHuttleDeck is an Omarchy bar widget that launches SSHuttle SSH VPN tunnels
through SSH config aliases, Tailscale machines, or a custom host/IP and SSH
port.

Keywords: SSHuttle, SSH, VPN, tunnel, Tailscale, routing.

The panel shows SSHuttle's daemon state, primary-link throughput, and the
current public IP address. Link throughput is intentionally labeled as link
traffic: SSHuttle does not expose exact per-tunnel traffic counters.

## Requirements

- `sshuttle` on the local machine: `omarchy pkg add sshuttle`
- SSH access to the selected remote machine
- A Python interpreter on the remote machine
- Permission to use local `sudo` when SSHuttle installs its firewall rules

## Usage

Click `SSH-` in the bar, choose an SSH config alias, Tailscale machine, or
enter a custom endpoint. SSHuttleDeck uses Omarchy's graphical polkit prompt
to grant the local firewall privilege without opening a terminal. It preserves
the active user's SSH config and SSH agent socket for key-based authentication.

Authenticate with the selected host in a terminal once before using it here,
so its host key is trusted and its key is loaded into your SSH agent. Hosts
that require an interactive remote password or key passphrase are not suitable
for the non-terminal launcher.

The route box accepts normal SSHuttle route syntax, including port-specific
routes such as `10.0.0.0/8:443` and `10.0.0.0/8:8000-9000`. Custom SSH ports
from 1 through 65535 are supported. SSH config aliases preserve their own
configured port and identity settings.

Right-click the bar button or use the Disconnect button to stop the current
SSHuttleDeck tunnel.
