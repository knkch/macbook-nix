// sketchybar のカレンダーから予定を扱う（EventKit。カレンダーアプリは開かない）
//   osascript -l JavaScript event.js calendars
//       → 予定を追加できるカレンダーの名前（1 行ずつ。最初が既定のカレンダー）
//   osascript -l JavaScript event.js add <YYYY-MM-DD> <タイトル> <開始 HH:MM | ""> <終了 HH:MM | ""> <カレンダー名> [通知]
//       → 開始が空なら終日。終了が空なら開始の 1 時間後。成功で "ok"、失敗でエラー内容
//       → 通知: 開始の何分前に知らせるか（0 = 開始時、空 = 通知なし）。終日の予定は当日の朝 9 時に知らせる
//   osascript -l JavaScript event.js list <YYYY-MM-DD>
//       → その日の予定。1 行 1 件: <ID> US <表示用の文字（時刻  タイトル）> US <1 = 編集できる / 0>（US = \x1f）
//   osascript -l JavaScript event.js get <ID>
//       → <タイトル> US <日付 YYYY-MM-DD> US <開始 HH:MM | 空 = 終日> US <終了 HH:MM> US <通知の分 | 空> US <カレンダー名>
//   osascript -l JavaScript event.js update <ID> <タイトル> <開始 HH:MM | ""> <終了 HH:MM | ""> [通知]
//       → 日付はそのままで、タイトル・時間・通知を変更。成功で "ok"
//   osascript -l JavaScript event.js delete <ID>   → 成功で "ok"
// 繰り返しの予定は、その回だけを変更・削除する
// カレンダーへのアクセス許可は、呼び出し元（sketchybar）のものを使う
ObjC.import("EventKit");

const pad = n => String(n).padStart(2, "0");
const hm = d => pad(d.getHours()) + ":" + pad(d.getMinutes());
const nsdate = d => $.NSDate.dateWithTimeIntervalSince1970(d.getTime() / 1000);

// 予定の日時と通知を設定する（開始が空なら終日。終了が空なら開始の 1 時間後）
function setTimes(ev, y, m, d, startHM, endHM, alarmMin) {
  const at = (s, plusMin) => {
    const [h, mi] = s.split(":").map(Number);
    return new Date(y, m - 1, d, h, mi + (plusMin || 0));
  };
  if (!startHM) {
    ev.allDay = true;
    ev.startDate = nsdate(new Date(y, m - 1, d));
    ev.endDate = ev.startDate;
  } else {
    ev.allDay = false;
    ev.startDate = nsdate(at(startHM));
    ev.endDate = nsdate(endHM ? at(endHM) : at(startHM, 60));
  }
  if (alarmMin !== undefined) {
    for (const a of ObjC.unwrap(ev.alarms) || []) ev.removeAlarm(a);
    if (alarmMin !== "") {
      // 通知（macOS がその時間に通知を出す。カレンダーアプリが開いていなくてもよい）
      ev.addAlarm($.EKAlarm.alarmWithRelativeOffset(startHM ? -Number(alarmMin) * 60 : 9 * 3600));
    }
  }
}

function save(store, ev) {
  const err = Ref();
  const ok = store.saveEventSpanCommitError(ev, 0, true, err);   // 0 = この回だけ
  return ok ? "ok" : (err[0] && !err[0].isNil() ? ObjC.unwrap(err[0].localizedDescription) : "保存できませんでした");
}

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

  if (argv[0] === "list") {
    const [y, m, d] = argv[1].split("-").map(Number);
    const from = new Date(y, m - 1, d), to = new Date(y, m - 1, d + 1);
    const evs = ObjC.unwrap(store.eventsMatchingPredicate(
      store.predicateForEventsWithStartDateEndDateCalendars(nsdate(from), nsdate(to), $())));
    evs.sort((a, b) => (b.allDay - a.allDay) || (ObjC.unwrap(a.startDate) - ObjC.unwrap(b.startDate)));
    return evs.map(ev => {
      const s = ObjC.unwrap(ev.startDate), e = ObjC.unwrap(ev.endDate);
      const when = ev.allDay ? "終日" : hm(s) + "-" + hm(e);
      const editable = ev.calendar.allowsContentModifications ? 1 : 0;
      return [ObjC.unwrap(ev.eventIdentifier), when + "  " + ObjC.unwrap(ev.title), editable].join("\x1f");
    }).join("\n");
  }

  if (argv[0] === "get" || argv[0] === "update" || argv[0] === "delete") {
    const ev = store.eventWithIdentifier(argv[1]);
    if (!ev || ev.isNil()) return "予定が見つかりません";
    if (argv[0] === "get") {
      const s = ObjC.unwrap(ev.startDate), e = ObjC.unwrap(ev.endDate);
      const alarms = ObjC.unwrap(ev.alarms) || [];
      const alarm = alarms.length ? (ev.allDay ? "0" : String(Math.round(-alarms[0].relativeOffset / 60))) : "";
      return [ObjC.unwrap(ev.title), s.getFullYear() + "-" + pad(s.getMonth() + 1) + "-" + pad(s.getDate()),
              ev.allDay ? "" : hm(s), ev.allDay ? "" : hm(e), alarm, ObjC.unwrap(ev.calendar.title)].join("\x1f");
    }
    if (!ev.calendar.allowsContentModifications) return "このカレンダーの予定は変更できません";
    if (argv[0] === "delete") {
      const err = Ref();
      return store.removeEventSpanCommitError(ev, 0, true, err) ? "ok" : "削除できませんでした";
    }
    const [, , title, startHM, endHM, alarmMin] = argv;
    const s = ObjC.unwrap(ev.startDate);
    ev.title = title;
    setTimes(ev, s.getFullYear(), s.getMonth() + 1, s.getDate(), startHM, endHM, alarmMin);
    return save(store, ev);
  }

  if (argv[0] === "add") {
    const [, day, title, startHM, endHM, calName, alarmMin] = argv;
    const [y, m, d] = day.split("-").map(Number);
    const ev = $.EKEvent.eventWithEventStore(store);
    ev.title = title;
    const cal = writable.find(c => ObjC.unwrap(c.title) === calName) || def;
    if (!cal || cal.isNil()) return "予定を追加できるカレンダーがありません";
    ev.calendar = cal;
    setTimes(ev, y, m, d, startHM, endHM, alarmMin === undefined ? "" : alarmMin);
    return save(store, ev);
  }
  return "使い方: calendars | list | get | add | update | delete";
}
