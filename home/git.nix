{ ... }:
{
  programs.git = {
    enable       = true;
    userName     = "knkch";
    userEmail    = "255763411+knkch@users.noreply.github.com";
    ignores      = [ ".DS_Store" ];
    delta.enable = true;
  };
}
