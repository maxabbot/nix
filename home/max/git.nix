{ git, pkgs, ... }:
let
  palette = import ../../config/stylix/palette.nix;
in
{
  programs.git = {
    enable = true;
    settings = {
      user.name = git.name;
      user.email = git.email;
      alias = {
        st = "status -sb";
        co = "checkout";
        br = "branch -vv";
        lg = "log --oneline --graph --decorate --all";
        last = "log -1 HEAD --stat";
        undo = "reset HEAD~1 --mixed";
        unstage = "reset HEAD --";
        wip = "!git add -A && git commit -m 'wip'";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      merge.conflictstyle = "zdiff3";
      diff.colorMoved = "default";
      rebase.autoStash = true;
      rerere.enabled = true;
      credential = {
        # Pin the personal account; work.inc overrides the username under
        # ~/Projects/work/ so gh hands git that account's token instead.
        "https://github.com" = {
          helper = "!${pkgs.gh}/bin/gh auth git-credential";
          username = "maxabbot";
        };
        "https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };
      safe.directory = "/etc/nixos";
      column.ui = "auto";
      branch.sort = "-committerdate";
      core = {
        autocrlf = "input";
        # zeditor, not zed: `zed` is only a zsh alias, and git runs the editor
        # through sh.
        editor = "zeditor --wait";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };
    };
    # Work identity lives in an untracked local file so it stays out of this
    # public repo. Git silently skips the include if the file is missing.
    includes = [
      {
        condition = "gitdir:~/Projects/work/";
        path = "~/.config/git/work.inc";
      }
    ];
  };

  programs.delta = {
    enable = true;
    # Defaults to false since delta moved out of programs.git: without it delta
    # is only a binary, and git keeps paging through less.
    enableGitIntegration = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
      syntax-theme = "gruvbox-dark";
      # Dark diff-fill tints: derived surfaces in the palette, since
      # gruvbox-material has no background tint for added/removed lines.
      "plus-style" = "syntax \"${palette.diffAddBg}\"";
      "minus-style" = "syntax \"${palette.diffDelBg}\"";
      "file-style" = "bold \"${palette.blue}\"";
      "hunk-header-style" = "file line-number syntax";
    };
  };
}
