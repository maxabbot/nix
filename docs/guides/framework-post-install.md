# Framework post-install tests

Everything below was configured before the machine existed, so none of it has
run on the real hardware yet. Work through it top to bottom after
[the install](nix-install.md#framework--encrypted-root): later sections assume
earlier ones passed, and Secure Boot + TPM come last on purpose. Anything that
fails, note it in `TODO.md` with the command and its output.

---

## 0. Before installing

- [ ] **RAM vs swapfile.** On the live ISO: `free -g`. The `@swap` swapfile
      must hold a hibernation image of all of RAM, and it can only be resized
      by reinstalling. Above 32 GiB, raise `swap.swapfile.size` in
      `hosts/framework/disk-config.nix` first, and commit it (push too, if you
      install from the GitHub flake).
- [ ] **Disk name.** `lsblk` should show the one NVMe as `nvme0n1`, which is
      what `disk-config.nix` formats.
- [ ] **Ship the sops key with the install.** The first activation decrypts
      the password hash, so `/var/lib/sops-nix/key.txt` has to exist before it
      runs. From `/etc/nixos` on home-desktop:

  ```bash
  extra=$(mktemp -d) && chmod 755 "$extra"   # its mode lands on the target's /
  install -Dm600 .bootstrap/framework/key.txt "$extra/var/lib/sops-nix/key.txt"
  nix run github:nix-community/nixos-anywhere -- \
    --flake .#framework --build-on remote \
    --extra-files "$extra" nixos@<ip>
  rm -rf "$extra"
  ```

  Without it, activation fails with "no key could decrypt" and the user is
  created with no usable password.

---

## 1. First boot

- [ ] **Limine menu.** The text is double size (Limine scales itself 2× at
      2560×1440 and up), with a `NixOS` and a `powersave` entry.
- [ ] **LUKS prompt.** It's themed by plymouth and takes the passphrase you
      typed during the install.
- [ ] **SDDM greeter.** It should come up at a readable size: it runs on
      KWin, which picks a scale from the panel. If it's tiny, that needs config.
- [ ] **TTY font.** On `Ctrl+Alt+F2` the kernel picks its large Terminus font
      by itself. `Ctrl+Alt+F1` goes back.
- [ ] **Log in with the password.** It comes from `max-password-hash` in
      `secrets/common.yaml`.
- [ ] **Real hardware config.** Replace the placeholder
      `hosts/framework/hardware-configuration.nix` as described in
      [nix-install.md](nix-install.md#framework--encrypted-root), commit it,
      and run `nixup`, which should succeed with nothing else changing.
- [ ] **Remove the staged key** from home-desktop:
      `rm .bootstrap/framework/key.txt` (see `TODO.md`, Secrets).

---

## 2. Hardware

```bash
hyprctl monitors | grep -E "^Monitor|scale|availableModes" | head
lspci -k | grep -A3 -E "VGA|Display"
vainfo 2>&1 | grep -i "driver version"
ls /dev/accel
systemctl is-active iwd
```

- [ ] **Panel.** `eDP-1` at `2880x1920@120`, scale `2.00`. If the connector
      or mode differs, fix `monitors` and `kanshi.internal` in `flake.nix`.
- [ ] **GPU driver.** `Kernel driver in use: xe`.
- [ ] **Video decode.** vainfo names the iHD driver (Intel iHD). Play a video
      in Zen while `intel_gpu_top` runs: the Video engine should be busy.
- [ ] **NPU.** `/dev/accel` lists `accel0`.
- [ ] **Wi-Fi.** iwd is `active`, and the connection survives walking between
      access points.
- [ ] **Audio.** Speakers, microphone and headphones all work, with no pop
      when the codec wakes.

---

## 3. Secrets, network, identity

```bash
sudo ls /run/secrets /run/secrets/syncthing
sudo tailscale up --operator=max     # once; follow the login URL
tailscale status
getent hosts home-desktop            # and `getent hosts framework` on home-desktop
avahi-browse -rt _ipp._tcp | grep -E "hostname|address" | head
```

- [ ] **Secrets.** `/run/secrets` holds `max-password-hash` and
      `syncthing/{cert-pem,key-pem}`.
- [ ] **Tailscale.** The framework shows in `tailscale status`, and each
      machine resolves the other's bare hostname to a `100.x` address. That
      MagicDNS lookup is what lan-mouse relies on.
- [ ] **Syncthing.** At `localhost:8384` the device ID matches the framework
      entry in the homelab repo (it comes from `secrets/framework.yaml`), and
      `~/SyncDrive` syncs.
- [ ] **Printers.** Network printers show up in avahi-browse and in CUPS at
      `localhost:631`.

---

## 4. Fingerprint

```bash
fprintd-enroll                      # right index finger; -f <finger> for others
fprintd-verify
grep -c fprintd /etc/pam.d/{login,hyprlock,sudo,polkit-1}
```

- [ ] **PAM wiring.** The counts read `login:0`, `hyprlock:0`, `sudo:1` and
      `polkit-1:1`.
- [ ] **sudo.** `sudo -k; sudo true` asks for a finger. Left alone, it falls
      back to the password after the reader's 30 s timeout.
- [ ] **Polkit.** `pkexec true` opens the polkit-gnome dialog (DMS's own agent
      is switched off), and it takes the finger too.
- [ ] **hyprlock.** Lock with `Super+L`. A line under the password box reads
      "(Scan fingerprint to unlock)". The finger unlocks, and typing the
      password works straight away without waiting for the reader.
- [ ] **SDDM and TTY.** Both take the password only, with no wait for the
      reader first.
- [ ] **Keyring unlocked.** After an SDDM login,
      `busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked`
      prints `b false`.

---

## 5. Suspend and hibernate

```bash
swapon --show
grep systemctl ~/.config/hypr/hypridle.conf
systemctl hibernate
```

- [ ] **Swap.** `/dev/zram0` at PRIO 5, plus `/.swapvol/swapfile` at a lower
      (negative) PRIO.
- [ ] **Idle.** The hypridle line ends in `systemctl suspend-then-hibernate`.
- [ ] **Hibernate.** The machine powers off. On power-on you get the LUKS
      prompt, then the same session behind hyprlock with windows intact.
      `journalctl -b -g "sleep operation"` shows `'hibernate'`.
- [ ] **Plain suspend.** `systemctl suspend`, then wake from the keyboard:
      both the screen and hyprlock come back.

**suspend-then-hibernate.** The real delay is 2 h, so shorten it for the test
with a drop-in, which systemd-sleep reads on each run:

```bash
sudo mkdir -p /etc/systemd/sleep.conf.d
printf '[Sleep]\nHibernateDelaySec=2min\n' | sudo tee /etc/systemd/sleep.conf.d/zz-test.conf
```

- [ ] **On battery** (unplugged): close the lid, wait about 3 minutes, then
      open it and press power. The LUKS prompt shows it hibernated.
- [ ] **On AC:** run `systemctl suspend-then-hibernate`, which is what the
      idle path does, and wait the same 3 minutes. It stays suspended, with no
      LUKS prompt on wake, because `HibernateOnACPower = false` holds the
      countdown while plugged in. (Closing the lid on AC only ever suspends.)
- [ ] **Docked** (external monitor attached): closing the lid does nothing.
- [ ] **Clean up:** `sudo rm /etc/systemd/sleep.conf.d/zz-test.conf`.

---

## 6. Battery and power

```bash
systemctl status battery-charge-limit
cat /sys/class/power_supply/BAT1/charge_control_end_threshold
cat /sys/class/power_supply/BAT1/status
powerprofilesctl get
```

- [ ] **Charge limit.** The service exited `0/SUCCESS` and the threshold reads
      `80`. Plugged in above 80%, the status is `Not charging`. If the service
      failed, `journalctl -b -u battery-charge-limit` shows why; EIO means the
      EC rejected the write.
- [ ] **Power profiles.** The profile buttons in the DMS battery popout change
      what `powerprofilesctl get` reports.
- [ ] **powersave entry.** Boot it from Limine once: `sudo tlp-stat -s | head`
      shows TLP enabled, and `powerprofilesctl` fails, since ppd is off there.
- [ ] **powertop.** Run `sudo powertop --calibrate` once, then look at what
      keeps the package out of deep C-states.

---

## 7. Cursor and docking

```bash
hyprctl getoption cursor:no_hardware_cursors
journalctl --user -b -u kanshi | tail -5
```

- [ ] **Hardware cursor.** The option reads `int: 2`. The cursor shows on
      every output, with no trails or flicker, including over fullscreen video
      and on the external monitors.
- [ ] **Office dock.** kanshi applies `docked`. In `hyprctl monitors` the
      Philips `UK02150032264` sits at `0,0`, `UK02150032262` at `2560,0`, and
      `eDP-1` at `1840,1440`. At a different desk, take the descriptions from
      `hyprctl monitors` and replace `kanshi.docked` in `flake.nix`.
- [ ] **Lid closed while docked.** The internal panel stays enabled, because
      the docked profile turns it on. Note it if you'd rather it switched off.

---

## 8. lan-mouse (with home-desktop)

```bash
sudo iptables -S nixos-fw | grep 4242      # on both machines
kdeconnect-cli --pair -n home-desktop      # accept the request on home-desktop
kdeconnect-cli -l
systemctl --user status lan-mouse
```

- [ ] **Firewall.** Exactly one rule on each machine:
      `-A nixos-fw -i tailscale0 -p udp -m udp --dport 4242 -j nixos-fw-accept`.
- [ ] **KDE Connect.** Each machine lists the other as paired and reachable.
- [ ] **Crossing.** Open `lan-mouse` on both and activate the peer. The cursor
      crosses off the framework's left edge onto home-desktop and back off
      home-desktop's right edge, and typing follows it. The release combo is
      `LeftCtrl+LeftShift+LeftMeta+LeftAlt`.
- [ ] **Clipboard.** Copy on one machine, cross, and paste on the other.
- [ ] **Make it permanent.** Once the link works, set
      `activateOnStartup = true` in both `lanMouse` blocks in `flake.nix`.

---

## 9. Firmware and maintenance

```bash
fwupdmgr refresh && fwupdmgr get-updates
systemctl list-timers 'btrfs-scrub*' fwupd-refresh.timer
ls -l /lib64/ld-linux-x86-64.so.2
```

- [ ] **Firmware updates.** Apply any BIOS or EC updates now, before
      section 10: a BIOS update can change PCR 7 or reset the Secure Boot keys.
- [ ] **Timers.** Both show a next run: the btrfs scrub is monthly.
- [ ] **nix-ld.** The loader exists, so downloaded binaries can run.
- [ ] **Moonlight.** It streams a game from home-desktop's Apollo.
- [ ] **Build parallelism.** With 32 GiB or more of RAM, uncomment
      `nix.settings.max-jobs = "auto";` in `hosts/framework/default.nix`.

---

## 10. Secure Boot, then TPM2 unlock

**Secure Boot.** Follow the four steps in the `limine.nix` header:

1. Create the keys: `sudo sbctl create-keys`.
2. In the BIOS, put Secure Boot into Setup Mode, then run
   `sudo sbctl enroll-keys -m -f`.
3. Uncomment `loader.limine.secureBoot.enable = true;` in
   `hosts/framework/default.nix`, then run `nixup`.
4. In the BIOS, leave Setup Mode and enable Secure Boot.

- [ ] **Secure Boot on.** `sbctl status` reports Secure Boot enabled, and the
      machine boots.
- [ ] **Hibernate still works.** Repeat `systemctl hibernate`. The kernel has
      no lockdown LSM, so Secure Boot doesn't block it.

**TPM2.** Enrol it only once Secure Boot is on. It asks for the LUKS passphrase:

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-nvme-luks
# add --tpm2-with-pin=yes to keep a short PIN at boot (see the host file)
sudo systemd-cryptenroll /dev/disk/by-partlabel/disk-nvme-luks   # lists password + tpm2 slots
```

- [ ] **Unattended unlock.** Reboot: there's no passphrase prompt, or just the
      PIN if you added one.
- [ ] **Fallback.** Disable Secure Boot in the BIOS and boot. The passphrase
      prompt comes back, because PCR 7 changed and the TPM refuses, and the
      passphrase works. Re-enable Secure Boot, and it unlocks by itself again.
- [ ] **Later Secure Boot database updates** (fwupd's dbx) also change PCR 7.
      Unlock with the passphrase once, then re-enrol by adding
      `--wipe-slot=tpm2` to the enrol command.

---

## Repo follow-ups once everything passes

- [ ] Real `hardware-configuration.nix` committed (section 1).
- [ ] `activateOnStartup = true` on both lan-mouse ends (section 8).
- [ ] `max-jobs` raised if RAM allows (section 9).
- [ ] `secureBoot.enable` uncommented and committed (section 10).
- [ ] `kanshi.docked` descriptions updated if the desk differs (section 7).
