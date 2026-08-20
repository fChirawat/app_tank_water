import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ===== เก็บข้อมูลของคนที่ล็อกอินอยู่ =====
// ใช้ร่วมกันทั้งแอป (ไม่ต้องส่งต่อทีละหน้า)
//
// ตอนนี้เก็บลงเครื่องด้วย -> ปิดแอปเปิดใหม่ไม่ต้องล็อกอินซ้ำ
class AppSession {
  // ชื่อ key ที่ใช้เก็บลงเครื่อง
  static const _kToken = 'session_token';
  static const _kProfile = 'session_profile';
  static const _kRoles = 'session_roles';

  // LINE access token — ใช้ยืนยันตัวตนกับ Edge Function
  static String? accessToken;

  // ข้อมูลโปรไฟล์จากฐานข้อมูล
  static Map<String, dynamic>? profile;

  // role ที่มี (ชื่อดิบจากฐานข้อมูล เช่น 'citizen', 'officer')
  static List<String> roles = [];

  static bool get isLoggedIn => accessToken != null;

  static bool get isOfficer => roles.contains('officer');
  static bool get isVillageHead => roles.contains('village_head');
  static bool get isPalad => roles.contains('palad'); // เจ้าหน้าที่เทศบาล
  static bool get isAdmin => roles.contains('admin');
  // ประกาศได้ทุกหมู่บ้าน = เทศบาล หรือ แอดมิน
  static bool get canAnnounceAll => isPalad || isAdmin;

  // หมู่บ้านในโปรไฟล์ (เช่น "บุญเรืองเหนือ")
  static String? get myVillage => profile?['village'] as String?;

  // หมู่บ้านที่ดูแล (จาก role ไม่ใช่โปรไฟล์)
  static String? officerVillage;
  static String? headVillage;

  static String? get profileId => profile?['id'] as String?;

  // เก็บข้อมูลตอนล็อกอินสำเร็จ (เก็บลงเครื่องด้วย)
  static Future<void> save({
    required String token,
    Map<String, dynamic>? profileData,
    List<String>? roleList,
    String? officerVillageArg,
    String? headVillageArg,
  }) async {
    accessToken = token;
    profile = profileData;
    roles = roleList ?? [];
    officerVillage = officerVillageArg;
    headVillage = headVillageArg;

    // เขียนลงเครื่อง
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, token);
      if (profileData != null) {
        await prefs.setString(_kProfile, jsonEncode(profileData));
      }
      await prefs.setStringList(_kRoles, roles);
    } catch (_) {
      // เขียนไม่ได้ก็ไม่เป็นไร (ยังใช้งานต่อได้ในรอบนี้)
    }
  }

  // อ่านข้อมูลที่เคยเก็บไว้ (เรียกตอนเปิดแอป)
  // คืน true ถ้ามี token เก่าอยู่
  static Future<bool> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      if (token == null || token.isEmpty) return false;

      accessToken = token;

      final profileStr = prefs.getString(_kProfile);
      if (profileStr != null && profileStr.isNotEmpty) {
        profile = jsonDecode(profileStr) as Map<String, dynamic>;
      }

      roles = prefs.getStringList(_kRoles) ?? [];
      return true;
    } catch (_) {
      return false;
    }
  }

  // อัปเดตข้อมูลล่าสุด (ตอน auto login สำเร็จ ได้ role ใหม่จากเซิร์ฟเวอร์)
  static Future<void> updateProfile({
    Map<String, dynamic>? profileData,
    List<String>? roleList,
    String? officerVillageArg,
    String? headVillageArg,
  }) async {
    if (profileData != null) profile = profileData;
    if (roleList != null) roles = roleList;
    officerVillage = officerVillageArg;
    headVillage = headVillageArg;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (profileData != null) {
        await prefs.setString(_kProfile, jsonEncode(profileData));
      }
      if (roleList != null) {
        await prefs.setStringList(_kRoles, roleList);
      }
    } catch (_) {}
  }

  // ล้างตอนออกจากระบบ (ลบออกจากเครื่องด้วย)
  static Future<void> clear() async {
    accessToken = null;
    profile = null;
    roles = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kProfile);
      await prefs.remove(_kRoles);
    } catch (_) {}
  }
}