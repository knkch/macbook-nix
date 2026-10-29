// 画面の上端・上の角でのクリックを少し内側に移す常駐プログラム。
// 標準メニューバーは sketchybar で覆っているが、macOS は画面の一番上の行と角のクリックを
// メニューバーに渡してしまう。クリック位置をずらして sketchybar に届くようにする。
// 動かすにはアクセシビリティの許可が必要。
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>

#define TOP_EDGE 3     // 上端からこの範囲のクリックは、この位置まで下げる
#define CORNER   12    // 上の角（丸くなっている部分）はこの範囲を内側に寄せる

static CFMachPortRef tap;

static CGEventRef callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ref) {
  // 応答が遅いなどで macOS にタップを止められたら、再開する
  if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
    CGEventTapEnable(tap, true);
    return event;
  }

  CGPoint p = CGEventGetLocation(event);
  CGRect d = CGDisplayBounds(CGMainDisplayID()); // メニューバーがあるのはメインディスプレイ
  if (p.x < d.origin.x || p.x >= d.origin.x + d.size.width) return event;

  double y = p.y - d.origin.y;
  if (y >= CORNER) return event;

  CGPoint q = p;
  if (y < TOP_EDGE) q.y = d.origin.y + TOP_EDGE;
  if (p.x - d.origin.x < CORNER) q.x = d.origin.x + CORNER;
  else if (d.origin.x + d.size.width - p.x <= CORNER) q.x = d.origin.x + d.size.width - CORNER - 1;

  if (q.x != p.x || q.y != p.y) CGEventSetLocation(event, q);
  return event;
}

int main(void) {
  CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp)
                   | CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp)
                   | CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp);
  tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault,
                         mask, callback, NULL);
  if (!tap) {
    fprintf(stderr, "menubar-click-guard: イベントタップを作れません（アクセシビリティの許可が必要）\n");
    return 1;
  }
  CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(NULL, tap, 0);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
  CGEventTapEnable(tap, true);
  CFRunLoopRun();
  return 0;
}
