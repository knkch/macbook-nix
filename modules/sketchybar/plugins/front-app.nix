ctx:
let
  inherit (ctx) plugin;
in
rec {
  frontApp = plugin "front-app" ''
    if [ "$SENDER" = "front_app_switched" ]; then
      sketchybar --set "$NAME" label="$INFO"
    fi
  '';
}
