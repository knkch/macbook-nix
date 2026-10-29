// 予定の時間を選ぶ画面（開始・終了のプルダウンと「終日」のチェックボックス）
//   osascript -l JavaScript timepicker.js <見出し> [開始 HH:MM | ""] [終了 HH:MM | ""]
//   出力: "allday" / "<開始> <終了>" / "cancel"
//   開始が空（終日の予定）のときは「終日」にチェックを入れた状態で開く。
//   開始の初期値がなければ次の 15 分区切り、終了の初期値がなければ開始の 1 時間後
ObjC.import("Cocoa");

const pad = n => String(n).padStart(2, "0");
const toMin = t => { const [h, m] = t.split(":").map(Number); return h * 60 + m; };
const toHM = m => pad(Math.floor(m / 60) % 24) + ":" + pad(m % 60);

function run(argv) {
  const [message, defStart, defEnd] = [argv[0] || "時間", argv[1] || "", argv[2] || ""];
  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
  app.activateIgnoringOtherApps(true);

  // 初期値
  const now = new Date();
  const nextQuarter = Math.ceil((now.getHours() * 60 + now.getMinutes() + 1) / 15) * 15;
  const start = defStart || toHM(Math.min(nextQuarter, 23 * 60 + 45));
  const end = defEnd || toHM(Math.min(toMin(start) + 60, 23 * 60 + 45));

  // 候補: 15 分刻み（初期値が刻みにないときはそれも加える）
  const times = [];
  for (let m = 0; m < 24 * 60; m += 15) times.push(toHM(m));
  for (const t of [start, end]) if (!times.includes(t)) times.push(t);
  times.sort((a, b) => toMin(a) - toMin(b));

  const view = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 230, 90));
  const allDay = $.NSButton.checkboxWithTitleTargetAction("終日", $(), $());
  allDay.frame = $.NSMakeRect(0, 64, 200, 22);
  allDay.state = defStart || argv.length < 2 ? 0 : 1;   // 編集で開始が空 = 終日の予定
  view.addSubview(allDay);

  const row = (label, y, value) => {
    const l = $.NSTextField.labelWithString(label);
    l.frame = $.NSMakeRect(0, y + 3, 40, 20);
    view.addSubview(l);
    const p = $.NSPopUpButton.alloc.initWithFramePullsDown($.NSMakeRect(44, y, 110, 26), false);
    p.addItemsWithTitles($(times));
    p.selectItemWithTitle(value);
    view.addSubview(p);
    return p;
  };
  const startPopup = row("開始", 32, start);
  const endPopup = row("終了", 2, end);

  const alert = $.NSAlert.alloc.init;
  alert.messageText = message;
  alert.informativeText = "プルダウンから選んでください（終了が開始より前なら 1 時間の予定にします）";
  alert.addButtonWithTitle("OK");
  alert.addButtonWithTitle("キャンセル");
  alert.accessoryView = view;
  alert.window.level = $.NSFloatingWindowLevel;

  if (alert.runModal !== $.NSAlertFirstButtonReturn) return "cancel";
  if (allDay.state === 1) return "allday";
  const s = ObjC.unwrap(startPopup.titleOfSelectedItem), e = ObjC.unwrap(endPopup.titleOfSelectedItem);
  return s + " " + (toMin(e) > toMin(s) ? e : toHM(Math.min(toMin(s) + 60, 24 * 60 - 1)));
}
