{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.google-chrome ];

  # Settings → Languages: English (New Zealand) first, so sites are sent
  # Accept-Language en-NZ. ForcedLanguages pins these to the top of the list
  # (more can still be added below). Chrome's UI locale and date-box format
  # come from the system locale (en_NZ, base.nix) instead, which it maps to its
  # en-GB locale: dd/mm/yyyy. Merges with Stylix's BrowserThemeColor in the
  # same managed policy file.
  programs.chromium.extraOpts.ForcedLanguages = [
    "en-NZ"
    "en-GB"
    "en"
  ];

  # Cast discovery: Chrome finds TVs by multicast queries (SSDP to
  # 239.255.255.250:1900, mDNS to 224.0.0.251:5353), but devices answer by
  # *unicast* to Chrome's ephemeral port. conntrack doesn't tie a unicast reply
  # to a multicast query, so the firewall drops it and no TV shows up. Accept
  # just those replies — source port 1900/5353 from a private LAN address —
  # rather than the usual blanket 32768-60999 opening (matters on the laptop).
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p udp -m multiport --sports 1900,5353 \
      -s 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -j nixos-fw-accept
  '';
}
