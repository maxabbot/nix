# Swap Claude Code between saved logins (work/personal); see the script header.
{
  writeShellApplication,
  jq,
  coreutils,
  procps,
}:
writeShellApplication {
  name = "claude-account";
  runtimeInputs = [
    jq
    coreutils
    procps
  ];
  text = builtins.readFile ./claude-account.sh;
}
