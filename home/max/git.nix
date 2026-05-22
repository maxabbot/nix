{ git, ... }:
{
  programs.git = {
    enable = true;
    userName = git.name;
    userEmail = git.email;

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      merge.conflictstyle = "zdiff3";
      diff.colorMoved = "default";
      rebase.autoStash = true;
      rerere.enabled = true;
      safe.directory = "/etc/nixos";
      column.ui = "auto";
      branch.sort = "-committerdate";
      core = {
        autocrlf = "input";
        editor = "zed --wait";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };
    };

    aliases = {
      st = "status -sb";
      co = "checkout";
      br = "branch -vv";
      lg = "log --oneline --graph --decorate --all";
      last = "log -1 HEAD --stat";
      undo = "reset HEAD~1 --mixed";
      unstage = "reset HEAD --";
      wip = "!git add -A && git commit -m 'wip'";
    };
  };

  programs.delta = {
    enable = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
      syntax-theme = "gruvbox-dark";
      "plus-style" = "syntax \"#1e4920\"";
      "minus-style" = "syntax \"#4a1020\"";
      "file-style" = "bold \"#89b4fa\"";
      "hunk-header-style" = "file line-number syntax";
    };
  };
}
