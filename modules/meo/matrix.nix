{
  config,
  lib,
  pkgs,
  ...
}: let
  # Matrix-Server + Messenger-Brücken (2026-10-28, Probelauf auf meo).
  # Spec: docs/superpowers/specs/2026-10-28-matrix-messenger-design.md
  #
  # Host-lokal (nur hosts/meo importiert das), weil es eine Server-Rolle ist:
  # Dauerbetrieb kommt später auf meo-server. Umzug = Import dorthin verschieben,
  # die öffentliche Adresse folgt dem Hostnamen automatisch.
  #
  # Nur im Tailnet erreichbar: Synapse hört auf 127.0.0.1, `tailscale serve`
  # reicht HTTPS von https://<host>.tailec8a46.ts.net weiter. Keine Föderation.
  # ENDGÜLTIG: steckt in jeder Adresse (@meo:meo-server), nie mehr ändern.
  serverName = "meo-server";
  oeffentlicheAdresse = "https://${config.networking.hostName}.tailec8a46.ts.net/";
  ich = "@meo:${serverName}";

  # Geheimnisse liegen nicht im (öffentlichen) Repo, sondern hier auf der Platte.
  geheim = "/var/lib/matrix-geheim";

  # Telegram braucht api_id/api_hash von https://my.telegram.org (dein Login).
  # Erst auf true setzen, wenn ${geheim}/telegram.env existiert, sonst startet
  # Synapse nicht (es erwartet die Registrierungsdatei der Brücke).
  telegramBereit = true;
in {
  services.postgresql = {
    enable = true;
    # Läuft nur beim allerersten Anlegen des Datenbank-Clusters (meo hatte keinen).
    # Synapse verlangt die Sortierung "C". CREATE ROLE ohne LOGIN darf sich
    # nicht anmelden (das Beispiel in der nixpkgs-Doku vergisst das).
    initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE ROLE "matrix-synapse" WITH LOGIN;
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';
    # Repariert die Rolle auf meo (dort ohne LOGIN angelegt): ALTER USER … WITH LOGIN
    # bei jedem Start von postgresql-setup.
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureClauses.login = true;
      }
    ];
  };

  services.matrix-synapse = {
    enable = true;
    # registration_shared_secret für register_new_matrix_user (siehe unten)
    extraConfigFiles = ["${geheim}/synapse-registrierung.yaml"];
    settings = {
      server_name = serverName;
      public_baseurl = oeffentlicheAdresse;
      listeners = [
        {
          port = 8008;
          bind_addresses = ["127.0.0.1"];
          type = "http";
          tls = false;
          x_forwarded = true;
          # nur Client-API, keine Föderation
          resources = [
            {
              names = ["client"];
              compress = true;
            }
          ];
        }
      ];
      # Föderation ganz aus: mit niemandem ausserhalb reden
      federation_domain_whitelist = [];
      trusted_key_servers = [];
      enable_registration = false;
      report_stats = false;
    };
  };

  # Erzeugt die Geheimnisse einmalig, bevor Synapse startet. Bleiben bei jedem
  # Neustart gleich (nur anlegen, wenn sie fehlen).
  systemd.services.matrix-geheimnisse = {
    description = "Matrix: Geheimnisse einmalig erzeugen";
    wantedBy = ["matrix-synapse.service"];
    before = ["matrix-synapse.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0750 -o root -g matrix-synapse ${geheim}
      f=${geheim}/synapse-registrierung.yaml
      if [ ! -s "$f" ]; then
        umask 0137
        printf 'registration_shared_secret: "%s"\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > "$f"
        chgrp matrix-synapse "$f"
      fi
    '';
  };
  systemd.services.matrix-synapse = {
    requires = ["matrix-geheimnisse.service"];
    after = ["matrix-geheimnisse.service"];
  };

  services.mautrix-signal = {
    enable = true;
    # goolm = Olm in Go statt der veralteten, als unsicher markierten libolm.
    # Wird dadurch einmal lokal gebaut (Go-Teil, ein paar Minuten).
    package = pkgs.mautrix-signal.override {withGoolm = true;};
    settings = {
      homeserver.address = "http://127.0.0.1:8008";
      appservice.hostname = "127.0.0.1";
      # Namen wie im Handy-Adressbuch (nur ein Nutzer auf der Brücke, daher erlaubt)
      network.displayname_template = "{{or .ContactName .ProfileName .PhoneNumber \"Unbekannt\"}}";
      # Verlauf übernehmen: Signal liefert ihn nur EINMAL beim Verknüpfen
      # ("Nachrichtenverlauf übertragen"). Ohne das entsteht ein Chat erst bei
      # der nächsten neuen Nachricht.
      backfill = {
        enabled = true;
        max_initial_messages = 200;
      };
      bridge = {
        relay.enabled = false;
        # niemand sonst darf die Brücke benutzen
        permissions = {
          "*" = "block";
          ${ich} = "admin";
        };
      };
      provisioning.shared_secret = "disable";
      # Auf "info" schreibt die Brücke Namen und Nummern aller Kontakte ins Journal.
      logging.min_level = "warn";
    };
  };

  services.mautrix-telegram = lib.mkIf telegramBereit {
    enable = true;
    # Ohne Matrix-Verschlüsselung (E2BE) gebaut: die Python-Brücke zöge sonst die
    # als unsicher markierte libolm mit, eine goolm-Variante hat sie nicht.
    # Die Brücken-Räume liegen ohnehin unverschlüsselt auf dem eigenen Server.
    package = pkgs.mautrix-telegram.override {withE2BE = false;};
    # MAUTRIX_TELEGRAM_TELEGRAM_API_ID=… und MAUTRIX_TELEGRAM_TELEGRAM_API_HASH=…
    environmentFile = "${geheim}/telegram.env";
    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = serverName;
      };
      appservice = {
        hostname = "127.0.0.1";
        port = 29317;
        address = "http://127.0.0.1:29317";
      };
      bridge = {
        permissions = {
          "*" = "relaybot";
          ${ich} = "admin";
        };
        # Standard: nur 15 Gruppen beim Login, Direktchats erst bei neuer Nachricht.
        # Hier: die 40 zuletzt aktiven Chats inkl. Direktchats sofort anlegen.
        sync_create_limit = 40;
        sync_direct_chats = true;
      };
    };
  };

  # HTTPS im Tailnet: https://<host>.tailec8a46.ts.net → Synapse.
  # Braucht in der Tailscale-Admin-Konsole DNS → "HTTPS Certificates" aktiviert.
  # Die Weiterleitung merkt sich tailscaled selbst; abbauen mit `tailscale serve reset`.
  systemd.services.matrix-tailscale-serve = {
    description = "Matrix: HTTPS über tailscale serve";
    wantedBy = ["multi-user.target"];
    after = ["tailscaled.service" "matrix-synapse.service"];
    wants = ["tailscaled.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 http://127.0.0.1:8008
    '';
  };

  # Chat-App am Laptop (am Handy: Element X)
  environment.systemPackages = [pkgs.element-desktop];
}
