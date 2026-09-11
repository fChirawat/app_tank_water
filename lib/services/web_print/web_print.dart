// เปิดหน้า HTML (รายงาน PDF) ในแท็บใหม่บนเว็บ ให้ผู้ใช้กด Print ของเบราว์เซอร์
// (Ctrl+P) -> Save as PDF เอง เพราะเว็บไม่มี flutter_native_html_to_pdf ให้แปลง
// เป็นไฟล์ PDF ตรงๆ แบบมือถือ
//
// ไฟล์นี้แค่เลือก implementation ตาม platform (มือถือ import ไฟล์นี้ไม่ได้ก็ไม่
// เป็นไร เพราะไม่มีที่ไหนเรียกใช้นอกจากตอน kIsWeb)
export 'web_print_stub.dart'
    if (dart.library.html) 'web_print_web.dart';
