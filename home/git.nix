{ ... }:
{
  programs.git = {
    enable       = true;
    userName     = "knkch";
    userEmail    = "255763411+knkch@users.noreply.github.com";  # GitHub の匿名アドレス（非公開のメールを守る設定でもプッシュできる）
    ignores      = [ ".DS_Store" ];
    delta.enable = true;
    # コミットに YubiKey の署名副鍵で署名する（キーは主鍵の指紋。~/fingerprint.txt と同じ）
    signing = {
      key           = "6968645FBDE07A8B8E6AED2F613BEB7098A167D7";
      signByDefault = true;
    };
  };
}
