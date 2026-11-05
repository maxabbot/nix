# Framework migration: what the repo covers, and what has to move

Compares the `framework` host with `home-desktop`, then gives a generic
checklist for moving off a Windows laptop onto the framework. Written
2026-11-03. The repo is public, so this file names no clients, repos or
credential locations; keep a gitignored `framework-migration.local.md` beside
it for those (`*.local.md` is in `.gitignore`).

---

## 1. framework vs home-desktop

The framework imports every `hosts/common/optional/*.nix` module home-desktop
does, except these, all deliberate:

| Missing on framework | Why |
|---|---|
| `nvidia.nix`, `cuda.nix`, `fan2go.nix`, `it87` | No NVIDIA GPU; a laptop has no case fans to manage |
| `gaming-streaming.nix` | Gets `moonlight.nix` (client only) instead of the Apollo host |
| `expo.nix` | Home-desktop only: Metro serves app source on the LAN |
| Gamescope DP-3 args, greeter monitor rule, Windows chainload | Specific to the desktop's monitors and disk |

Framework-only: `nixos-hardware`, LUKS + TPM, hibernate, 80% charge limit,
powersave specialisation, fingerprint login, kanshi docking.

### Gaps that have been closed (commit `df43339`)

- `hosts/common/optional/keyboards.nix`: QMK, NuPhy and Vial udev rules, moved
  out of home-desktop and imported by both hosts.
- `fonts.packages = [ pkgs.corefonts ]` on the framework (the CV build's
  Puppeteer render expects Georgia).
- `hardware.i2c.enable` on the framework. External monitors expose a DDC/CI side
  channel over HDMI/DisplayPort; `ddcutil` reaches it through `/dev/i2c-*`, and
  the DMS brightness slider uses that for the docked monitors. The internal
  panel goes through the backlight interface and is unaffected.
- `snowsql` and `dbt` (with the Snowflake adapter) in `development.nix`.

### Still absent, all optional

1. `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`, for building the
   Raspberry Pi SD image from the framework.
2. `sops` / `age` packages: only home-desktop holds the admin age key.
   Intentional.
3. Zen / Thunderbird profile names: the framework uses the defaults, so it
   starts with empty profiles.

---

## 2. Already handled by the config

- Syncthing identity (`secrets/framework.yaml`), so `~/SyncDrive` syncs by itself.
- Login password hash (`secrets/common.yaml`).
- The sops host key must be at `/var/lib/sops-nix/key.txt` **before** the first
  rebuild (staged in `.bootstrap/framework/`; delete it afterwards).

Hardware tests (Secure Boot, TPM, hibernate, charge limit) are in
[framework-post-install.md](framework-post-install.md).

---

## 3. Git work that exists only on the old machine

OneDrive (or any synced folder) is a file backup, not version control, and
`.git` is thousands of small files a partial sync can leave inconsistent.

Audit every repo for work with no home:

```bash
git status --porcelain                         # uncommitted
git log --branches --not --remotes --oneline   # commits on no remote
git stash list                                 # stashes
git remote get-url origin                      # none = no remote at all
```

- **No remote:** push to a private repo, or `git bundle create repo.bundle --all`
  (one file, restore with `git clone repo.bundle`; verify with
  `git bundle verify`).
- **Unpushed commits:** push as a branch and open a PR; don't push shared
  `main` directly.
- **Stashes:** list them before deleting anything. A stash whose diff is empty
  under `git diff --ignore-cr-at-eol --ignore-space-at-eol <stash>^1 <stash>` is
  pure CRLF/LF noise. A `.gitattributes` with `* text=auto eol=lf` stops it
  recurring. Check a stash's untracked files (`git ls-tree -r <stash>^3`)
  before dropping it.
- **Rebase leftovers:** a `backup/*-pre-rebase` branch usually holds the old
  copies of commits the remote now has in rebased form. Compare patch IDs
  (`git cherry`) before deleting.
- **Not git repos at all:** zip them, or turn them into repos.
- **Regenerable folders:** delete `node_modules`, venvs, `dist`/`build` and
  `__pycache__` before moving. They reinstall (`npm ci`, `pip install -r`) and
  they dominate sync time. Skip any venv outside git with no requirements file
  beside it, and any `dist` you can't rebuild.

---

## 4. Credentials and config outside git

Move these over an encrypted channel (password manager, an age-encrypted
tarball, scp). Never through a synced folder in plaintext.

- `.env` files and their variants (`.env.prod`, `.env.staging`).
- Terraform/OpenTofu state, `.tfvars` and secrets files.
- Local database files and backups.
- SSH keys. Generating a new key on the framework and adding it to GitHub is
  cleaner than copying the old one.
- Key-pair files and CLI config for data tooling (Snowflake `.p8`/`.pub`,
  `~/.snowsql`, `~/.dbt/profiles.yml`) and any other `~/.<tool>` config.
- Cloud CLI credentials, **including those inside WSL**, which are separate from
  the Windows ones.
- Docker Desktop volumes: check for local database data before wiping.

Also decide what must never move: publish-profile files (`*.PublishSettings`),
HAR captures (they hold session cookies and tokens), and any credential already
committed to a shared repo, which needs rotating, not moving.

---

## 5. Logins to redo on the framework

- `gh auth login` (HTTPS remotes use the credential manager's account; if it
  differs from the repo owner a private repo answers "not found", so use SSH
  remotes), `az login`, `gcloud auth login`.
- Work VPN client: no Nix config yet (e.g. `openfortivpn`, or a NetworkManager VPN
  plugin).
- Password manager, Tailscale, Obsidian Sync (`Open folder as vault`, then log
  in and pick the remote vault), Zen sync, Chrome (the PWAs need it), Moonlight
  pairing, Solaar pairing, `fprintd-enroll`.
- Work OneDrive: not through `onedriver`. The work tenant doesn't let users
  consent to third-party apps ("Need admin approval"), and rclone or
  `abraunegg/onedrive` would hit the same wall. Work files go through the
  OneDrive web app in `pwas.nix` (`office.com/launch/onedrive`, which resolves
  to the signed-in account; `microsoft365.com/onedrive` now 404s in the
  Copilot app), and `.pbix` files through the OneDrive client in the WinBoat
  guest, which is Microsoft's own and needs no consent. No personal OneDrive
  is needed, so `onedriver-launcher` stays unused.

---

## 6. Downloads and loose files

Sort the Downloads folder into: keep, move, delete.

- **Keep:** things that exist nowhere else (personal documents, your own media).
- **Account recovery codes and ID photos:** into the password manager, then
  delete the files. Don't leave them in a company-managed synced folder.
- **Customer or financial exports** (statements, payment batches, bulk CSV/JSON):
  confirm the original lives in the system of record, then delete the local copy.
- **Work documents:** confirm they're in SharePoint or a repo, then delete.
- **Reproducible:** drivers and installers, tool zips, forex/reference datasets,
  screenshots, scratch diagrams, copies of files the repo already has (compare
  hashes before deleting).
- Prefer sending files to the Recycle Bin over deleting them outright until
  you're sure. A very large folder (long paths, deep `node_modules`) can be
  refused by the Recycle Bin; delete it directly once you've checked it's all
  pushed.

### Is the synced Desktop actually uploading?

A file OneDrive has finished uploading becomes a cloud placeholder, which carries
a reparse-point attribute; a plain file hasn't been converted yet. Counting
files without it is a quick check. Expect a handful of deliberate exclusions
(`.DS_Store`, `~$*` Office lock files, `.venv/.lock`). Python venvs made under
WSL contain a `lib64 -> lib` symlink Windows can't follow, which makes naive
directory walks throw "file cannot be accessed". It doesn't prove a recent edit
has finished uploading; the tray icon and the web view do.

---

## 7. Power BI on the framework

Power BI Desktop is Windows-only, and the framework has no Windows install.
What works where:

| Task | On the framework |
|---|---|
| Viewing and sharing published reports | Works in the browser (Zen or Chrome) |
| Editing a report that's already published | Works in the browser (Power BI service). The editor is capable, but behind Desktop for modelling and some formatting |
| Editing PBIR report files (`pbi-cli` report, visuals, pages, themes, filters skills) | Works. PBIR is a folder of JSON, so scaffold, validate and edit work anywhere |
| Editing TMDL model files as text | Works as text and git. Nothing validates them without a Tabular engine |
| `pbi connect`, DAX queries, measures and modelling through `pbi-cli` | **Does not work natively.** It attaches to the local Analysis Services instance that Desktop starts, using .NET libraries (`~/.pbi-cli/bin`) |
| Opening, refreshing and publishing `.pbix` / `.pbip` | Needs Desktop, so Windows |

There is no Linux client, and Wine/Proton aren't realistic (WebView2, .NET and
the Analysis Services engine are the problem). So it's a real Windows guest or
the old laptop.

### Decision: WinBoat, with the Windows laptop kept until it's proven

Power BI is the only Windows app needed, which is what WinBoat suits: one app
shown as a native window over RDP, rather than a whole desktop to manage.

1. **Keep the Windows laptop for Power BI** until the steps below work end to
   end. It already has Desktop, the ODBC drivers, `pbi-cli` and its
   connections.
2. **Try WinBoat** (below). It runs a real Windows 11 guest, so Desktop's local
   Analysis Services instance is there and `pbi-cli` works inside the guest.
3. **Fall back to a libvirt VM** if WinBoat's Podman mode won't run here.
   `libvirt.nix` is already imported. Windows 11 guest, virtio drivers, 4+
   vCPU, 8+ GB RAM, TPM via swtpm.
4. **Browser-only** covers light edits to published reports, not modelling or
   DAX through `pbi-cli`.

Run one or the other, not both: each is a separate Windows install with its own
disk image, so both together cost 60–80 GB. Delete the loser's image and ISO.

### What's known about WinBoat (checked 2026-11-03)

No first-hand report of Power BI Desktop on WinBoat turned up, official or
user. It should work, since the guest is plain Windows 11, but it's untested.

- **Packaging:** `pkgs.winboat` is in nixpkgs (0.9.0 in this flake's pin). No
  AppImage needed.
- **Podman:** supported since 0.9.0, chosen during WinBoat's setup. The
  nixpkgs package wraps `podman-compose` and FreeRDP onto its own PATH, so
  nothing extra is needed. USB passthrough doesn't
  work under Podman (not needed for Power BI), and ports are assigned randomly.
  The README's NixOS instructions assume Docker. **Tested 2026-11-03:** Podman
  mode installs fine on the framework. Setup pulled the `dockur/windows` image,
  built the disk and finished the unattended Windows install in about 25
  minutes, with no changes beyond `winboat.nix`.
- **USB device snapshot:** WinBoat's generated `~/.winboat/podman-compose.yml`
  passes `/dev/bus/usb` into the container, and Podman expands it into the
  device nodes present when the container is created. After a dock, undock or
  replug renumbers the bus, start fails with `crun: cannot stat
  /dev/bus/usb/NNN/NNN`. Windows itself is fine. Fix (2026-11-05): delete the
  `- /dev/bus/usb` line (passthrough doesn't work under Podman anyway), then
  recreate the container from `~/.winboat`: `podman rm WinBoat` and
  `podman-compose -f podman-compose.yml up -d` (`podman-compose` is only on
  WinBoat's wrapped PATH, so call it by store path). The disk image lives in
  the install folder, not the container, so this loses nothing. WinBoat may
  restore the line when its settings change; check the file first if the
  error returns.
- **Not Docker:** switching to real Docker would mean dropping `podman.nix`'s
  `dockerCompat`, since NixOS won't enable both. If Podman mode fails, use the
  libvirt VM rather than reshuffling container runtimes.
- **Status:** beta; expect bugs. The nixpkgs build pins Electron 40, which is
  EOL, so `flake.nix` permits it as an insecure package (as it already does
  Electron 39). Drop that entry when WinBoat moves on, or if WinBoat goes.
- **Requirements:** KVM, FreeRDP 3.x with sound, 4+ GB RAM, 32+ GB free on the
  install folder's drive (one write-up measured 48 GB). Plan on about 4 vCPU and
  8 GB RAM for Power BI, out of 32 GB.
- **Licence:** the image is downloaded for you; activation is on you.
- **GPU:** no passthrough. Desktop copes with software rendering; large
  visuals will be slower than native.
- **Storage on btrfs:** make the install folder and `chattr +C` it **before**
  WinBoat creates the disk image (it only applies to new files). Otherwise the
  image fragments badly under copy-on-write. Offline dedup won't help either.
- **Home share:** WinBoat mounts the Linux home into the guest. Keep the Power
  BI repo (PBIR/TMDL) on the guest's own disk and sync through git; working
  over the share is slow, and file watching and Desktop's reload are flaky.
- **Claude Code:** to edit report files and have `pbi-cli` connect to the
  model, run both inside the guest. Claude Code on Linux against the share
  only suits the PBIR file-editing part.
- **Network:** SQL Server, Snowflake and VPN access follow the guest's network,
  so the VPN client or Tailscale may need installing inside it.

### Plan

1. ~~Add `hosts/common/optional/winboat.nix`~~ (done: framework only, asserts
   `podman.nix`). Rebuild.
2. ~~Create the install folder, `chattr +C` it, then run WinBoat setup choosing
   Podman.~~ (done 2026-11-03: `~/winboat`, `+C` confirmed with `lsattr`, so
   the 64 GB `data.img` was created without copy-on-write.)
3. In the guest: `winget install -e --id Microsoft.PowerBI`, then `pbi-cli`
   and the data-source drivers. Sign in to the guest's OneDrive client with
   the work account for `.pbix` files. DAX Studio and Tabular Editor go here too if
   wanted; they attach to Desktop's Analysis Services the same way.
4. Test on a throwaway report: `pbi connect`, a DAX query, a refresh against
   real data sources (over the VPN if they need it), and a publish.
5. If that all works, retire Power BI from the Windows laptop. If Podman mode
   or networking fails, delete the WinBoat folder and set up the libvirt VM.

The PBIR and TMDL files stay in git, so the guest only needs a clone and the
`~/.pbi-cli` config. `.pbix` files are binary and Windows-only, so keep them in
a synced folder rather than git.

### Other reasons to want Windows later

None of these is needed now. If one comes up, it goes in the same guest, and a
full Windows desktop (the libvirt VM, or WinBoat's full-desktop mode) starts to
make more sense than a single app.

- SSMS for admin work (Profiler, Agent jobs). Plain queries work in VS Code's
  mssql extension.
- SSIS/SSRS/SSAS projects in Visual Studio; Power BI Report Builder.
- Excel with VBA, Power Pivot or COM add-ins; Access, Visio, Project; Power
  Automate Desktop.
- A work VPN or endpoint client with no Linux build. A VM may not satisfy an
  Intune compliance policy.
- Testing Windows behaviour: PowerShell 5.1, CRLF, Windows builds.

A VM doesn't help with games using kernel anti-cheat (they refuse VMs) or
GPU-heavy work (no passthrough).
