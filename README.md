# Tunneler 1.1.0

Tunneler is a polished Linux VPN connection assistant in the same simple, guided spirit as Uppy. It uses NetworkManager and maintained distribution plugins to install protocol support, create or import profiles, connect, test the complete path, diagnose failures, and apply a small set of reversible client-side repairs.

The interface uses Tunneler's dark palette on every desktop. Profile refreshes run through a main-thread result queue with a 45-second watchdog, so a failed or unresponsive NetworkManager command cannot leave the application permanently busy.

All fields start blank. Field hints use reserved examples such as `vpn.example.com`, `10.20.0.0/24`, and `internal.example`; Tunneler contains no personal network defaults.

## Finished AppImage requirements

Someone downloading only the finished AppImage does **not** need Python, Tk, Tcl, `squashfs-tools`, `kdialog`, `zenity`, `fuse2`/`libfuse2`, a compiler, or the source tree. Python and Tk/Tcl are bundled. The built-in dark file browser is also bundled; Tunneler uses KDE or GTK's native picker when one is already available, but does not require either one.

Tunneler's AppImage defaults to the AppImage runtime's built-in extract-and-run path. It temporarily extracts itself, starts Tunneler, then cleans up when the application closes. This avoids the usual FUSE mounting requirement at the cost of slightly slower startup and about 45 MiB of temporary free space while it is running.

NetworkManager is a system service rather than an application library. Tunneler detects missing NetworkManager/protocol packages and can install the correct packages through the distribution package manager after the user approves the Polkit prompt. Automatic installation supports Arch/CachyOS, Fedora/Nobara, Debian/Ubuntu and openSUSE families.

`tk` is required only when running or building directly from the source tree. `squashfs-tools` is no longer installed or required by Tunneler's build helper; `appimagetool` carries the packaging support it needs.

## Supported VPN types

| Protocol | Setup | Notes |
| --- | --- | --- |
| WireGuard | Import `.conf` or manual | Recommended for a new home or small-business server. |
| OpenVPN | Import `.ovpn` | Import is required because certificates and TLS settings should come from the server. |
| L2TP/IPsec | Manual | Useful for legacy or embedded servers; credentials and PSK are requested at connection time. |
| IKEv2/IPsec | Manual EAP | Uses the NetworkManager strongSwan plugin. |
| OpenConnect | Manual | Supports AnyConnect-compatible, GlobalProtect, Pulse/Juniper, F5 and Fortinet modes. |

PPTP is intentionally unsupported because it is obsolete and insecure. Tunneler does not implement cryptography or tunnels itself.

## Discovery limits

Tunneler can use an imported profile, DNS SRV records, local mDNS announcements, the current gateway and already-known neighbour devices. It checks likely HTTPS/OpenConnect and TCP OpenVPN listeners without sweeping the entire subnet.

WireGuard, L2TP and IKEv2 normally use UDP and do not identify themselves to an unauthenticated probe. No client can reliably discover a remote private VPN server with no hostname, IP, configuration or local advertisement. For those protocols, an exported config, QR-derived values, or the server address is required. Tunneler labels probe results as hints rather than claiming certainty.

## Diagnostics and safe repairs

Tunneler checks:

- NetworkManager installation and state.
- Profile installation and active state.
- VPN endpoint DNS and the pre-tunnel route to it.
- Local and remote subnet overlap.
- Expected private-network routes.
- Split-DNS configuration and an optional internal hostname.
- Optional ICMP and TCP service reachability.
- Recent WireGuard handshake age.
- A likely WireGuard MTU black hole.
- Recent NetworkManager signatures for bad credentials, missing plugins, IPsec proposal mismatch and negotiation timeouts.

Safe automatic repairs are limited to reloading or reconnecting a profile, restoring its declared routes or DNS, and reducing WireGuard MTU to 1380 after a specific small-packet-pass/large-packet-fail test. Tunneler never edits a router, VPN server, firewall, port forward or remote subnet automatically.

## Security decisions

- Commands use argument arrays; shell interpolation is not used.
- Passwords and PSKs never appear in process arguments or Tunneler logs.
- Connection secrets use a mode-`0600` temporary NetworkManager password file that is overwritten and removed after use.
- Remembering credentials is opt-in and uses the desktop Secret Service through `secret-tool` when available.
- Logs are mode `0600`, rotated, and filtered for passwords, PSKs and WireGuard keys.
- Imported configs are capped at 2 MiB.
- WireGuard command hooks (`PreUp`, `PostUp`, `PreDown`, `PostDown`) are blocked.
- OpenVPN executable scripts, plugins, management sockets and external password files are blocked.
- Referenced OpenVPN certificates and keys are copied to private persistent storage so moving the original download does not break the profile.
- Privileged package installation accepts only a fixed protocol enum and fixed package lists.

## Run from source

```bash
chmod +x run-from-source.sh test.sh packaging/*.sh
./run-from-source.sh
```

Python 3 with Tk is required only for this source workflow. NetworkManager is required to create or connect profiles.

## Test and build

```bash
./test.sh
./packaging/install-build-deps.sh
./packaging/build-appimage.sh
```

The AppImage and SHA-256 file are written to `dist/`. The builder uses a pinned PyInstaller version, downloads `appimagetool` from its official release only when unavailable, bundles Python/Tk/Tcl, enables FUSE-free extract-and-run by default, and runs a post-build `--version` test with the normal launch command.

For broader glibc compatibility, build inside Ubuntu 22.04 with Podman or Docker:

```bash
./packaging/build-portable.sh
```

Install the built AppImage for the current user with:

```bash
./packaging/install-appimage.sh
```

## First connection

1. Export a client configuration from the VPN server when possible.
2. Open **Add VPN → Import config**, choose the file and import it.
3. If Tunneler reports missing protocol support, approve installation of the distribution packages.
4. Connect, provide credentials if requested, and let Tunneler run diagnostics.
5. For a stronger end-to-end test than ping, add an internal hostname and TCP port to a manually created profile.

### Export a WireGuard client from UniFi

1. Open **UniFi Network → Settings → VPN → VPN Server**.
2. Create or open a **WireGuard** VPN server.
3. Choose **Add Client**, give this laptop its own client name, and save it.
4. Download that client's configuration file. Some Network versions put the download action in the client row's menu.
5. In Tunneler, open **Add VPN → Import config**, choose the `.conf` file, then select **Inspect and import**.

Create a separate client configuration for every device. Treat it like a password because it contains that client's private key. A direct WireGuard server normally requires a public WAN address; if the UniFi gateway is behind another router, forward the configured UDP port (51820 by default) to the gateway.

## Known server-side limits

Tunneler cannot create server users or peers, export certificates, open a WAN port, repair NAT/firewall rules, select compatible IPsec proposals on the server, or fix a public DNS record. It identifies the likely problem class and explains the server-side item to check.

## Licence

MIT. See `LICENSE`.
