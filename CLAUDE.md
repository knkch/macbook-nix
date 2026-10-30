# nix-darwin Configuration — KokinoMacBook-Pro

nix-darwin + home-manager による macOS 環境の宣言的管理（git 管理）。
ホスト: `KokinoMacBook-Pro` / アーキテクチャ: `aarch64-darwin` / ユーザー: `konkichi`

## 適用コマンド

```bash
sudo darwin-rebuild switch --flake ~/.config/nix-darwin
# または
rebuild   # zsh エイリアス
```

- flake は **git に add されたファイルしか見えない**。新規ファイルは `git add` してから rebuild。
- ビルドだけ確認: `nix build .#darwinConfigurations.KokinoMacBook-Pro.system --no-link`
- 整形: `nix fmt`

---

## ファイル構成

| ファイル | 役割 |
|----------|------|
| `flake.nix` | inputs / outputs。`user` / `host` はここで一元定義し `specialArgs` で各モジュールへ。`nixpkgs-unstable` は 25.05 にない新しい版が要るものだけ（今は youtube-tui）|
| `modules/system.nix` | nix 設定・ユーザー・PATH・システムパッケージ・macOS defaults（Dock / Spaces / WindowManager 含む）・GC・ファイアウォール（activation） |
| `modules/homebrew.nix` | Homebrew casks / brews / masApps / VS Code 拡張 / cleanup |
| `modules/desktop.nix` | 常駐サービス: jankyborders、menubar-click-guard。sketchybar は `modules/sketchybar/` を読み込む |
| `modules/sketchybar/default.nix` | sketchybar のサービス・バーの設定（`sketchybarrc`）、protected-reader の常駐、集中モードのショートカットの確認 |
| `modules/sketchybar/shared.nix` | 共通部品: `plugin`（スクリプトの作り方）、`focusModes`（集中モードの一覧）、外部コマンドのパス、Wi-Fi の JXA、カレンダーの道具、各プラグインの先頭 `header` |
| `modules/sketchybar/lib.nix` | 各プラグインが読み込む共通関数（`sketchybar-lib.sh`）: 色・メニューの作り方・幅の見積もり・集中モード・カレンダー |
| `modules/sketchybar/action.nix` | メニューの行を押したときの操作（`sketchybar-action`） |
| `modules/sketchybar/plugins/*.nix` | バーの各項目（1 ファイル 1 項目。`build_menu` でメニューを作る） |
| `modules/sketchybar/doctor.nix` | `sketchybar-doctor`（macOS の更新で壊れていないかの点検） |
| `home/default.nix` | ユーザー情報・dotfiles・imports |
| `home/packages.nix` | 一般 CLI / インフラ / クラウドツール |
| `home/security.nix` | セキュリティツール群（`my.security.enable` で一括オン・オフ） |
| `home/shell.nix` | zsh・starship・atuin・zoxide・fzf・bat・eza・lazygit・direnv |
| `home/git.nix` | git + delta |
| `home/nixvim.nix` | Neovim（nixvim）全設定 |
| `home/desktop.nix` | AeroSpace 設定・Ghostty |
| `home/vscode.nix` | VS Code の表示言語のみ（本体・拡張は Homebrew） |
| `home/music.nix` | 音楽: mpd（`~/Music/MyLibrary`、CoreAudio、launchd で常駐。データ / ログのディレクトリは activation で作成）・rmpc（TUI）・mpc・ymuse（GUI）。エイリアス `music` = rmpc |
| `home/yazi.nix` | ファイルマネージャー Yazi（`yy` で開き、終了時にそのフォルダへ移動）。開き方: 写真 → open（プレビュー）、音声 → mpv をターミナル内で（`--no-video`）、動画 → mpv の別ウィンドウ（`O` でターミナル内 `--vo=kitty` も選べる） |
| `home/rmpc/` | rmpc の設定 `config.ron`（0.8.0 の既定値 + アルバムアートは Kitty 方式を明示: cmux は TERM_PROGRAM を出さず自動判定で未対応になる）とテーマ `tokyonight.ron`（作者の公開設定を参考に、上に曲情報 2 行と、その下に操作キーの案内 1 行（表示だけ。rmpc は個別のボタンを置けない。ヘッダーの中は左・中央・右に 3 等分され切れるので、幅全体の `Property` ペインに置く）・下に進行バー、アート 35% / 再生リスト 65%） |
| `pkgs/calendar/` | sketchybar の時計メニューのカレンダー画像を描く `render.py`（メニューを開くたびに約 0.25 秒）、予定の一覧・追加・編集・削除をする `event.js`（JXA + EventKit）、時間を選ぶ画面 `timepicker.js`（JXA + NSAlert / NSPopUpButton） |
| `pkgs/ymuse/` | mpd の GUI ymuse の Mac 向け手直し: nixpkgs の SVG 読み込み部品（librsvg の `libpixbufloader_svg.dylib`）は `@rpath` が解決できず読めないため、コピーして librsvg の場所を書き込み・署名し直し、それを含む `loaders.cache` を使う（ないとボタンのアイコンが灰色の四角）。包み方を変えてアプリ名を `.ymuse-wrapped` でなく `ymuse` に |
| `pkgs/runcat/` | sketchybar の CPU で走る猫のシルエット 5 コマ（`gen.py`、Pillow） |
| `pkgs/menubar-click-guard/` | 画面上端・上の角のクリックを sketchybar に届くよう内側に移す常駐プログラム（C、イベントタップ） |
| `pkgs/ax-agent/` | アクセシビリティが必要な操作（前面アプリのメニューを読む・開く、通知センター・ビデオエフェクトを開く、カメラの使用中の判定、⌃Space などのキー操作）だけを行う常駐プログラム（Objective-C）。sketchybar は `~/Library/Caches/sketchybar-ax/sock` に 1 行で頼む（`ax` 関数、lib.nix）。アクセシビリティはこれだけに与える |
| `pkgs/protected-reader/` | 通知の履歴と集中モードの状態（保護領域）を読み、`~/Library/Caches/sketchybar-protected` に書き出す常駐プログラム（Objective-C）。フルディスクアクセスはこれだけに与える |
| `pkgs/focus-shortcuts/` | 集中モードの切り替え用ショートカットを用意するコマンド `focus-shortcuts`。中身（署名前）は `gen.py` でビルド時に作り、署名と取り込みは実行時。モードの一覧は modules/sketchybar/shared.nix の `focusModes` |

### 配置の原則

| 種別 | 置き場所 |
|------|----------|
| システム全体・ネットワーク CLI | `environment.systemPackages` (modules/system.nix) |
| ユーザー開発ツール | `home.packages` / `programs.*` (home/*.nix) |
| 頻繁に更新したい CLI / GUI アプリ | `homebrew.casks` (modules/homebrew.nix) |
| GUI アプリ（App Store） | `homebrew.masApps` (modules/homebrew.nix) |
| 常駐サービス | nix-darwin `services.*` / `launchd.user.agents.*` (modules/desktop.nix・modules/sketchybar/) |
| dotfiles | `home.file.*` / `xdg.configFile.*` / `programs.*` |

---

## Homebrew の方針

- **Brewfile が唯一の正**。rebuild 時に `brew bundle cleanup --force` が走り、
  Brewfile にない cask / formula / App Store アプリ / VS Code 拡張は **アンインストールされる**（zap はしない）。
  → 手動で `brew install` したものは必ず `modules/homebrew.nix` にも追加する。
  - Homebrew 7 で `brew bundle --cleanup` フラグが廃止され、nix-darwin 25.05 の
    `onActivation.cleanup` が使えないため、activation script で自前実行している。
- `onActivation.autoUpdate` / `upgrade` が有効 → rebuild のたびに cask も最新化される。
- サードパーティ tap の cask（cmux / chiaki-ng / aerospace）は Homebrew 7 の要件で
  `trusted: true` が必要 → `trustedCasks` に書く（`casks` には書かない）。
- VS Code 拡張は `vscodeExtensions` に書く。依存で自動インストールされる拡張も列挙しないと cleanup で消える。

### Claude Code

- **cask `claude-code`** で管理（nixpkgs-25.05 版は古く更新されないため）。
- 更新: `rebuild` または `brew upgrade --cask claude-code`。
- より新しいチャネルが欲しい場合は `claude-code@latest` に差し替え
  （両者は同じ `claude` を提供するので、先に `brew uninstall --cask claude-code`）。
- PATH: `environment.systemPath` に `/opt/homebrew/bin` を追加済み（Nix のパスより後ろ）。

### masApps

| アプリ | ID | 理由 |
|--------|----|------|
| WireGuard | 1451685025 | GUI 設定が必要 |
| Tailscale | 1475387142 | System Extension の権限が安定 |
| Slack | 803453959 | 通知の動作が安定 |
| Windows App | 1295203466 | 旧 Microsoft Remote Desktop |
| Microsoft Excel | 462058435 | |
| Brother iPrint&Scan | 1193539993 | |

> macSKK / XLD は mas インストール失敗のため cask で管理。
> webex は App Store 版もあるが、画面共有・マイク権限問題のため cask。zoom も cask で管理。

### 既存アプリを cask 管理へ移す場合

nix-darwin 25.05 の cask 指定には `--adopt` がないため、手動インストール済みのアプリをそのまま
`casks` に書くと rebuild が「既にアプリがある」で失敗する。先に `brew install --cask --adopt <cask>` で
取り込んでから `casks` に追記する（例: `media-center`）。

### Nix / Homebrew 管理外のアプリ（手動インストール）

| アプリ | 理由 |
|--------|------|
| Parallels Desktop 26 | cask は 27（有償のメジャー更新）。取り込むとライセンス外の版へ上がるおそれ |
| VMware Fusion 13 | cask 廃止（Broadcom アカウント経由の配布のみ） |
| MakeMKV 2.0 | cask（1.18.x）より新しい版を手動導入済み |
| e-Gov電子申請アプリケーション | cask なし。Intel 専用 |
| Pioneer DJ FwUpdateManager（`/Applications/Pioneer`） | rekordbox のインストーラが同梱で導入。単体の cask なし（rekordbox 本体は cask 管理） |
| Brother ドライバ（Push Scan Tool） | pkg インストーラ。Intel 専用の常駐プロセスあり（印刷は AirPrint のため不要） |

---

## デスクトップ

| 要素 | 管理 | 備考 |
|------|------|------|
| AeroSpace | 本体: cask / 設定: `programs.aerospace`（home/desktop.nix） | `start-at-login = true`。キー割当は下記 |
| sketchybar | `services.sketchybar`（modules/sketchybar/） | バーの左右の端の余白 12。`notch_width=186`（実際のノッチ幅 185 に合わせ、ノッチ左右の項目を寄せる）。左: Apple メニュー・ワークスペース 1〜9・前面アプリ / ノッチの左: 再生中の曲・右: CPU で走る猫 / 右: VPN・ネットワーク・Bluetooth・入力ソース・音量・電池・時計・通知（右端）。`topmost=on` で、上端にマウスを寄せて出てくる標準メニューバーを覆い隠す |
| jankyborders | `services.jankyborders`（modules/desktop.nix） | round, width=2（隙間 3 に合わせる） |
| メニューバー | `_HIHideMenuBar = false` | 標準メニューバーは常に表示し、sketchybar（同じ高さ 33・より上のレベル）で覆う。自動非表示にすると通知バナーが最上部に出て sketchybar の裏に潜る |
| AeroSpace ギャップ | `gaps`（home/desktop.nix） | すべて `3`。上は macOS がメニューバー分を空けるので内蔵画面 `3`（メニューバー ≒ バー 33）、外部モニター `12`（メニューバー 24 前後とバー 33 の差 9 + 3。未確認）。sketchybar を無効にするときは上も `3` に |
| Spaces | `spans-displays = true` | AeroSpace 推奨（ディスプレイごとの個別スペースをオフ）。反映にはログアウトが必要 |
| Dock | `autohide = true` / `mru-spaces = false` / `expose-group-apps = true` | 自動非表示・スペース自動並べ替えオフ・Mission Control でアプリごとにグループ化 |
| WindowManager | `GloballyEnabled` / `EnableStandardClickToShowDesktop` / `EnableTilingByEdgeDrag` / `EnableTopTilingByEdgeDrag` / `EnableTilingOptionAccelerator` すべて `false` | ステージマネージャ・壁紙クリックでデスクトップ表示・macOS 標準タイル機能をオフ（AeroSpace と競合するため） |

sketchybar の項目（クリックでメニュー。メニューは開くたびに作り直して最新の状態を表示）:

| 項目 | バーの表示 | メニュー |
|------|------|------|
| Apple | アイコン | この Mac について / システム設定 / ソフトウェアアップデート / App Store / アクティビティモニタ / スリープ / 画面ロック（`pmset displaysleepnow`）/ 再起動・システム終了・ログアウト（確認ダイアログ） |
| 前面アプリ | アプリ名（緑） | そのアプリのメニュー（ファイル・編集…）の一覧。メニューは ax-agent が読み、選ぶと ax-agent が隠れている標準メニューバーの項目を押して、本物のメニューがバーのすぐ下に開く（前面アプリのものだけ）。メニューを検索（⌘⇧/ を送る） |
| VPN | Tailscale か他の VPN が接続中なら緑 | Tailscale の状態・接続/切断・出口ノード選択（CLI `/usr/local/bin/tailscale`）、システムの VPN 一覧をクリックで接続/切断（`scutil --nc`、Tailscale は除外）、VPN 設定 |
| ネットワーク | 有線 > Wi-Fi の順でアイコンのみ | Wi-Fi オン/オフ、接続中のネットワーク、**周囲のネットワーク一覧**（CoreWLAN でスキャン、電波の強さ・鍵の有無をアイコン表示、クリックで接続。鍵ありで未登録ならパスワードを尋ねる）、有線 IP・Wi-Fi IP・ルーター・DNS、Wi-Fi / ネットワーク設定 |
| Bluetooth | オフ / オン / 接続中で色分け（`blueutil`） | オン/オフ、ペアリング済みデバイスをクリックで接続/切断、Bluetooth 設定 |
| 音量 | スクロールで音量調整 | 出力音量スライダー（右に %）・ミュート・出力デバイス選択、入力音量スライダー（右に %）・入力デバイス選択（`SwitchAudioSource`）、サウンド設定 |
| 電池 | 残量 | 残量・電源・残り時間、**電力モード**（自動 / 低電力 / 高出力をバッテリー・電源アダプタ別に。`pmset powermode`、変更時に管理者パスワードの画面が出る）、アクティビティモニタ、バッテリー設定 |
| 入力ソース | あ / A / カ など | 有効な入力ソース一覧（現在のものに印）、次の入力ソースへ（⌃Space を送る）、絵文字と記号、キーボード設定 |
| 再生中の曲 | ノッチのすぐ左（`position q`）。再生中は曲名、一時停止中は薄く、停止中は「♪ 停止中」、曲名を隠すとアイコンだけ、mpd に接続できなければ「♪ オフ」 | アルバム・曲名・アーティスト、前の曲 / 再生・一時停止 / 次の曲（`mpc`）、ymuse を開く（cmux は外のプロセスからの操作を受け付けないため rmpc は開かない。どちらも同じ mpd を操作）。停止（表示も消える）、曲名を隠す（その曲のあいだだけアイコンのみ。`$TMPDIR/sketchybar-music-hidden` に曲を記録）。`mpc idle` のループで変化を待つ |
| CPU で走る猫 | ノッチのすぐ右（`position e`） | RunCat 風（絵はオリジナル、`pkgs/runcat`）。CPU 使用率（`ps` の合計 / コア数）を約 1 秒ごとに測り、コマ間隔 0.2〜0.03 秒で走る速さを変える。右に使用率 |
| カメラ | 使用中だけ表示（緑 + 「使用中」） | メニューなし。押すと使用中のカメラのビデオエフェクト（標準メニューバーの `com.apple.menuextra.audiovideo` を ax-agent が押す）。使用状態はコントロールセンターの表示（`com.apple.menuextra.controlcenter` の説明に「カメラ」）で判定: AVFoundation の `isInUseByAnotherApplication` は sketchybar にカメラ許可がないと常に未使用を返す |
| 通知（右端） | ベル + 赤いバッジ（消去後に届いた件数、10 件以上は 9+） | 最新 15 件の通知一覧（クリックでそのアプリを開く）・すべて消去、通知センターを開く（隠れた標準メニューバーの時計を ax-agent が押す）、通知設定、集中モード（下記）、ショートカットを追加（足りなければ `focus-shortcuts` で取り込み、そろっていればショートカットアプリを開く）、集中モード設定 |
| 時計 | 日付・曜日・時刻 | 大きな時刻（中央）、**画像で描く月カレンダー**（`pkgs/calendar/render.py`、Pillow + ヒラギノ。月送り・曜日・6 週の行を別々の画像に。日曜・祝日は赤、土曜は青、今日は塗りの丸、選んだ日は輪、予定のある日は右上に件数のバッジ、前後の月は薄く。祝日はカレンダー「日本の祝日」から）、**日付を押すとその日の予定**（最大 5 行。`event.js list` で読み、行を押すと**編集**（タイトル・時間・通知）/ **削除**。祝日など読み取り専用は不可）、**予定を追加…**（選んだ日に。タイトル → 時間（`pkgs/calendar/timepicker.js` の画面: 開始・終了を 15 分刻みのプルダウンで選ぶ / 終日のチェック）→ カレンダー → 通知（開始の何分前か。終日は当日 9 時。EKAlarm で付けるので macOS が通知を出す）を入力画面で尋ね、`pkgs/calendar/event.js` が EventKit で登録。カレンダーアプリは開かない）、カレンダーのアカウント（インターネットアカウント設定を開く。Google / Outlook を追加すると予定の表示・追加先になり同期される）、日付と時刻設定 |

- sketchybar 本体はパッチ版（`services.sketchybar.package`）。`topmost=on` のバーのウィンドウレベルを
  ステータス（macOS のメニューバーアイコンと同じ）→ PopUpMenu - 1 に上げ、バーの端のクリックが隠れた標準メニューバーに抜けないようにしている。
  バーの高さは標準メニューバーと同じ 33（32 だと下端 1px が標準メニューバーに当たる）。
  バイナリが変わると macOS の許可（アクセシビリティ等）を付け直す必要がある。
- それでも画面の一番上の行と上の角のクリックは macOS が標準メニューバーに渡すため、`menubar-click-guard`
  （launchd ユーザーエージェント）がクリック位置を上端から 3px・角から 12px 内側に移す。
  アクセシビリティの許可が必要（`/nix/store/…-menubar-click-guard-1.0/bin/menubar-click-guard`）。
  許可がないと起動に失敗して 30 秒ごとに再試行する。ログ: `/tmp/menubar-click-guard.log`。
- メニューのクリックできる行は、マウスが乗るとハイライト（`hover` スクリプト、`mouse.entered` / `mouse.exited`）。
  ハイライトが行全体に付くよう、クリックできる行の幅を揃える。幅は**表示する前に**文字数から見積もって決める
  （`estimate` / `apply_widths`。実測: 英数字 1 文字 ≒ 7.5、全角 ≒ 12.5）。表示後に幅を変えるとメニューが左右にずれるため。
- メニューはバーに隙間なく付ける（`popup.y_offset=0`）。隙間があるとマウスがそこを通るときにメニューが閉じる。
- バーの色は不透明（`0xff1a1b26`）。常に表示している標準メニューバーが下から透けないように。
- メニュー（ポップアップ）は少し透かしてぼかす（`0xb01a1b26` + `popup.blur_radius=30`）。
- メニューの中身は `BATCH` に貯めて、古い行の削除と一緒に 1 回の sketchybar 呼び出しで送る（裏の Wi-Fi スキャン後の作り直しなどと
  重なっても行の順番が崩れないように）。Wi-Fi のスキャンは同時に 1 本だけ（`~/Library/Caches/sketchybar-wifi-scan.lock`）。
- カレンダーの操作: 月送りの行と週の行は、画像を行の背景に敷き、行全体を透明なスライダーにして押した位置（%）を受け取る
  （月送り: 左 2 割 = 前月 / 右 2 割 = 翌月 / 中央 = 今月。週: 7 等分してその日を選ぶ。各週の日付は `$TMPDIR/sketchybar-calendar/dates`）。
  スライダーの帯に画像を敷くと二重に描かれ、帯の外のクリックは無視される。操作時はメニューを作り直さず、画像と予定の行の中身だけ差し替える
  （作り直すと直後のクリックが消えた行に向かいメニューが閉じる）。時計のメニューは `popup.height=26` で行を詰めている。
- 構成: modules/sketchybar/ に、共通部品 `shared.nix`、共通関数 `lib.nix`（メニュー項目の追加・開閉）、操作 `action.nix`、
  各項目のプラグイン `plugins/`（`build_menu` でメニューを作る）。各ファイルは `ctx`（全部の部品をまとめたもの）を受け取り、
  自分の部品を返す（`default.nix` で `lib.fix` を使ってまとめる）。ほかのファイルの部品は `inherit (ctx) …` で使う。
- 部品を足したら `nix run nixpkgs#deadnix -- modules/sketchybar` で使っていない名前がないか確かめる。
- 初回に許可が必要: Bluetooth（`blueutil`）、カレンダー（`icalBuddy`）は sketchybar に対して許可する。
  **アクセシビリティとフルディスクアクセスは sketchybar に与えない**（それぞれ ax-agent・protected-reader だけ。下記）。
  **フルディスクアクセスは sketchybar に与えない**（protected-reader だけ。下記）。
- 接続中の SSID は位置情報保護で取れないため、今の接続のチャンネルと RSSI を直近のスキャン結果
  （`~/Library/Caches/sketchybar-wifi-scan`）と照らし合わせて推定する。スキャンは約 5 秒かかるので、
  メニューは前回の結果で開き、裏でスキャンして終わったら作り直す。
- カメラの一覧・Wi-Fi のスキャンは JXA（`osascript -l JavaScript`）で AVFoundation / CoreWLAN を呼ぶ。カメラの使用状態はコントロールセンターの表示から読む（上の表）。
- 通知メニューのアイコンは設定を開く行だけ。
- **保護領域の読み取りは protected-reader に分けている**（pkgs/protected-reader、launchd のユーザーエージェント）。
  sketchybar は外からのコマンド（`sketchybar --set … script=…`）で任意のスクリプトを自分の権限で実行できるので、
  sketchybar にフルディスクアクセスを与えると、この Mac の何からでも保護されたデータを読めてしまう。そのため:
  - protected-reader（フルディスクアクセスあり）が 0.5 秒ごとに更新を見て、変わったときだけ読み、必要な分だけを
    `~/Library/Caches/sketchybar-protected/` に書き出す（自分だけが読める。`notifications` = 最新 99 件、`focus` = オンの集中モード）。
  - 読むファイルはプログラムに固定（引数で変えられない）。通知が変わると `notify_update` を送るので、ベルのバッジはすぐ更新される。
  - 読めない理由は `/tmp/protected-reader.log`（`authorization denied` = 許可がない、`no such table / column` = macOS 側の形式が変わった）。
- **アクセシビリティの操作は ax-agent に分けている**（pkgs/ax-agent、launchd のユーザーエージェント）。理由は protected-reader と同じ
  （sketchybar にアクセシビリティを与えると、この Mac の何からでも画面を操作できてしまう）。
  - sketchybar は `ax <操作>`（lib.nix。`nc -U` で `~/Library/Caches/sketchybar-ax/sock` に 1 行送る）で頼む。ソケットとディレクトリは自分だけが使える。
  - できる操作は固定: `menus` / `menu-open <pid> <番号>`（前面アプリだけ）/ `extra-click clock|audiovideo` / `camera` / `key ime-next|emoji|menu-search` / `extras` / `trusted`。
  - System Events（osascript）は使わない: Apple Events では許可の確認が osascript に対して行われ、sketchybar の許可が効かないため。
  - sketchybar には**オートメーション（System Events）も与えない**（使っていない）。一覧に出たら画面からは外せない（.app でないため）ので
    `tccutil reset AppleEvents`（全アプリのオートメーション許可を消す。cmux などは次に使うときにまた聞かれる）。
  - 許可がないと `ERROR noaccess` を返し、`/tmp/ax-agent.log` に出す。点検は `sketchybar-doctor`。
  - 前面アプリは NSWorkspace で取る（AX の `kAXFocusedApplicationAttribute` は launchd から動かすと取れなかった）。
- 通知一覧は、protected-reader が通知センターのデータベース（`~/Library/Group Containers/group.com.apple.usernoted/db2/db`）から
  書き出したものを `notifList`（Python）で読む（読めない場合はメニューに案内を表示）。
  「すべて消去」は消去した時刻を `~/Library/Caches/sketchybar-notify-cleared` に記録して、それより前を表示しないだけ（macOS の通知センター側は消えない。DB は書き換えない）。
- 集中モード: ショートカット「集中モード: <名前> オン / オフ」（`is.workflow.actions.dnd.set`。モードは識別子で指定、オンは `Enabled: 1`、オフは指定なし）を
  通知メニューに 1 モード 1 行で並べ、押すと今の状態の逆を実行。今の状態は `~/Library/DoNotDisturb/DB/Assertions.json` を protected-reader が書き出したもの（`focus`）から読み、
  オンは ● と緑。ショートカットの名前は NFD（濁点が分かれた形）で返るので `nfc` で揃えて比べる。
  - **モードの一覧は `focusModes`（modules/sketchybar/shared.nix）が唯一の正**。ここから `focus_id`（名前 → 識別子）と、`focus-shortcuts` が取り込むショートカットの中身の両方を作る。
  - メニューに出るのは、ショートカットがあるモード（`shortcuts list` から探す。フォルダの中も含む）。`focusModes` にないモードは状態が分からず、押すと毎回「オン」を実行する。
  - 「ショートカットを追加…」は、足りないショートカットがあれば `focus-shortcuts` で取り込み画面を開き、そろっていればショートカットアプリを開く。
  - rebuild のたびに `focus-shortcuts --check` で確認だけ行い、足りなければメッセージを出す（取り込み画面は勝手に開かない）。
  - 標準モードの識別子: おやすみ `com.apple.donotdisturb.mode.default` / 睡眠 `com.apple.sleep.sleep-mode` / 仕事 `com.apple.focus.work` /
    パーソナル `com.apple.focus.personal-time` / 割り込みを減らす `com.apple.focus.reduce-interruptions`。
    それ以外（自分で作ったモードなど）の識別子は、そのモードをオンにした状態で Assertions.json の `assertionDetailsModeIdentifier` を見る（フルディスクアクセスが必要）。
  - ショートカットはフォルダ「SketchyBar」にまとめている（フォルダは手作業。コマンドから作れない）。
- 入力ソースを直接選んで切り替える CLI（macism など）は Homebrew / nixpkgs にないため、一覧は表示のみ。

sketchybar を無効にする手順: `services.sketchybar.enable = false`、AeroSpace の `gaps.outer.top = 3`（単一値に戻す）。AeroSpace の `exec-on-workspace-change`（sketchybar への通知）は
`osConfig.services.sketchybar.enable` に連動して自動で有効・無効になる。

AeroSpace 導入時の手動作業: アクセシビリティ許可（プライバシーとセキュリティ > アクセシビリティ）、
`spans-displays` 反映のためのログアウト、標準の Space を各ディスプレイ 1 つに減らす。

AeroSpace のレイアウト: 通常のウィンドウは必ずタイル（`default-root-container-layout = "tiles"`、
`accordion-padding = 0`）。フローティングはタイルの後ろに隠れることがある（AeroSpace は手前に固定できない）ので、
`on-window-detected` で浮かせるのはピクチャインピクチャ・Finder の情報/コピー進行状況・アーカイブユーティリティ・
Digital Color Meter だけ（ダイアログ・シートは AeroSpace が自動で浮かせる）。手動の切り替えは `alt-shift-f`。

緑のボタン（macOS のフルスクリーン）は別の Space を作り、そこには sketchybar が出ない（標準メニューバーは上端にマウスを寄せると出る）。
最大化は `alt-f`（AeroSpace のフルスクリーン。外側の隙間を残すので sketchybar も見える）を使う。

AeroSpace キー: `alt-hjkl` フォーカス / `alt-shift-hjkl` 移動 / `alt-N`・`alt-shift-N` ワークスペース /
`alt-f` フルスクリーン / `alt-tab` ワークスペースを次のモニターへ。

---

## 冪等性と手作業の設定

方針: **このリポジトリと `rebuild` だけで、何回実行しても同じ状態になる**ようにする。
`rebuild` で入れられないもの（macOS が外からの設定を許さないもの）は、下の一覧にまとめて手順を残す。

- 起動時の処理（activation）は、すでにその状態なら何もしない作りにする（`mkdir -p`、Rosetta は入っていれば飛ばす、`focus-shortcuts --check` は確認だけ）。
- Homebrew は Brewfile にないものを毎回消すので、書いた内容と一致する。ただし `autoUpdate` / `upgrade` が有効なので、
  **入る版は実行した日によって変わる**（Claude Code などを常に最新にするための意図した設定。版の固定はしない）。
- Nix のパッケージの版は `flake.lock` で固定。更新は `nix flake update` → `rebuild`。
- ファイアウォールとステルスモードは activation で `socketfilterfw` を使ってオンにする（modules/system.nix）。
  `system.defaults.alf`（com.apple.alf の defaults）は macOS 15 以降効かないので使わない。
  外からの接続を許可するアプリの一覧（`socketfilterfw --listapps`）は管理しない（2026-10-30 時点で /usr/bin/python3・ruby が許可されたまま）。
- macOS の許可（TCC: アクセシビリティ・フルディスクアクセス・オートメーションなど）と FileVault は、macOS の仕様で設定ファイルから入れられない → 下の一覧で手作業。
  許可を与えるプログラムは決まった場所（nix store）にあり、パッケージが変わると付け直し（`sketchybar-doctor` がパスを示す）。
- `pkgs/ymuse` は nixpkgs の librsvg / gdk-pixbuf のファイル配置（`lib/gdk-pixbuf-2.0/2.10.0/loaders/…`、`librsvg-2.2.dylib`）に頼っている。
  `nix flake update` で配置が変わると、SVG が入っていなければビルドが止まる（`grep -q svg`）。nixpkgs 側で直れば手直しは不要になる。
- 既存の Mac では、Brewfile から外したもの（例: Rigelian）は `rebuild` の片付けでアンインストールされる。新しい Mac では入らないだけ。
- **リモートの git リポジトリはまだない**。この Mac が壊れると設定も失われるので、プライベートなリポジトリへの push を推奨。

### 手作業が必要な設定（新しい Mac・作り直したとき）

| 何を | どこで | 理由・メモ |
|------|--------|------------|
| Nix と Homebrew のインストール、このリポジトリを `~/.config/nix-darwin` に置く | ターミナル | rebuild の前提（README の「新しい Mac にセットアップする」） |
| **FileVault** をオン | プライバシーとセキュリティ > FileVault | ディスクの暗号化。ノート PC なので必須。`sketchybar-doctor` で点検 |
| protected-reader に **フルディスクアクセス** | プライバシーとセキュリティ > フルディスクアクセス で「＋」→ ⌘⇧G でパスを入力 | 通知一覧・集中モードの状態を読む。パスは `launchctl print gui/$(id -u)/org.nixos.protected-reader \| grep program`。**sketchybar には与えない**（与えていたら外す） |
| ax-agent に **アクセシビリティ** | 同 > アクセシビリティ | アプリのメニュー、通知センター・ビデオエフェクトを開く、カメラの判定、入力ソース切り替え、絵文字。パスは `launchctl print gui/$(id -u)/org.nixos.ax-agent \| grep program`。**sketchybar には与えない**（与えていたら外す） |
| sketchybar に **Bluetooth**・**カレンダー** | 初回に出る確認で許可 | `blueutil`、`icalBuddy` / `event.js` |
| menubar-click-guard に **アクセシビリティ** | プライバシーとセキュリティ > アクセシビリティ | パスは `/nix/store/…-menubar-click-guard-1.0/bin/menubar-click-guard`。許可がないと 30 秒ごとに再試行 |
| AeroSpace に **アクセシビリティ** | 同上 | ウィンドウ操作 |
| 標準の Space を各ディスプレイ 1 つに、ログアウト | Mission Control・ログアウト | AeroSpace と `spans-displays` の反映 |
| 集中モード（おやすみ・睡眠・仕事）を追加 | システム設定 > 集中モード | 追加されていないモードは切り替えられない |
| 集中モードのショートカットを取り込む | `focus-shortcuts` を実行 →「ショートカットを追加」を押す | 署名と取り込みの確認は macOS の仕様で手作業。その後フォルダ「SketchyBar」へ移す |
| Blu-ray の `keydb.cfg` | `~/Library/Preferences/aacs/` に置く | FindVUK Online Database から手動ダウンロード |
| Nix / Homebrew 管理外のアプリ | 各配布元 | 上の「Nix / Homebrew 管理外のアプリ」の表 |

- sketchybar・menubar-click-guard・protected-reader・ax-agent は、パッケージが変わる（nix store のパスが変わる）と許可を付け直す必要がある。
  パスが変わるのは、そのプログラム自体か、ビルドに使う道具（`nix flake update` で nixpkgs を更新したときなど）が変わったときだけ。
  ふだんの設定変更（メニューの中身など）では変わらない。古いパスの許可は一覧に残るので、ときどき削除する。
- 付け直しが必要かどうかは `sketchybar-doctor` で分かる（動いていない・読めない項目と、その直し方を表示）。
- 許可を付け直さずに済ませるには、決まった場所へのコピーと、自分で作った証明書での署名が必要（未対応。手間に対して効果が小さいため）。

### macOS の更新で壊れうる箇所

sketchybar は macOS が公開していない仕組みに頼っている。macOS を更新したら `sketchybar-doctor` を実行する。

| 頼っているもの | 使う場所 | 壊れたときの症状 |
|----------------|----------|------------------|
| 通知センターのデータベースの形式（`record` / `app` テーブル、`req` の `titl` / `subt` / `body`） | pkgs/protected-reader | 通知一覧が「読めない」 |
| 集中モードの状態ファイル `Assertions.json` の形式 | pkgs/protected-reader | 集中モードが常に ○ |
| コントロールセンターの項目の識別子（`com.apple.menuextra.clock` / `.controlcenter` / `.audiovideo`） | pkgs/ax-agent/main.m | 通知センター・ビデオエフェクトが開かない、カメラが出ない |
| sketchybar 本体のソース（`bar_manager.c` の 1 行） | default.nix のパッチ | ビルドが失敗する（`--replace-fail`） |
| 画面上端のクリックの扱い | pkgs/menubar-click-guard | 上端のクリックが標準メニューバーに抜ける |
| ショートカットの「集中モードを設定」アクションの形式 | pkgs/focus-shortcuts/gen.py | 取り込んだショートカットが動かない |

---

## メディア（音楽・動画・写真）

| 種類 | 裏で動くもの | 操作画面 | 起動 |
|------|--------------|----------|------|
| 音楽 | mpd（+ mpc） | rmpc（TUI）/ ymuse（GUI） | `music` / `ymuse`・sketchybar の曲メニュー |
| YouTube | mpv | youtube-tui（TUI） | `youtube` |
| 手元の動画・音声・写真 | mpv / プレビュー | Yazi（TUI） | `yy` |

- rmpc: 操作ボタンを置く機能はない（0.8.0・最新の 0.11 とも。ヘッダーのクリックで再生/一時停止、スクロールで音量、
  進行バーのクリックでその位置へ、だけ）。代わりにヘッダーの下に操作キーの案内の行を表示（home/rmpc/tokyonight.ron）。
  ボタンで操作したいときは ymuse。
- ymuse: Rigelian（有料・App Store）の代わり。無料で Mac で使える mpd の GUI はほぼこれだけ
  （Cantata・myMPD・Plattenalbum・Sonata・mpdevil は nixpkgs で Linux 専用、Persephone は Homebrew から消えた）。
  GTK なので見た目は Mac らしくない。`.app` はなく、コマンドで起動。iPhone から操作する手段はない。
- youtube-tui: **0.9.4 を nixpkgs-unstable から**取る（flake の入力 `nixpkgs-unstable`、home-manager に `pkgsUnstable` で渡す）。
  25.05 の 0.8.1 は Invidious が返す -1（Mix などの動画数）を読めず、検索が「Cannot deserialize response: invalid value: integer `-1`, expected u32」で失敗する。
  0.9 は Rust 1.88 以上が要り、25.05（Rust 1.86）ではビルドできない。nixpkgs を上げたら `pkgs.youtube-tui` に戻し、unstable の入力も外せるか確かめる。
  - 設定 `~/.config/youtube-tui/main.yml` は activation で**普通のファイルとして書き込む**（home/packages.nix）。
    youtube-tui は起動のたびに main.yml を書き直すので、読み取り専用のリンク（xdg.configFile）にすると検索が「Loading…」のまま止まる。
    ほかの *.yml（search.yml は直前の検索を保存する）は youtube-tui が作るので管理しない。
  - 検索は YouTube から直接（`search_provider = RustyPipe`）。Invidious（`invidious_instance`）は動画の詳細などに使う。
    公開サーバーの多くは外部からの利用を止めていて、2026-10-30 時点で通ったのは `yt.chocolatemoo53.com`（既定の vid.puffyan.us は停止済み）。
    使えなくなったら https://api.invidious.io で探して差し替える。
  - 再生は mpv + **yt-dlp**（yt-dlp がないと YouTube を再生できない）。YouTube 側の変更で yt-dlp が古くなると再生できなくなる → `nix flake update`。
  - 画像は HalfBlocks（cmux は Sixel 非対応）、ブラウザは `open`、保存は `env` で裏で実行（既定は Linux 向けの xdg-open / konsole）。
  ytfzf（検索して 1 本選ぶだけ、TUI ではない）は試して外した。
- mpv を外から操作する TUI（mpvc / mpvc-tui）は nixpkgs で Linux 専用。必要なら自分でパッケージ化（シェルスクリプト + socat）。

---

## シェル

- zsh: autosuggestion / syntax highlighting。補完は home-manager の compinit と nix パッケージ同梱の補完を使用。
- `<C-r>`: atuin（fzf の割当を上書き）/ `<C-t>`: fzf ファイル / `Alt-c`: fzf ディレクトリ
- エイリアス: `rebuild`, `ll`, `lg`, `cat`(bat), `ls`(eza), `vlc-bd`, `music`(rmpc), `youtube`(youtube-tui)
- `yy`: Yazi（home/yazi.nix）。終了するとそのフォルダへ移動する
- `vlc-bd`: `open --env JAVA_HOME=…openjdk@17 -a VLC`（`open` は通常の環境変数を引き継がないため `--env`）

---

## macOS 制限・非対応ツール

| ツール | 状態 | 代替 |
|--------|------|------|
| `hping3` | nixpkgs-25.05-darwin 未対応 | OrbStack の Linux VM |
| `bettercap` | nixpkgs-25.05 で broken | OrbStack の Linux VM / proxyman |
| `angry-ip-scanner` / `owasp-zap` | 2026-09 以降 Gatekeeper で起動不可 | `network-radar` / `caido` |
| `aircrack-ng` | モニターモード非対応 | 解析のみ |
| Wireshark | キャプチャに ChmodBPF が必要 | 導入済み（`/Library/LaunchDaemons/org.wireshark.ChmodBPF.plist`） |

### Alfred
アプリ説明はほぼ全アプリが Spotlight メタデータを空にしているため表示不可。
Workflow「Brew Cask Finder」で `cask {キーワード}` 検索。

---

## 今後の課題

- protected-reader: 通知を読めなかったとき、ファイルを直接開いた結果（`Operation not permitted` = 許可がない）もログに出すと、
  `sketchybar-doctor` で原因がはっきりする。ただし直すとプログラムのパスが変わり許可の付け直しが要るので、
  `nix flake update` など、どのみち付け直すときに一緒に入れる。ax-agent も同じ（直すと許可の付け直しが要る）。
- 未確認: Yazi の画像プレビューと mpv のターミナル内再生（`--vo=kitty`）が cmux で表示されるか。
  出なければ rmpc と同じく Kitty 方式の明示が要るかもしれない。
- nixpkgs / nix-darwin / home-manager 25.05 → 新しいリリースへ更新。そのとき youtube-tui を `pkgs` に戻し、`nixpkgs-unstable` の入力を外せるか確かめる。
  その際 `programs.git.userName/userEmail` → `programs.git.settings.user.*`、
  `programs.git.delta` → `programs.delta` などの移行が必要。
