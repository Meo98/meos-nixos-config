{
  # DNS override — Fritzbox + sekundäres Gateway (192.168.178.1 / 192.168.68.1)
  # propagieren manche Cloudflare-Subdomain-Records nur als AAAA und liefern
  # kein A-Fallback. Das hat das öffentliche Erreichen des obsidian-stack via
  # printbrigatacloud.org auf diesem Laptop blockiert (Tunnel war OK, lokaler
  # Resolver hat nur IPv6 geliefert, das aber im LAN nicht in CF edge geroutet
  # war → 15s-Timeouts im Browser).
  #
  # Wir setzen 1.1.1.1 / 1.0.0.1 als bevorzugte Resolver. NetworkManager nimmt
  # zusätzlich die DHCP-DNS auf, aber unsere Einträge stehen vor — der Resolver
  # versucht 1.1.1.1 zuerst, kriegt sofort ein A-Record, fertig. Die Fritzbox
  # bleibt als Fallback drin für rein-lokale Hostnames falls vorhanden.

  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  # NetworkManager: vor jeder DHCP-DNS-Liste unsere Resolver einfügen, statt
  # sie ans Ende zu hängen. Ohne das wird `networking.nameservers` zwar in
  # /etc/resolv.conf landen, aber NM überschreibt resolv.conf pro Connection
  # mit DHCP-DNS — Effekt wäre weg sobald die WLAN-Connection up geht.
  networking.networkmanager.insertNameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];
}
