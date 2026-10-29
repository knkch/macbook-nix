ctx:
let
  inherit (ctx) plugin;
in
rec {
  space = plugin "space" ''
    focused="''${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
    if [ "$1" = "$focused" ]; then
      sketchybar --set "$NAME" background.drawing=on label.color=0xff1a1b26
    else
      sketchybar --set "$NAME" background.drawing=off label.color=0xffc0caf5
    fi
  '';
}
