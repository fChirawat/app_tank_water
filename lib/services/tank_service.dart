import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/water_tank.dart';
import 'session.dart';

// จัดการข้อมูลแทงค์น้ำกับ PostgreSQL
//
// อ่าน: ดึงตรงจากฐานข้อมูล (ข้อมูลแทงค์ไม่ใช่ความลับ ชาวบ้านดูได้)
// เขียน: ผ่าน Edge Function ที่ตรวจ role เจ้าหน้าที่ก่อน
class TankService {
  static final _supabase = Supabase.instance.client;

  // ===== ดึงรายการแทงค์ทั้งหมด =====
  static Future<List<WaterTank>> fetchTanks() async {
    final data = await _supabase
        .from('water_tanks')
        .select()
        .order('created_at', ascending: false);

    return (data as List)
        .map((row) => WaterTank.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ===== อัปโหลดรูป 1 รูป แล้วคืน URL สำหรับแสดงผล =====
  // ขั้นตอน: ขอ "ตั๋วอัปโหลด" จาก Edge Function (เช็ค role ก่อน)
  //         -> อัปไฟล์เข้า Storage โดยตรง -> ได้ URL กลับมา
  static Future<String> uploadImage(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;

    // 1) ขอตั๋วอัปโหลด
    final response = await _supabase.functions.invoke(
      'water-tanks',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'upload-url',
        'fileName': fileName,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    final path = data['path'] as String;
    final token = data['token'] as String;
    final publicUrl = data['publicUrl'] as String;

    // 2) อัปไฟล์เข้า Storage ด้วยตั๋วที่ได้มา
    await _supabase.storage
        .from('tank-images')
        .uploadToSignedUrl(path, token, file);

    return publicUrl;
  }

  // ===== อัปโหลดหลายรูปพร้อมกัน =====
  static Future<List<String>> uploadImages(List<File> files) async {
    final urls = <String>[];
    for (final f in files) {
      urls.add(await uploadImage(f));
    }
    return urls;
  }

  // ===== เพิ่มแทงค์ใหม่ =====
  static Future<WaterTank> createTank({
    required String name,
    required String type,
    required String village,
    required int moo,
    String? detail,
    List<String> imageUrls = const [],
    double? lat,
    double? lng,
    double? capacity,
    int? builtYear,
    String? caretaker,
    String? caretakerPhone,
  }) async {
    final response = await _supabase.functions.invoke(
      'water-tanks',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'create',
        'tank': {
          'name': name,
          'type': type,
          'village': village,
          'moo': moo,
          'detail': detail,
          'imageUrls': imageUrls,
          'lat': lat,
          'lng': lng,
          'capacity': capacity,
          'builtYear': builtYear,
          'caretaker': caretaker,
          'caretakerPhone': caretakerPhone,
        },
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return WaterTank.fromJson(data['tank'] as Map<String, dynamic>);
  }

  // ===== แก้ไขแทงค์ =====
  static Future<WaterTank> updateTank({
    required String tankId,
    required String name,
    required String type,
    required String village,
    required int moo,
    String? detail,
    List<String> imageUrls = const [],
    double? lat,
    double? lng,
    double? capacity,
    int? builtYear,
    String? caretaker,
    String? caretakerPhone,
  }) async {
    final response = await _supabase.functions.invoke(
      'water-tanks',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'update',
        'tankId': tankId,
        'tank': {
          'name': name,
          'type': type,
          'village': village,
          'moo': moo,
          'detail': detail,
          'imageUrls': imageUrls,
          'lat': lat,
          'lng': lng,
          'capacity': capacity,
          'builtYear': builtYear,
          'caretaker': caretaker,
          'caretakerPhone': caretakerPhone,
        },
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }

    return WaterTank.fromJson(data['tank'] as Map<String, dynamic>);
  }

  // ===== ลบแทงค์ =====
  static Future<void> deleteTank(String tankId) async {
    final response = await _supabase.functions.invoke(
      'water-tanks',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'delete',
        'tankId': tankId,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}