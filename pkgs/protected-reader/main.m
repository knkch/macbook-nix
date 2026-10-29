// protected-reader: macOS が保護している 2 つのファイルを読み、sketchybar が使う分だけをキャッシュに書き出す常駐プログラム。
// フルディスクアクセスはこのプログラムだけに与え、sketchybar には与えない
// （sketchybar は外からのコマンドで任意のスクリプトを実行できるので、強い権限を持たせない）。
//
//   通知の履歴: ~/Library/Group Containers/group.com.apple.usernoted/db2/db
//     → <出力先>/notifications（新しい順に最大 99 件。1 行 1 件:
//        <Bundle ID> US <届いた日時（2001-01-01 からの秒）> US <タイトル> US <本文>、US = \x1f）
//        読めないときは "ERROR" の 1 行
//   集中モードの状態: ~/Library/DoNotDisturb/DB/Assertions.json
//     → <出力先>/focus（今オンになっている集中モードの識別子。1 行 1 個）
//
// 読むファイルは固定（引数で変えられない）。0.5 秒ごとに更新時刻を見て、変わったときだけ読み直す。
// 通知が変わったら sketchybar に notify_update を送る（ベルのバッジがすぐ更新される）。
//
// 使い方: protected-reader <sketchybar のパス> <出力先のディレクトリ>
#import <Foundation/Foundation.h>
#include <spawn.h>
#include <sqlite3.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

// ファイルの更新時刻と大きさ（変わったかどうかの判定用。ないときは 0）
static NSString *stamp(NSString *path) {
  struct stat st;
  if (stat(path.fileSystemRepresentation, &st) != 0) return @"0";
  return [NSString stringWithFormat:@"%ld.%ld.%lld", (long)st.st_mtimespec.tv_sec,
                                    (long)st.st_mtimespec.tv_nsec, (long long)st.st_size];
}

// 空白・改行・区切り文字をまとめて 1 つの空白にする
static NSString *clean(id value) {
  if (![value isKindOfClass:NSString.class]) return @"";
  NSMutableCharacterSet *sep = NSMutableCharacterSet.whitespaceAndNewlineCharacterSet;
  [sep addCharactersInString:@"\x1f"];
  NSArray *words = [[value componentsSeparatedByCharactersInSet:sep]
      filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
  return [words componentsJoinedByString:@" "];
}

static void writeAtomically(NSString *text, NSString *path) {
  [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static NSString *readNotifications(NSString *db) {
  NSString *uri = [NSString stringWithFormat:@"file:%@?mode=ro", db];
  sqlite3 *con = NULL;
  // 読めない理由はログ（launchd の StandardErrorPath）に残す。
  // 「unable to open」「authorization denied」= フルディスクアクセスがない、「no such table / column」= macOS 側で形式が変わった
  if (sqlite3_open_v2(uri.UTF8String, &con, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, NULL) != SQLITE_OK) {
    fprintf(stderr, "protected-reader: 通知を読めません: %s\n", sqlite3_errmsg(con));
    sqlite3_close(con);
    return @"ERROR\n";
  }
  const char *sql = "SELECT a.identifier, r.data, r.delivered_date FROM record r"
                    " JOIN app a ON a.app_id = r.app_id ORDER BY r.delivered_date DESC LIMIT 99";
  sqlite3_stmt *st = NULL;
  if (sqlite3_prepare_v2(con, sql, -1, &st, NULL) != SQLITE_OK) {
    fprintf(stderr, "protected-reader: 通知を読めません: %s\n", sqlite3_errmsg(con));
    sqlite3_close(con);
    return @"ERROR\n";
  }
  NSMutableString *out = [NSMutableString string];
  while (sqlite3_step(st) == SQLITE_ROW) {
    const char *bid = (const char *)sqlite3_column_text(st, 0);
    NSDictionary *req = nil;
    const void *blob = sqlite3_column_blob(st, 1);
    int len = sqlite3_column_bytes(st, 1);
    if (blob && len > 0) {
      id plist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytes:blob length:len]
                                                           options:0 format:NULL error:nil];
      if ([plist isKindOfClass:NSDictionary.class] && [plist[@"req"] isKindOfClass:NSDictionary.class])
        req = plist[@"req"];
    }
    NSString *title = clean(req[@"titl"]);
    if (title.length == 0) title = clean(req[@"subt"]);
    [out appendFormat:@"%@\x1f%.3f\x1f%@\x1f%@\n", clean(bid ? @(bid) : @""),
                      sqlite3_column_double(st, 2), title, clean(req[@"body"])];
  }
  sqlite3_finalize(st);
  sqlite3_close(con);
  return out;
}

static NSString *readFocus(NSString *path) {
  NSData *data = [NSData dataWithContentsOfFile:path];
  if (!data) return @"";
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  NSMutableString *out = [NSMutableString string];
  if (![json isKindOfClass:NSDictionary.class] || ![json[@"data"] isKindOfClass:NSArray.class]) return out;
  for (id entry in json[@"data"]) {
    if (![entry isKindOfClass:NSDictionary.class]) continue;
    id records = entry[@"storeAssertionRecords"];
    if (![records isKindOfClass:NSArray.class]) continue;
    for (id r in records) {
      if (![r isKindOfClass:NSDictionary.class]) continue;
      id details = r[@"assertionDetails"];
      if (![details isKindOfClass:NSDictionary.class]) continue;
      id ident = details[@"assertionDetailsModeIdentifier"];
      if ([ident isKindOfClass:NSString.class]) [out appendFormat:@"%@\n", ident];
    }
  }
  return out;
}

static void trigger(const char *sketchybar, const char *event) {
  pid_t pid;
  char *argv[] = {(char *)sketchybar, "--trigger", (char *)event, NULL};
  if (posix_spawn(&pid, sketchybar, NULL, NULL, argv, environ) == 0) waitpid(pid, NULL, 0);
}

int main(int argc, char *argv[]) {
  if (argc != 3) {
    fprintf(stderr, "使い方: protected-reader <sketchybar のパス> <出力先のディレクトリ>\n");
    return 2;
  }
  @autoreleasepool {
    const char *envHome = getenv("HOME"); // launchd も HOME を渡す。テストで差し替えられるように優先する
    NSString *home = envHome && *envHome ? @(envHome) : NSHomeDirectory();
    NSString *dbDir = [home stringByAppendingPathComponent:@"Library/Group Containers/group.com.apple.usernoted/db2"];
    NSString *db = [dbDir stringByAppendingPathComponent:@"db"];
    NSString *assertions = [home stringByAppendingPathComponent:@"Library/DoNotDisturb/DB/Assertions.json"];
    NSString *outDir = @(argv[2]);
    umask(077); // 書き出したファイルは自分だけが読める
    [NSFileManager.defaultManager createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *notifOut = [outDir stringByAppendingPathComponent:@"notifications"];
    NSString *focusOut = [outDir stringByAppendingPathComponent:@"focus"];

    NSString *lastNotif = nil, *lastFocus = nil, *lastNotifText = nil;
    for (;;) {
      @autoreleasepool {
        // DB は WAL 方式なので、本体と -wal の両方の変化を見る
        NSString *n = [stamp(db) stringByAppendingString:stamp([db stringByAppendingString:@"-wal"])];
        if (![n isEqualToString:lastNotif]) {
          lastNotif = n;
          NSString *text = readNotifications(db);
          if (![text isEqualToString:lastNotifText]) {
            lastNotifText = text;
            writeAtomically(text, notifOut);
            trigger(argv[1], "notify_update");
          }
        }
        NSString *f = stamp(assertions);
        if (![f isEqualToString:lastFocus]) {
          lastFocus = f;
          writeAtomically(readFocus(assertions), focusOut);
        }
      }
      usleep(500000);
    }
  }
}
