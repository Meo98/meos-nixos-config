# ADDED 2026-10-06: Daten-Partition aus dem geloeschten Windows-Dual-Boot.
# NUR meo-work — meo (daheim) hat diese Partition nicht, deshalb eigene Datei
# statt Eintrag in modules/ oder in der generierten hardware.nix.
#
# Entstehung: Windows-Partitionen p1 (ESP) / p2 (MSR) / p3 (NTFS 207.6G) /
# p4 (Recovery) per sgdisk geloescht, p1 neu als Typ 8300 "daten" ueber den
# freigewordenen Block (Sektor 2048 - 435527679, direkt vor /boot = p5)
# angelegt, ext4 mit "-L daten -m 1 -E nodiscard" formatiert.
# /boot (p5) und / (p6) wurden nicht angefasst (Nummern + UUIDs unveraendert).
#
# GPT-Backup von VOR dem Umbau: /home/meo/gpt-backup-nvme0n1-2026-10-06.bin
#   (Restore der alten Tabelle: sgdisk --load-backup=<datei> /dev/nvme0n1 —
#   bringt nur die Tabelle zurueck, die NTFS-Daten sind durch mkfs weg.)
#
# Vorher gesicherte Windows-Nutzerdaten: ~/win-rescue (Desktop, Documents,
# Downloads, Pictures, .claude, .gitconfig). Der Technorama-Ordner wurde
# bewusst nicht gesichert — liegt in der Cloud. Nach dem ersten Mount nach
# /daten verschieben und /daten dem User uebereignen (chown meo:users).
{ ... }:
{
  fileSystems."/daten" = {
    device = "/dev/disk/by-uuid/cd014ae2-4dfd-4967-996f-9ccdcca178d8";
    fsType = "ext4";
    # noatime wie auf /. nofail: der Boot darf nicht an einer fehlenden
    # Daten-Partition scheitern — reine Nutzdaten, nichts Systemrelevantes.
    options = [ "noatime" "nofail" ];
  };
}
