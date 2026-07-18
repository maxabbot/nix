{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.duckdb ];
}
