# MacBook-Pro — nix-darwin Config

A declarative macOS setup built with nix-darwin and home-manager.

- **Host**: KokinoMacBook-Pro
- **Architecture**: aarch64-darwin (Apple Silicon)
- **Channel**: nixpkgs-25.05-darwin (stable)

> Comments in the Nix files and the detailed notes in [CLAUDE.md](CLAUDE.md) are written in Japanese.

## Quick start

```bash
# Apply the configuration
sudo darwin-rebuild switch --flake ~/.config/nix-darwin

# Alias (after the first apply)
rebuild
```

> Flakes only see files tracked by git. `git add` new files before applying.

**Policy**: this repository plus `rebuild` should always produce the same state, no matter how many times it runs (idempotent).
Settings that macOS does not allow to be automated are listed under [Manual setup](#manual-setup).

## Setting up a new Mac

```bash
# 1. Command line tools
xcode-select --install

# 2. Nix (official installer, multi-user)
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# 3. Homebrew (used for casks and App Store apps)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 4. Clone this repository
git clone https://github.com/knkch/macbook-nix.git ~/.config/nix-darwin

# 5. First apply (darwin-rebuild does not exist yet, so run it through nix run)
sudo nix --extra-experimental-features 'nix-command flakes' \
  run nix-darwin/nix-darwin-25.05#darwin-rebuild -- switch --flake ~/.config/nix-darwin
```

- If your host name is not `KokinoMacBook-Pro` or your user name is not `konkichi`, change `host` / `user` in `flake.nix`.
- After that, just run `rebuild`.
- Finally, go through [Manual setup](#manual-setup) from top to bottom and log out once.

## Layout

```
.
├── flake.nix              # inputs / outputs (user and host are defined once here)
├── flake.lock
├── CLAUDE.md              # detailed notes (Japanese)
├── modules/
│   ├── system.nix         # nix settings, users, PATH, system packages, macOS defaults
│   ├── homebrew.nix       # casks / brews / masApps / VS Code extensions / cleanup
│   ├── desktop.nix        # jankyborders, menubar-click-guard (imports sketchybar)
│   └── sketchybar/        # everything for sketchybar
│       ├── default.nix    #   service, bar settings, protected-reader agent
│       ├── shared.nix     #   shared parts (focus mode list `focusModes`, etc.)
│       ├── lib.nix        #   shell functions loaded by every plugin
│       ├── action.nix     #   what happens when a menu row is clicked
│       ├── doctor.nix     #   sketchybar-doctor (health check)
│       └── plugins/       #   one file per bar item
├── pkgs/
│   ├── ax-agent/          # agent that performs accessibility actions on behalf of sketchybar (Objective-C)
│   ├── menubar-click-guard/  # agent that keeps top-edge clicks on sketchybar (C)
│   ├── calendar/          # calendar images for the clock menu (render.py) and event editing (event.js)
│   ├── focus-shortcuts/   # command that prepares Shortcuts for switching focus modes
│   ├── protected-reader/  # agent that reads notification / focus state (the only one with Full Disk Access)
│   ├── runcat/            # pixel art for the running cat
│   └── ymuse/             # macOS fixes for the ymuse MPD client
└── home/
    ├── default.nix        # user info, dotfiles, imports
    ├── packages.nix       # CLI / infrastructure / cloud tools
    ├── gpg.nix            # GnuPG and gpg-agent (pinentry-mac, also the SSH agent)
    ├── security.nix       # security tools (my.security.enable)
    ├── shell.nix          # zsh, starship, atuin, zoxide, fzf, bat, eza, lazygit, direnv
    ├── git.nix            # git + delta, signed commits
    ├── nixvim.nix         # Neovim (nixvim)
    ├── desktop.nix        # AeroSpace, Ghostty
    ├── music.nix          # mpd, rmpc, mpc
    ├── rmpc/              # rmpc config and theme (tokyonight)
    ├── yazi.nix           # Yazi (video and audio open in mpv)
    └── vscode.nix         # VS Code display language
```

## What is managed where

| Kind | How |
|------|-----|
| System packages | `environment.systemPackages` (modules/system.nix) |
| User tools | `home.packages` / `programs.*` (home/) |
| GUI apps, Claude Code | `homebrew.casks` (modules/homebrew.nix) |
| App Store apps | `homebrew.masApps` (modules/homebrew.nix) |
| VS Code and extensions | cask + Brewfile `vscode` lines (modules/homebrew.nix) |
| Background services | `services.sketchybar`, protected-reader, ax-agent (modules/sketchybar/), `services.jankyborders`, menubar-click-guard (modules/desktop.nix), mpd (home/music.nix), gpg-agent (home/gpg.nix) |
| VS Code `settings.json` | not managed by Nix; VS Code writes it directly |
| Focus mode shortcuts | generated from `focusModes` (modules/sketchybar/shared.nix), imported with `focus-shortcuts` |

> Apps missing from the Brewfile are uninstalled on every rebuild (`brew bundle cleanup`).

## Common tasks

| Task | How |
|------|-----|
| Apply changes | `rebuild` |
| Add a CLI tool | add it to `home/packages.nix` → `rebuild` |
| Add a GUI app | add it to `casks` in `modules/homebrew.nix` → `rebuild` |
| Bring a manually installed app under cask management | `brew install --cask --adopt <cask>` → add to `casks` → `rebuild` (without adopting first, the rebuild fails because the app already exists) |
| Add an App Store app | add `"Name" = ID;` to `masApps` (find the ID with `mas search Name`) → `rebuild` |
| Add a VS Code extension | add it to `vscodeExtensions` in `modules/homebrew.nix` → `rebuild` |
| Update Claude Code | `brew upgrade --cask claude-code` (rebuild normally updates it too; see the note below) |
| Remove the security tools | set `my.security.enable = false;` in `home/default.nix` |
| Created a new .nix file | `git add` it, then `rebuild` |
| Roll back | find the commit with `git log` → `git checkout <commit>` → `rebuild` |
| Update Nix packages | `nix flake update` → `rebuild` (versions are pinned in `flake.lock`) |
| Add a focus mode | see [Focus modes](#focus-modes-sketchybar-notification-menu) |
| Focus mode shortcuts are gone | `focus-shortcuts` → press "Add Shortcut" |
| macOS was updated / part of the bar stopped working | `sketchybar-doctor` (shows what is broken and how to fix it) |

> ⚠️ **The Brewfile is the single source of truth for Homebrew.** Anything installed with a plain `brew install`
> is removed on the next `rebuild` unless it is also listed in `modules/homebrew.nix`.

## Main tools

### Desktop

| Tool | Managed by | Notes |
|------|------------|-------|
| AeroSpace | cask + `programs.aerospace` | tiling window manager, starts at login |
| Sketchybar | `services.sketchybar` (patched build) | left: Apple menu, workspaces 1–9, front app (click for its menus) / left of the notch: now playing, right of the notch: a cat that runs with CPU load / right: camera (only while in use), VPN, network, Bluetooth, input source, volume, battery, clock, notifications (click any item for a menu; details in CLAUDE.md) |
| ax-agent | launchd user agent | performs the accessibility actions sketchybar needs (needs Accessibility; sketchybar itself gets none) |
| menubar-click-guard | launchd user agent | stops clicks on the top edge and corners from reaching the standard menu bar (needs Accessibility) |
| jankyborders | `services.jankyborders` | border around the active window |
| Ghostty | `xdg.configFile` | terminal (Hack Nerd Font / tokyonight) |
| macSKK | cask + dotfile | Japanese input method (SKK-JISYO.L) |

- The macOS menu bar always stays visible and sketchybar (same height 33, opaque) covers it, so notification banners appear below the bar. AeroSpace gaps are 3.
- Clock menu: a month calendar drawn as images (holidays, event count badges), click a day to see its events, add / edit / delete events with alerts (Google / Outlook calendars sync once added under Internet Accounts).
- Network menu: nearby Wi-Fi networks, plus "iPhone のテザリング…" (iPhone tethering), which opens the standard Wi-Fi menu because Instant Hotspot does not show up in a normal scan.
- Menus stay open for 0.6 s after the mouse leaves them, so a small slip does not close them.
- "Displays have separate Spaces" is off (recommended by AeroSpace; needs a logout to take effect).
- Dock auto-hides, Spaces are not rearranged automatically, Mission Control groups windows by app.
- Stage Manager, click-wallpaper-to-show-desktop and macOS window tiling (edge drag / Option-drag) are off because they conflict with AeroSpace.
- One-time manual steps: give AeroSpace Accessibility access and reduce the standard Spaces to one per display.

#### Focus modes (sketchybar notification menu)

The notification (bell) menu lists each focus mode on its own row and toggles it (● and green when on).
Switching runs the Shortcuts "集中モード: <name> オン / オフ" (focus mode on / off).

| Task | How |
|------|-----|
| Check that all shortcuts exist | `focus-shortcuts --check` |
| Import missing shortcuts | `focus-shortcuts` (or "ショートカットを追加…" in the notification menu) → press "Add Shortcut" |
| Add a focus mode | ① add it in System Settings > Focus → ② add one line (name, identifier, label) to `focusModes` in `modules/sketchybar/shared.nix` → ③ `rebuild` → ④ `focus-shortcuts` |
| Remove a focus mode | delete it from `focusModes` and `rebuild` → delete its two shortcuts in the Shortcuts app |

- Currently registered: Do Not Disturb, Sleep and Work. The shortcuts live in the "SketchyBar" folder.
- Identifiers of the built-in modes, and how to find the identifier of a custom mode, are in the "集中モード" section of CLAUDE.md.
- Every `rebuild` checks that the shortcuts exist and prints a message if any are missing (it never opens the import screen by itself).

#### AeroSpace keys

| Key | Action |
|-----|--------|
| `alt-h/j/k/l` | move focus |
| `alt-shift-h/j/k/l` | move window |
| `alt-1`–`9` | switch workspace |
| `alt-shift-1`–`9` | send window to workspace |
| `alt-f` / `alt-shift-f` | toggle fullscreen / floating |
| `alt-/` / `alt-,` | tiles / accordion layout |
| `alt-tab` / `alt-shift-tab` | move workspace to next monitor / focus across monitors |

### Shell

| Key / command | Action |
|---------------|--------|
| `Ctrl-R` | history search (atuin) |
| `Ctrl-T` / `Alt-C` | file / directory search (fzf) |
| `z <dir>` | jump to a frequent directory (zoxide) |
| `ll` / `ls` | eza |
| `cat` | bat |
| `lg` | lazygit |
| `vlc-bd` | start VLC with OpenJDK 17 for Blu-ray menus |
| `music` | open rmpc (music player UI) |
| `youtube` | youtube-tui (YouTube UI; playback in mpv) |
| `yy` | Yazi file manager; on exit the shell moves to that folder. Photos preview with Enter, audio plays in the terminal, video opens in mpv (`O` lets you play inside the terminal) |

### Music (`home/music.nix`)

| Tool | Managed by | Notes |
|------|------------|-------|
| mpd | `services.mpd` | the player. Plays `~/Music/MyLibrary` through CoreAudio, starts at login |
| rmpc | `programs.rmpc` | TUI (`music`). Album art (Kitty protocol), tokyonight theme, a key hint row under the header (`p` play/pause, `s` stop, `<` `>` prev/next, `b` `f` seek, `,` `.` volume, `x` random, `z` repeat, `~` all keys). Click the header to play/pause, scroll for volume, click the progress bar to seek |
| mpc | `home.packages` | `mpc toggle` / `next` / `prev` / `update` |
| YouTube tracks | rmpc `addyt` | `rmpc addyt <URL>` (`:addyt <URL>` inside rmpc) downloads the audio and adds it to the queue; files go to `~/.cache/rmpc/youtube/` |
| ymuse | `home.packages` (`pkgs/ymuse`) | free GUI for the same mpd. Run `ymuse` or open it from the sketchybar music menu |

> Run `mpc update` after adding music. For careful listening use JRiver Media Center (bit-perfect, automatic sample rate switching).

### Development

| Tool | Managed by | Notes |
|------|------------|-------|
| Claude Code | cask `claude-code` | kept up to date by rebuild (the nixpkgs version lags behind) |
| VS Code | cask + Brewfile `vscode` lines | extensions come from the Marketplace (including Pylance) |
| Nixvim | `programs.nixvim` | LSP / treesitter / telescope |
| OrbStack | cask | Docker / Linux VMs |
| Starship | `programs.starship` | prompt (Nerd Font symbols) |
| direnv + nix-direnv | `programs.direnv` | put `use flake` in `.envrc` |

### Infrastructure

| Tool | Notes |
|------|-------|
| kubectl / helm / k9s | Kubernetes |
| terraform / ansible | IaC / configuration management |
| awscli2 / google-cloud-sdk | cloud CLIs |
| nmap / mtr / iperf3 | network diagnostics |
| openlens | Kubernetes GUI |
| tableplus | database GUI |
| wireshark-app | packet analyzer (ChmodBPF installed) |

### YubiKey and GPG

| Tool | Installed by | Notes |
|------|--------------|-------|
| ykman (yubikey-manager) | `home/packages.nix` | manage PINs, FIDO2, PIV and OATH (`ykman info`) |
| Yubico Authenticator | cask | show and manage TOTP codes |
| paperkey | `home/packages.nix` | export a GPG secret key for a paper backup |
| GnuPG (gpg) | `home/gpg.nix` | signing, encryption and SSH (gpg-agent doubles as the SSH agent). PINs are entered in pinentry-mac. Git commits are signed with the YubiKey. Check with `gpg --card-status` |

- The YubiKey holds the signing, encryption and authentication subkeys; the primary key is kept offline.
- Every signature and SSH login needs a touch on the YubiKey (it blinks; there is no on-screen prompt after the first PIN entry).
- macOS always sets `SSH_AUTH_SOCK` to its own ssh-agent, so zsh overrides it with the gpg-agent socket. GUI apps keep using the macOS ssh-agent.

### Security (`home/security.nix`)

| Tool | Notes |
|------|-------|
| nuclei / nikto / gobuster | vulnerability scanning |
| burp-suite / caido / proxyman | web proxies |
| metasploit | exploitation framework |
| ghidra / radare2 | reverse engineering |
| hashcat / john | password cracking |
| maltego | OSINT GUI |

### VPN / App Store

| Tool | Notes |
|------|-------|
| WireGuard / Tailscale | VPN (App Store versions) |
| Slack / Windows App / Microsoft Excel / Brother iPrint&Scan | App Store versions |

### Apps outside Nix and Homebrew

Kept as manual installs (reasons in [CLAUDE.md](CLAUDE.md)):
Parallels Desktop 26 / VMware Fusion 13 / MakeMKV 2.0 / e-Gov electronic application app /
Brother driver (Push Scan Tool) / Pioneer DJ FwUpdateManager (bundled with rekordbox)

> Intel-only (needs Rosetta): Maltego / the e-Gov app / the Brother driver's background process

## Manual setup

Things `rebuild` cannot do because macOS does not allow them to be configured from outside. Do these on a new Mac or after reinstalling.
Reasons and paths are in the "冪等性と手作業の設定" section of [CLAUDE.md](CLAUDE.md).

- [ ] Turn on **FileVault** (System Settings > Privacy & Security; disk encryption cannot be automated)
- [ ] Give protected-reader **Full Disk Access** (notification list and focus state). Do not give it to sketchybar
- [ ] Give ax-agent **Accessibility** (app menus, Notification Center, video effects, Wi-Fi menu, camera detection, input source, emoji). Do not give it to sketchybar
- [ ] Allow sketchybar **Bluetooth** and **Calendars** (accept the prompts on first use)
- [ ] Give menubar-click-guard and AeroSpace **Accessibility**
- [ ] Reduce the standard Spaces to one per display and log out
- [ ] Add Do Not Disturb, Sleep and Work in System Settings > Focus → import with `focus-shortcuts` → move them to the "SketchyBar" folder
- [ ] For Blu-ray playback, put `keydb.cfg` in `~/Library/Preferences/aacs/`
- [ ] Install the apps outside Nix and Homebrew (list above)
- [ ] For GPG / SSH, insert the YubiKey, import the public key and run `gpg --card-status`

- [ ] Finally run `sketchybar-doctor` and check that everything shows ✓

> The firewall and stealth mode are turned on automatically by `rebuild`.

> sketchybar, menubar-click-guard, protected-reader and ax-agent need their permissions granted again whenever their
> location (nix store path) changes. Normal configuration changes do not change it; `nix flake update` can. `sketchybar-doctor` tells you.
> Old entries stay in the Privacy & Security lists, so clean them up now and then.
> If sketchybar appears in the Automation list, run `tccutil reset AppleEvents` (it cannot be removed from the UI).

> Homebrew normally upgrades everything on each `rebuild` (to keep Claude Code and others current), so Homebrew app versions depend on the day you run it.
> As of 2026-11-11 this upgrade is temporarily off (`onActivation.upgrade = false`) because the media-center cask has a checksum mismatch.

## Changelog

### 2026-11-11 YubiKey, GPG and menu fixes

- **Privacy**: git now uses the GitHub noreply address, and the history was rewritten to remove the old address
- **YubiKey / GPG**: ykman, Yubico Authenticator, paperkey and GnuPG. gpg-agent is the SSH agent, and commits are signed with the YubiKey
- **sketchybar**: "iPhone tethering" in the Wi-Fi menu (opens the standard Wi-Fi menu through ax-agent); menus wait 0.6 s before closing
- **Homebrew**: upgrades on rebuild are paused until the media-center checksum is fixed upstream

### 2026-10-30 Media, app menus, split permissions

- **Media**: `youtube` (youtube-tui 0.9.4, standard features only), Yazi under home-manager (`yy`; video and audio in mpv, photos in Preview).
  Key hints in the rmpc header. Replaced Rigelian (paid) with the free GUI **ymuse** (patched for macOS in `pkgs/ymuse`)
- **sketchybar**: click the front app name to open that app's menus (File, Edit…); menu search (⌘⇧/)
- **Permissions**: accessibility actions moved to **ax-agent**. sketchybar has no Accessibility, Full Disk Access or Automation
- **Hardening**: the firewall and stealth mode are turned on by `rebuild`; `sketchybar-doctor` also checks the firewall and FileVault

### 2026-10-29 Cleanup and idempotency

- **Cleanup**: removed unused sketchybar code (camera list, monospaced rows, unused variables) and merged duplicate AppleScript. Removed `font-hackgen` (unused) and `xxd` (duplicates macOS)
- **Focus modes**: one list, `focusModes` (now in modules/sketchybar/shared.nix). Added `focus-shortcuts` and a check on `rebuild`
- **Notification menu**: moved "Notification settings…" under the notifications and added "Add shortcuts…"
- **Docs**: setup steps for a new Mac and the list of manual settings
- **Structure**: split sketchybar into `modules/sketchybar/` (one file per item); the generated scripts are identical
- **Permissions**: added `protected-reader` so sketchybar no longer needs Full Disk Access; the notification badge updates almost instantly
- **Health check**: added `sketchybar-doctor` and a list of things a macOS update can break (in CLAUDE.md)

### 2026-10-29 sketchybar and music

- **sketchybar**: re-enabled with items that mirror the standard menu bar (Apple menu, network / nearby Wi-Fi, Bluetooth, VPN, volume slider, battery and power mode, input source, camera, notifications and focus modes). Menus have row highlights and a frosted look
- **sketchybar**: patched build drawn above the menu bar; height 33, opaque, notch width 186. The standard menu bar stays visible underneath, so notifications appear below the bar
- **menubar-click-guard**: new agent that keeps clicks on the top edge and corners from reaching the standard menu bar
- **Clock menu**: calendar drawn as images (holidays, event badges, day selection), add / edit / delete events with alerts, shortcut to calendar accounts. Added `ical-buddy` from Homebrew
- **Music**: mpd + rmpc + mpc (`home/music.nix`), rmpc theme, Rigelian (App Store). Now playing left of the notch, a CPU-driven running cat right of it
- **AeroSpace**: gaps of 3, normal windows always tile, only small transient windows float
- **Brother LOGINserver** (Intel-only): outside Nix; its plist was removed from `/Library/LaunchAgents` to stop it starting

### 2026-10-29 macOS settings for AeroSpace

- **sketchybar**: disabled (config kept). Menu bar back to normal, AeroSpace top gap 37 → 5
- **macOS defaults**: Dock auto-hide and `expose-group-apps`; WindowManager features (Stage Manager, built-in tiling, etc.) disabled through the proper options
- **Homebrew**: added `zoom`; adopted the manually installed JRiver Media Center as `media-center`
- **AeroSpace**: the sketchybar hook (`exec-on-workspace-change`) follows `services.sketchybar.enable`, so it is not called when sketchybar is off
- **Survey**: listed the Intel-only apps and the apps outside Nix

### 2026-10-20 Refactoring

- **Claude Code**: dropped the nixpkgs version (old and not updated) in favor of the cask. `/opt/homebrew/bin` is added to PATH through `environment.systemPath`
- **sketchybar**: filled in the empty config and started it with nix-darwin's `services.sketchybar`
- **jankyborders**: moved from a home-manager launchd definition to `services.jankyborders`
- **AeroSpace**: config generated by `programs.aerospace`, starts at login, fixed the `spans-displays` setting
- **VS Code**: removed the duplicate Nix and cask installs in favor of the cask; extensions managed by Homebrew
- **OrbStack**: moved from Nix to a cask
- **Homebrew**: removed duplicate trusted casks, `wireshark` → `wireshark-app`, automatic `brew bundle cleanup`, added App Store apps (Windows App / Excel / Brother)
- **zsh**: removed the double compinit and per-start kubectl / helm completion generation (faster startup), `Ctrl-R` is atuin, fixed `vlc-bd`
- **Structure**: user name defined once in `flake.nix`, security tools split into `home/security.nix`, started tracking with git

See [CLAUDE.md](CLAUDE.md) for details (Japanese).
