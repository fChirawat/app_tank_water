import 'package:shared_preferences/shared_preferences.dart';

// ===== ฟีเจอร์เสริม: กำหนดชื่อ/ตำแหน่งผู้ลงนามในใบคำร้อง PDF เอง =====
// ปกติ (ยังไม่ปลดล็อก) -> PDF ใช้ชื่อ/ตำแหน่งเดิมที่ตั้งไว้ตายตัว
// ปลดล็อกแล้ว -> ทุกครั้งที่จะสร้าง PDF จะถามว่าจะใช้ชื่อ/ตำแหน่งล่าสุดหรือกรอกใหม่
//
// สถานะ "ปลดล็อกแล้วหรือยัง" ย้ายไปอยู่ที่ FeatureUnlockService แล้ว
// (id = 'pdf_signer') ไฟล์นี้เก็บเฉพาะข้อมูลของฟีเจอร์นี้เอง (ชื่อ/ตำแหน่งล่าสุด)
class PdfSignerPrefs {
  static const _kName = 'pdf_signer_name';
  static const _kPosition = 'pdf_signer_position';

  static Future<String?> lastName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kName);
  }

  static Future<String?> lastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPosition);
  }

  static Future<void> saveSigner(String name, String position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kPosition, position);
  }
}
