{host, ...}: let
  inherit (import ../../../../hosts/${host}/variables.nix) gitUsername gitEmail;
in {
  programs.git = {
    enable = true;
    signing.format = null;
    settings = {
      user = {
        name = "${gitUsername}";
        email = "${gitEmail}";
      };

      # 1. Zaneys Standard: Cache für alles andere (z.B. eigener Server)
      credential.helper = "cache --timeout=7200";

      # 2. Spezial-Regel für GitHub
      "credential \"https://github.com\"".helper = "!gh auth git-helper";
      "credential \"https://gist.github.com\"".helper = "!gh auth git-helper";

      # 3. NEU: Spezial-Regel für GitLab
      "credential \"https://gitlab.com\"".helper = "!glab auth git-helper";

      push.default = "simple";
      init.defaultBranch = "main";
      log.decorate = "full";
      log.date = "iso";
      merge.conflictStyle = "diff3";

      alias = {
        st = "status";
        # Bequeme Login-Aliase, damit du dir die langen Befehle nicht merken musst:
        login-github = "!gh auth login";
        login-gitlab = "!glab auth login";
      };
    };
  };
}
