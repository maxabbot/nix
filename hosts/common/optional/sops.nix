# hosts/common/optional/sops.nix — sops-nix secrets (all four hosts).
#
# Secrets live encrypted in secrets/*.yaml; recipients are in .sops.yaml. Each
# host decrypts at activation with its own age key at /var/lib/sops-nix/key.txt
# into /run/secrets (tmpfs, root-only), so plaintext never reaches git or the
# Nix store. Same layout as the homelab repo, except the host key is a plain age
# key rather than one derived from the SSH host key — no sshd on these machines.
#
# Bootstrap, once per host (the key must be on disk BEFORE a rebuild that reads
# secrets, or activation fails with "no key could decrypt"):
#
#   sudo install -Dm600 -o root -g root key.txt /var/lib/sops-nix/key.txt
#
# Keys are generated on home-desktop with `age-keygen` into .bootstrap/<host>/
# (gitignored) and their public halves added to .sops.yaml. The key file sits on
# the root filesystem — on framework that's inside LUKS.
#
# Edit secrets with `sops secrets/common.yaml` on home-desktop (admin key at
# ~/.config/sops/age/keys.txt, shared with the homelab repo).
#
# Password note: users.mutableUsers is true (the NixOS default), so the hash
# below only applies when the user is CREATED — on an existing machine
# /etc/shadow wins and `passwd` is how the password changes. The secret keeps
# fresh installs working without a hash in git. A missing file only warns
# during activation; it never blanks an existing password.
{ config, ... }:
{
  sops = {
    defaultSopsFile = ../../../secrets/common.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      sshKeyPaths = [ ];
      # Don't invent a key if it's missing — a generated key decrypts nothing
      # and turns a loud bootstrap failure into a silent one.
      generateKey = false;
    };
    # Decrypted before the users activation step, which reads the file.
    secrets.max-password-hash.neededForUsers = true;
  };

  custom.base.hashedPasswordFile = config.sops.secrets.max-password-hash.path;
}
