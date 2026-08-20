import 'package:shared_preferences/shared_preferences.dart';

// ===== เก็บสถานะ "ปลดล็อกแล้ว" ของฟีเจอร์เสริมแต่ละตัว (ไว้ในเครื่อง) =====
// ตัวไฟล์นี้ไม่รู้จักรหัสจริงเลย รหัสเช็คฝั่งเซิร์ฟเวอร์เท่านั้น
// (ดู AdminService.verifyFeatureUnlock) — เรียก markUnlocked ได้ก็ต่อเมื่อ
// เซิร์ฟเวอร์ยืนยันรหัสถูกแล้วเท่านั้น
class FeatureUnlockService {
  static const _kUnlockedFeatures = 'unlocked_feature_ids';

  static Future<Set<String>> unlockedFeatureIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kUnlockedFeatures) ?? const []).toSet();
  }

  static Future<bool> isUnlocked(String featureId) async {
    final ids = await unlockedFeatureIds();
    return ids.contains(featureId);
  }

  static Future<void> markUnlocked(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_kUnlockedFeatures) ?? const []).toSet();
    ids.add(featureId);
    await prefs.setStringList(_kUnlockedFeatures, ids.toList());
  }

  // ล็อกกลับ — ทำได้เองในเครื่อง ไม่ต้องใช้รหัส (แค่ปิดใช้งานชั่วคราว)
  static Future<void> lock(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_kUnlockedFeatures) ?? const []).toSet();
    ids.remove(featureId);
    await prefs.setStringList(_kUnlockedFeatures, ids.toList());
  }
}
