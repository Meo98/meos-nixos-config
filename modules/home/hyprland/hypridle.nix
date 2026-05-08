{...}: {
  services = {
    hypridle = {
      enable = true;
      systemdTarget = "graphical-session.target";
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on && sleep 1 && hyprctl reload";
          ignore_dbus_inhibit = false;
          lock_cmd = "noctalia-shell ipc call sessionMenu lock";
        };
        listener = [
          {
            timeout = 300;
            on-timeout = "noctalia-shell ipc call sessionMenu lock";
          }
          {
            timeout = 600;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
}
