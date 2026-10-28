# Matrix: alle Messenger in einer App (Design, 2026-10-28)

## Absicht

Alle Chats (WhatsApp, Signal, Telegram, Instagram/Messenger, SMS) in **einer** App lesen und
beantworten, übersichtlich nach Themen statt nach Messenger sortiert. Später liest Claude
dieselben Chats **nur lesend** mit, erkennt Termine und schlägt sie im Kalender blass vor
(siehe Kalender-Vorschlag im Gespräch vom 28.10.2026).

Dauerhaft gehört das auf den Homeserver (Notiz `~/Notizen/Projekte/Privat/Homeserver.md`). Auf meo läuft es vorher als
**Probelauf**: einrichten, ausprobieren, Config fertig machen. Für den Alltag taugt es auf dem
Laptop nicht, weil die Brücken nichts empfangen, solange er schläft.

## Ziele / Nicht-Ziele / Anti-Ziele

- Ziel: ein Matrix-Server + Brücken, als NixOS-Modul, das ohne Umbau vom Laptop auf den Server wandert.
- Ziel: Element X (Handy) und Element (Laptop) als einzige Chat-Apps im Alltag.
- Nicht-Ziel: Anrufe (werden nicht gebrückt, bleiben in den Original-Apps).
- Nicht-Ziel: Föderation mit fremden Matrix-Servern (vorerst).
- Anti-Ziel: Claude kann irgendwann selbst etwas senden. Lesen-only muss **technisch** erzwungen sein.
- Anti-Ziel: Chats im Klartext auf einem unverschlüsselten Laptop, der herumgetragen wird.

## Entscheidungen (Claudes Wahl, vom User freigegeben: „mach das so“)

| Punkt | Wahl | Warum |
|---|---|---|
| Server | `services.matrix-synapse` + PostgreSQL | Referenzserver; Brücken und Element X sind darauf getestet (native Sliding Sync) |
| Brücken | `services.mautrix-signal`, `-telegram`, `-whatsapp`, `-meta`; `mautrix-gmessages` (nur Paket, Unit selbst) | alles in nixpkgs, gleiche Bauart |
| Erreichbarkeit | nur Tailnet, HTTPS über `tailscale serve` | keine Ports ins Internet, gültiges Zertifikat für Element X |
| Reihenfolge der Brücken | Signal + Telegram zuerst, WhatsApp danach | WhatsApp-Brücke ist inoffiziell → kleines, aber reales Sperr-Risiko |
| Modul | `modules/meo/matrix.nix`, erst in `hosts/meo` importiert | Umzug = Import verschieben; `public_baseurl` folgt `networking.hostName` |
| Verschlüsselung der Brücken | `withGoolm = true` | libolm ist in nixpkgs als unsicher markiert |
| Secrets | Registrierungs-/Brücken-Tokens nicht ins Repo | Repo ist öffentlich; Ablage klären (sops-nix oder Datei ausserhalb) |

## Entscheide des Users (2026-10-28)

- **Servername `meo-server`** (endgültig, Adressen `@meo:meo-server`, nur Tailnet, keine Föderation).
  Passt zum späteren Host `meo-server` neben `meo` und `meo-work`.
- **meo wird für den Probelauf nicht verschlüsselt**; verschlüsselt wird der Server.
  Nach dem Probelauf die Chat-Daten auf meo entfernen.

## Phasen

**0. Voraussetzung:** nur der Server wird verschlüsselt (Entscheid User); meo-Daten nach dem Probelauf löschen.

**1. Probelauf auf meo:** Synapse + Postgres + Signal + Telegram. Element am Laptop, Element X am Handy
über Tailnet. Spaces nach Themen anlegen (Technorama, Espace, Familie, Kollektiv). Prüfen:
Login mit Element X, Push-Benachrichtigungen, Bilder/Sprachnachrichten, Verhalten nach Suspend.

**2. WhatsApp, Meta, SMS** dazu, wenn Phase 1 überzeugt.

**3. Claude liest mit (nur lesen):** drei unabhängige Sperren, jede muss allein halten:
1. eigenes Konto `@claude` ohne Senderecht in den Räumen → der Server lehnt ab;
2. Zugriff nur über einen Proxy, der ausschliesslich GET durchlässt;
3. Lese-Werkzeug ohne Sende-Befehl, Zugangs-Token für Claude selbst nicht lesbar.
Vorab klären: wie `@claude` in die Brücken-Räume kommt (Brücken laden nur den eigenen User ein)
und ob statt Sperre 1 ein Postgres-Nur-Lese-Zugriff robuster ist. Rot-Nachweis Pflicht:
ein Sendeversuch von `@claude` muss sichtbar scheitern.
Antworten: Claude schlägt Text vor (Benachrichtigung/Notiz), abschicken tut der User in Element.

**4. Umzug auf den Server:** Import von `hosts/meo` nach `hosts/<server>`; Postgres-Dump +
Brücken-Daten mitnehmen oder Messenger per QR neu verknüpfen. Clients neu anmelden (andere URL).

## Bekannte Grenzen

- Original-Apps bleiben installiert (Hauptgerät, Anrufe).
- WhatsApp wirft ein verknüpftes Gerät nach ~14 Tagen ohne Kontakt raus.
- Stories/Status, manche Umfragen fehlen.
- Threema, iMessage: keine brauchbare Brücke.
- Beim ersten Einschalten einer neuen Brücke scheitert Synapse einmal (Registrierungsdatei
  fehlt noch, die Brücke legt sie erst beim eigenen Start an); `fr` meldet Exit 4, Synapse
  startet per Restart von selbst. Beim Umzug auf meo-server einmal so erwarten.
- Telegram-Brücke (Python) ohne E2BE gebaut (`withE2BE = false`), sonst libolm.
