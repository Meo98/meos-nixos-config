{ pkgs, ... }: {
  # Bun JS runtime. Required by the claude-mem Claude Code plugin
  # (its stop hook calls `bun scripts/bun-runner.js`).
  home.packages = [ pkgs.bun ];
}
