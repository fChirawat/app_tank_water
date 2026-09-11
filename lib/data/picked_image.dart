import 'dart:typed_data';

// รูปที่เพิ่งเลือกจากเครื่อง ยังไม่ได้อัปโหลด
// เก็บเป็น bytes (ไม่ใช่ dart:io File) เพื่อให้ใช้ได้ทั้งมือถือและเว็บ
// (เว็บไม่มี path ไฟล์จริงให้เปิดอ่านแบบ dart:io)
class PickedImage {
  final Uint8List bytes;
  final String name;

  const PickedImage({required this.bytes, required this.name});
}
