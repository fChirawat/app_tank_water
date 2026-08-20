import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/announcement.dart';
import 'session.dart';

// เรียกใช้ Edge Function announcements
class AnnouncementService {
  static final _supabase = Supabase.instance.client;

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
    final response = await _supabase.functions.invoke(
      'announcements',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'create',
        'announcement': {
          'title': title,
          'detail': detail,
          'eventDate':
              eventDate.toIso8601String().split('T').first, // YYYY-MM-DD
          'startTime': startTime,
          'endTime': endTime,
          'villages': villages,
          'pushScheduledAt': pushScheduledAt?.toIso8601String(),
        },
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  // ดูรายการประกาศ (ยังไม่ข้ามวัน)
  static Future<List<Announcement>> list() async {
    final response = await _supabase.functions.invoke(
      'announcements',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'list',
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    return (data['announcements'] as List)
        .map((a) => Announcement.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  // เจ้าหน้าที่ลบประกาศ
  static Future<void> delete(String id) async {
    final response = await _supabase.functions.invoke(
      'announcements',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'delete',
        'id': id,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }
}