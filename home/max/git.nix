{ git, pkgs, ... }:
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
        "https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
        "https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential";
      };
      safe.directory = "/etc/nixos";
      column.ui = "auto";
      branch.sort = "-committerdate";
      core = {
        autocrlf = "input";
        editor = "zed --wait";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };
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
