// sketchybar のカレンダーから予定を扱う（EventKit。カレンダーアプリは開かない）
//   osascript -l JavaScript event.js calendars
//       → 予定を追加できるカレンダーの名前（1 行ずつ。最初が既定のカレンダー）
//   osascript -l JavaScript event.js add <YYYY-MM-DD> <タイトル> <開始 HH:MM | ""> <終了 HH:MM | ""> <カレンダー名> [通知]
//       → 開始が空なら終日。終了が空なら開始の 1 時間後。成功で "ok"、失敗でエラー内容
//       → 通知: 開始の何分前に知らせるか（0 = 開始時、空 = 通知なし）。終日の予定は当日の朝 9 時に知らせる
// カレンダーへのアクセス許可は、呼び出し元（sketchybar）のものを使う
ObjC.import("EventKit");

function run(argv) {
  const store = $.EKEventStore.alloc.init;
  const writable = ObjC.unwrap(store.calendarsForEntityType(0))   // 0 = 予定
    .filter(c => c.allowsContentModifications);
  const def = store.defaultCalendarForNewEvents;
  const defTitle = def && !def.isNil() ? ObjC.unwrap(def.title) : null;

  if (argv[0] === "calendars") {
    const names = writable.map(c => ObjC.unwrap(c.title));
    names.sort((a, b) => (b === defTitle) - (a === defTitle));
    return names.join("\n");
  }

  if (argv[0] === "add") {
    const [, day, title, startHM, endHM, calName, alarmMin] = argv;
    const [y, m, d] = day.split("-").map(Number);
    const at = (hm, plusMin) => {
      const [h, mi] = hm.split(":").map(Number);
      return new Date(y, m - 1, d, h, mi + (plusMin || 0));
    };
    const ev = $.EKEvent.eventWithEventStore(store);
    ev.title = title;
    if (!startHM) {
      ev.allDay = true;
      ev.startDate = $.NSDate.dateWithTimeIntervalSince1970(new Date(y, m - 1, d).getTime() / 1000);
      ev.endDate = ev.startDate;
    } else {
      const s = at(startHM), e = endHM ? at(endHM) : at(startHM, 60);
      ev.startDate = $.NSDate.dateWithTimeIntervalSince1970(s.getTime() / 1000);
      ev.endDate = $.NSDate.dateWithTimeIntervalSince1970(e.getTime() / 1000);
    }
    const cal = writable.find(c => ObjC.unwrap(c.title) === calName) || def;
    if (!cal || cal.isNil()) return "予定を追加できるカレンダーがありません";
    ev.calendar = cal;
    if (alarmMin !== undefined && alarmMin !== "") {
      // 通知（macOS がその時間に通知を出す。カレンダーアプリが開いていなくてもよい）
      const offset = startHM ? -Number(alarmMin) * 60 : 9 * 3600;   // 秒。終日は当日 0 時からの 9 時間後
      ev.addAlarm($.EKAlarm.alarmWithRelativeOffset(offset));
    }
    const err = Ref();
    const ok = store.saveEventSpanCommitError(ev, 0, true, err);   // 0 = この予定だけ
    return ok ? "ok" : (err[0] && !err[0].isNil() ? ObjC.unwrap(err[0].localizedDescription) : "保存できませんでした");
  }
  return "使い方: calendars | add ...";
}
