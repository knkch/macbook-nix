{ ... }:
{
  programs.git = {
    enable       = true;
    userName     = "knkch";
    userEmail    = "255763411+knkch@users.noreply.github.com";  # GitHub の匿名アドレス（非公開のメールを守る設定でもプッシュできる）
    ignores      = [ ".DS_Store" ];
    delta.enable = true;
  };
}
