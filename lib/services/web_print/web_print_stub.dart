// ใช้ตอนคอมไพล์ลงมือถือ (ไม่มี dart:html) — ไม่ควรถูกเรียกจริง เพราะฝั่งหน้าจอ
// จะเช็ก kIsWeb ก่อนเรียกเสมอ
Future<void> openHtmlForPrint(String htmlContent) async {
  throw UnsupportedError('openHtmlForPrint ใช้ได้เฉพาะบนเว็บ');
}
