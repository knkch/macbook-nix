// mouse-pos: マウスの位置を「x y」（画面の左上が原点、ポイント単位）で出す。
// sketchybar のメニューを閉じてよいか（マウスがメニューの外か）の判定に使う。macOS の許可は要らない
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>

int main(void) {
  CGEventRef e = CGEventCreate(NULL);
  if (!e) return 1;
  CGPoint p = CGEventGetLocation(e);
  CFRelease(e);
  printf("%d %d\n", (int)p.x, (int)p.y);
  return 0;
}
