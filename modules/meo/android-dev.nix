# Android development toolkit
#
# Was es einrichtet:
#   - Android Studio (IDE, SDK-Manager, AVD-Manager, eingebettetes JBR)
#   - OpenJDK 17 als zweite, vom System auffindbare JVM
#   - Gradle (für CLI-Builds: ./gradlew oder gradle direkt)
#
# adb ist schon einsatzbereit (android-tools liegt in
# modules/upstream/core/packages.nix, der User ist in der adbusers-Gruppe,
# und ab systemd 258 sind keine extra udev-Regeln mehr nötig).
#
# Was hier NICHT gesetzt wird:
#   - ANDROID_HOME / ANDROID_SDK_ROOT: Android Studio legt das SDK beim
#     ersten Start nach ~/Android/Sdk und konfiguriert sich selbst.
#     Hardcoden im nix würde bei jedem Pfadwechsel einen Rebuild
#     erzwingen.
#   - SDK-Komponenten selbst: bewusst nicht über androidenv deklariert,
#     weil der GUI-SDK-Manager flexibler ist (Lizenz-Klicks, einzelne
#     Build-Tool-Versionen, System-Images für AVDs).
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    android-studio
    jdk17
    gradle
  ];

  environment.sessionVariables = {
    JAVA_HOME = "${pkgs.jdk17.home}";
  };
}
