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
| Gamescope DP-3 args, SDDM monitor config, Windows chainload | Specific to the desktop's monitors and disk |

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
  pairing, Solaar pairing, `fprintd-enroll`, `onedriver-launcher`.

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

Options, in order of how much I'd recommend them:

1. **Keep the Windows laptop for Power BI work.** It already has Desktop, SSMS,
   the ODBC drivers, `pbi-cli` and its connections. The framework does
   everything else. Lowest effort, and nothing breaks.
2. **A Windows VM on the framework.** `libvirt.nix` is already imported. A
   Windows 11 guest (virtio drivers, 4+ vCPU, 8+ GB RAM, TPM via swtpm)
   runs Desktop and `pbi-cli` well. Needs a Windows licence, and share the
   repos folder by virtiofs or git. Works offline and without the laptop,
   at the cost of disk and RAM on a 32 GB machine.
3. **Browser-only.** Fine for light report edits, not for modelling or DAX
   authoring through `pbi-cli`.

Wine and Proton aren't realistic for Desktop (WebView2 and the Analysis
Services engine are the problem). Whichever option you pick, the PBIR and
TMDL files stay in git, so the VM or the laptop only needs a clone and the
`~/.pbi-cli` config. `.pbix` files are binary and Windows-only, so keep them in
a synced folder rather than git.

### WinBoat vs a plain libvirt VM

WinBoat runs a full Windows VM (QEMU/KVM inside a Docker container) and shows
individual Windows apps as native windows over RDP. Power BI Desktop runs as a
real Windows app, so the local Analysis Services instance is there and
`pbi-cli` works if it runs inside the guest. This is from memory and untested
on this hardware, so check it against the current WinBoat docs.

**Recommendation: try WinBoat first; fall back to libvirt only if it gives
trouble.**

Why WinBoat:

- Desktop appears as a normal window beside the Hyprland apps.
- Setup is mostly automated: no ISO, virtio drivers or swtpm TPM to arrange.
- Same Windows engine underneath, so no loss in `pbi-cli` or Desktop compatibility.

When the plain VM wins:

- Docker is the sticking point. WinBoat expects Docker, and it's unconfirmed
  whether it accepts `podman.nix`'s Docker-compat socket. Enabling real Docker
  just for this costs more than libvirt, which is already imported.
- You need a full Windows desktop (SSMS, a work VPN client, installers that
  misbehave in RemoteApp mode).
- You want snapshots before risky changes (virt-manager makes this easy).
- You'd rather not depend on a young project that may break between updates.

Things to check on this setup:

- **Packaging:** confirm with `nix search nixpkgs winboat`. If it isn't there,
  use the AppImage pattern from `lmms-appimage`.
- **Resources:** about 4 vCPUs and 8 GB RAM or more for the guest, out of 32 GB.
- **Licence:** the image is downloaded for you; activation is on you.
- **GPU:** no passthrough. Desktop copes with software rendering; large
  visuals will be slower than native.
- **Repo location:** WinBoat shares the Linux home into the guest as a network
  drive. Keep the Power BI repo (PBIR/TMDL) on the guest's own disk and sync
  through git; working over the share is slow and file watching and Desktop's
  reload are flaky.
- **Claude Code:** to edit report files and have `pbi-cli` connect to the model,
  run both inside the guest. Claude Code on Linux against the share only suits
  the PBIR file-editing part.
- **Network:** SQL Server, Snowflake and VPN access follow the guest's network,
  so the VPN client or Tailscale may need installing inside it.

Plan:

1. Keep the Windows laptop for Power BI until the framework settles.
2. Check the package (above).
3. Try WinBoat on a throwaway report: install Desktop, run `pbi connect`, and
   refresh a report that uses real data sources.
4. If that works, add a `winboat.nix` to `hosts/common/optional/` (and a row in
   `CLAUDE.md`). If it fails on Docker or networking, set up the libvirt VM.

Everything stays in git, so switching between the two later costs nothing.
