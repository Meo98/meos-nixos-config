{...}: {
  services = {
    hypridle = {
      enable = true;
      systemdTarget = "graphical-session.target";
      settings = {
        general = {
          after_sleep_cmd = "for m in $(hyprctl monitors | grep '^Monitor' | awk '{print $2}'); do hyprctl dispatch dpms on $m; done && sleep 1 && hyprctl reload";
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
            on-timeout = "for m in $(hyprctl monitors | grep '^Monitor' | awk '{print $2}'); do hyprctl dispatch dpms off $m; done";
            on-resume = "for m in $(hyprctl monitors | grep '^Monitor' | awk '{print $2}'); do hyprctl dispatch dpms on $m; done";
          }
        ];
      };
    };
  };
}
