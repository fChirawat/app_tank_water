import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/announcement.dart';
import 'session.dart';

// เรียกใช้ Edge Function announcements
class AnnouncementService {
  static final _supabase = Supabase.instance.client;

  // เรียก Edge Function 'announcements' + แกะ error ให้อ่านง่าย
  // (functions.invoke() throw FunctionException ตรงๆ เมื่อ status ไม่ใช่ 2xx
  //  ถ้าไม่แกะเอง จะโชว์ FunctionException(status: .., details: ..) ดิบๆ ให้ผู้ใช้เห็น)
  static Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await _supabase.functions.invoke('announcements', body: body);
      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);
      return data;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      throw Exception('เกิดข้อผิดพลาด (${e.status})');
    }
  }

  // เจ้าหน้าที่สร้างประกาศ
  static Future<void> create({
    required String title,
    String? detail,
    required DateTime eventDate,
    String? startTime,
    String? endTime,
    List<String> villages = const [], // ว่าง = ทุกหมู่บ้าน
    // ฟีเจอร์เสริม: ตั้งเวลาส่ง push ล่วงหน้า — ไม่ระบุ = ส่งทันที
    DateTime? pushScheduledAt,
  }) async {
    await _invoke({
      'accessToken': AppSession.accessToken,
      'action': 'create',
      'announcement': {
        'title': title,
        'detail': detail,
        'eventDate': eventDate.toIso8601String().split('T').first, // YYYY-MM-DD
        'startTime': startTime,
        'endTime': endTime,
        'villages': villages,
        'pushScheduledAt': pushScheduledAt?.toIso8601String(),
      },
    });
  }

  // ดูรายการประกาศ (ยังไม่ข้ามวัน)
  static Future<List<Announcement>> list() async {
    final data = await _invoke({
      'accessToken': AppSession.accessToken,
      'action': 'list',
    });
    return (data['announcements'] as List)
        .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  // เจ้าหน้าที่ลบประกาศ
  static Future<void> delete(String id) async {
    await _invoke({
      'accessToken': AppSession.accessToken,
      'action': 'delete',
      'id': id,
    });
  }
}
