// ax-agent: sketchybar の代わりに、アクセシビリティが必要な操作だけを行う常駐プログラム。
// アクセシビリティの許可はこのプログラムだけに与え、sketchybar には与えない
// （sketchybar は外からのコマンドで任意のスクリプトを実行できるので、強い権限を持たせない）。
//
// 受け付ける操作は下の固定の一覧だけ。<ソケットのディレクトリ>/sock（自分だけが使える）に
// 1 行で頼み、結果を受け取る（シェルからは `printf '%s\n' "menus" | nc -U <sock>`）。
//
//   menus                 前面アプリの pid（1 行目）と、メニューバーの項目（2 行目から
//                         「<番号> US <名前>」、US = \x1f。Apple メニュー（0 番）は除く）
//   menu-open <pid> <番号> 前面アプリのメニューを開く（pid が今の前面アプリと一致するときだけ）
//   extra-click <名前>    標準メニューバーの項目をクリック（clock = 通知センター / audiovideo = ビデオエフェクト）
//   camera                カメラが使用中なら 1、そうでなければ 0（コントロールセンターの表示から判定）
//   key <名前>            決まったキー操作を送る（ime-next = ⌃Space / emoji = ⌃⌘Space / menu-search = ⌘⇧/）
//   extras                コントロールセンターの項目の識別子の一覧（sketchybar-doctor の点検用）
//   trusted               アクセシビリティの許可があれば 1
//
// 許可がないときは "ERROR noaccess" を返す（理由は /tmp/ax-agent.log にも出す）。
//
// 使い方: ax-agent <ソケットのディレクトリ>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

static NSString *const US = @"\x1f";

// ── アクセシビリティの小道具 ─────────────────────────────────────────── //

static id copyAttr(AXUIElementRef el, CFStringRef name) {
  CFTypeRef v = NULL;
  if (AXUIElementCopyAttributeValue(el, name, &v) != kAXErrorSuccess) return nil;
  return CFBridgingRelease(v);
}

static NSString *stringAttr(AXUIElementRef el, CFStringRef name) {
  id v = copyAttr(el, name);
  return [v isKindOfClass:NSString.class] ? v : nil;
}

static AXUIElementRef appElement(pid_t pid) {
  AXUIElementRef app = AXUIElementCreateApplication(pid);
  AXUIElementSetMessagingTimeout(app, 1.0); // 応答しないアプリで止まらないように
  return app;
}

// 前面アプリの pid（取れなければ 0）。NSWorkspace の値はメインの run loop で更新される
static pid_t frontPid(void) {
  __block pid_t pid = 0;
  dispatch_sync(dispatch_get_main_queue(), ^{
    pid = NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
  });
  return pid;
}

// アプリのメニューバーの項目（0 番は Apple メニュー）
static NSArray *menuBarItems(pid_t pid) {
  AXUIElementRef app = appElement(pid);
  id bar = copyAttr(app, kAXMenuBarAttribute);
  CFRelease(app);
  if (!bar) return @[];
  id kids = copyAttr((__bridge AXUIElementRef)bar, kAXChildrenAttribute);
  return [kids isKindOfClass:NSArray.class] ? kids : @[];
}

// コントロールセンターが標準メニューバーに置いている項目（時計・コントロールセンター・カメラ等）
static NSArray *controlCenterExtras(void) {
  NSRunningApplication *cc =
      [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.controlcenter"].firstObject;
  if (!cc) return @[];
  AXUIElementRef app = appElement(cc.processIdentifier);
  id bar = copyAttr(app, CFSTR("AXExtrasMenuBar"));
  if (!bar) bar = copyAttr(app, kAXMenuBarAttribute);
  CFRelease(app);
  if (!bar) return @[];
  id kids = copyAttr((__bridge AXUIElementRef)bar, kAXChildrenAttribute);
  return [kids isKindOfClass:NSArray.class] ? kids : @[];
}

static id extraWithId(NSString *ident) {
  for (id item in controlCenterExtras())
    if ([stringAttr((__bridge AXUIElementRef)item, kAXIdentifierAttribute) isEqual:ident]) return item;
  return nil;
}

// 押す。メニューは閉じるまで戻らないことがあるので、返事を待たせないよう裏で実行
static void pressLater(id item) {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    AXUIElementPerformAction((__bridge AXUIElementRef)item, kAXPressAction);
  });
}

static void sendKey(CGKeyCode code, CGEventFlags flags) {
  CGEventRef down = CGEventCreateKeyboardEvent(NULL, code, true);
  CGEventRef up = CGEventCreateKeyboardEvent(NULL, code, false);
  CGEventSetFlags(down, flags);
  CGEventSetFlags(up, flags);
  CGEventPost(kCGHIDEventTap, down);
  CGEventPost(kCGHIDEventTap, up);
  CFRelease(down);
  CFRelease(up);
}

// ── 操作（固定の一覧）────────────────────────────────────────────────── //

static NSString *handle(NSArray<NSString *> *args) {
  NSString *cmd = args.firstObject ?: @"";
  if ([cmd isEqual:@"trusted"]) return AXIsProcessTrusted() ? @"1" : @"0";
  if (!AXIsProcessTrusted()) {
    fprintf(stderr, "ax-agent: アクセシビリティの許可がありません\n");
    return @"ERROR noaccess";
  }

  if ([cmd isEqual:@"menus"]) {
    pid_t pid = frontPid();
    if (!pid) return @"ERROR nofront";
    NSMutableArray *lines = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%d", pid]];
    NSArray *items = menuBarItems(pid);
    for (NSUInteger i = 1; i < items.count; i++) {
      NSString *t = stringAttr((__bridge AXUIElementRef)items[i], kAXTitleAttribute);
      if (t.length) [lines addObject:[NSString stringWithFormat:@"%lu%@%@", (unsigned long)i, US, t]];
    }
    return [lines componentsJoinedByString:@"\n"];
  }

  if ([cmd isEqual:@"menu-open"] && args.count == 3) {
    pid_t pid = (pid_t)args[1].intValue;
    NSInteger i = args[2].integerValue;
    if (pid <= 0 || pid != frontPid()) return @"ERROR notfront"; // 前面アプリだけ
    NSArray *items = menuBarItems(pid);
    if (i < 1 || i >= (NSInteger)items.count) return @"ERROR range";
    pressLater(items[i]);
    return @"ok";
  }

  if ([cmd isEqual:@"extra-click"] && args.count == 2) {
    NSDictionary *allowed = @{
      @"clock" : @"com.apple.menuextra.clock",
      @"audiovideo" : @"com.apple.menuextra.audiovideo",
    };
    NSString *ident = allowed[args[1]];
    if (!ident) return @"ERROR unknown";
    id item = extraWithId(ident);
    if (!item) return @"ERROR notfound";
    pressLater(item);
    return @"ok";
  }

  if ([cmd isEqual:@"camera"]) {
    id cc = extraWithId(@"com.apple.menuextra.controlcenter");
    NSString *d = cc ? stringAttr((__bridge AXUIElementRef)cc, kAXDescriptionAttribute) : nil;
    BOOL used = d && ([d containsString:@"カメラ"] || [d.lowercaseString containsString:@"camera"]);
    return used ? @"1" : @"0";
  }

  if ([cmd isEqual:@"key"] && args.count == 2) {
    NSString *k = args[1];
    if ([k isEqual:@"ime-next"]) sendKey(49, kCGEventFlagMaskControl);
    else if ([k isEqual:@"emoji"]) sendKey(49, kCGEventFlagMaskControl | kCGEventFlagMaskCommand);
    else if ([k isEqual:@"menu-search"]) sendKey(44, kCGEventFlagMaskCommand | kCGEventFlagMaskShift);
    else return @"ERROR unknown";
    return @"ok";
  }

  if ([cmd isEqual:@"extras"]) {
    NSMutableArray *ids = [NSMutableArray array];
    for (id item in controlCenterExtras()) {
      NSString *s = stringAttr((__bridge AXUIElementRef)item, kAXIdentifierAttribute);
      if (s) [ids addObject:s];
    }
    return [ids componentsJoinedByString:@"\n"];
  }

  return @"ERROR unknown";
}

// ── ソケット ─────────────────────────────────────────────────────────── //

static void serve(int client) {
  struct timeval tv = {.tv_sec = 1};
  setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
  char buf[512];
  size_t len = 0;
  while (len < sizeof buf - 1) {
    ssize_t n = read(client, buf + len, sizeof buf - 1 - len);
    if (n <= 0) break;
    len += (size_t)n;
    if (memchr(buf, '\n', len)) break;
  }
  buf[len] = 0;
  NSString *line = [[NSString alloc] initWithUTF8String:buf] ?: @"";
  NSArray *args = [[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
      componentsSeparatedByString:@" "];
  NSString *reply = [handle(args) stringByAppendingString:@"\n"];
  const char *out = reply.UTF8String;
  write(client, out, strlen(out));
  close(client);
}

int main(int argc, char **argv) {
  @autoreleasepool {
    if (argc != 2) {
      fprintf(stderr, "使い方: ax-agent <ソケットのディレクトリ>\n");
      return 2;
    }
    NSString *dir = @(argv[1]);
    mkdir(dir.fileSystemRepresentation, 0700);
    chmod(dir.fileSystemRepresentation, 0700); // 自分だけが使える
    NSString *path = [dir stringByAppendingPathComponent:@"sock"];
    unlink(path.fileSystemRepresentation);

    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un addr = {.sun_family = AF_UNIX};
    strlcpy(addr.sun_path, path.fileSystemRepresentation, sizeof addr.sun_path);
    if (bind(s, (struct sockaddr *)&addr, sizeof addr) != 0 || listen(s, 8) != 0) {
      perror("ax-agent: ソケットを開けません");
      return 1;
    }
    chmod(path.fileSystemRepresentation, 0600);
    if (!AXIsProcessTrusted()) fprintf(stderr, "ax-agent: アクセシビリティの許可がありません（起動時）\n");

    // 1 件ずつ順番に処理する（同時に来ても操作が混ざらないように）
    dispatch_queue_t q = dispatch_queue_create("ax-agent", DISPATCH_QUEUE_SERIAL);
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)s, 0, q);
    dispatch_source_set_event_handler(src, ^{
      int c = accept(s, NULL, NULL);
      if (c >= 0) @autoreleasepool { serve(c); }
    });
    dispatch_resume(src);
    [[NSRunLoop mainRunLoop] run];
  }
  return 0;
}
