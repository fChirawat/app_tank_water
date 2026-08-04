import 'package:supabase_flutter/supabase_flutter.dart';
import 'session.dart';

// ===== ข้อมูลผู้ใช้ 1 คน (สำหรับหน้า admin) =====
class ManagedUser {
  final String id;
  final String? title;
  final String firstName;
  final String lastName;
  final String? village;
  final String? avatarUrl;
  final List<String> roles;
  final String? headVillage; // หมู่บ้านที่ผู้ใหญ่บ้านดูแล
  final String? officerVillage; // หมู่บ้านที่เจ้าหน้าที่ดูแล

  const ManagedUser({
    required this.id,
    this.title,
    required this.firstName,
    required this.lastName,
    this.village,
    this.avatarUrl,
    this.roles = const [],
    this.headVillage,
    this.officerVillage,
  });

  String get fullName => '${title ?? ''}$firstName $lastName'.trim();

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'] as String,
      title: json['title'] as String?,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      village: json['village'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      roles: (json['roles'] as List?)?.cast<String>() ?? const [],
      headVillage: json['headVillage'] as String?,
      officerVillage: json['officerVillage'] as String?,
    );
  }
}

// ผลลัพธ์ 1 หน้า (ผู้ใช้ในหน้านี้ + ข้อมูลแบ่งหน้า)
class UserPage {
  final List<ManagedUser> users;
  final int total; // จำนวนทั้งหมดทุกหน้า
  final int page; // หน้าปัจจุบัน (เริ่มที่ 0)
  final int pageSize; // จำนวนต่อหน้า

  const UserPage({
    required this.users,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  // จำนวนหน้าทั้งหมด
  int get totalPages => total == 0 ? 0 : ((total - 1) ~/ pageSize) + 1;
}

class AdminService {
  static final _supabase = Supabase.instance.client;

  // ===== ผลการค้นหาแบบแบ่งหน้า =====
  // ผู้ใช้ในหน้านี้ + จำนวนทั้งหมด (ไว้คำนวณว่ามีกี่หน้า)
  static Future<UserPage> listUsers({
    String? title,
    String? firstName,
    String? lastName,
    int page = 0,
  }) async {
    final response = await _supabase.functions.invoke(
      'admin-users',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'list-users',
        'title': title ?? '',
        'firstName': firstName ?? '',
        'lastName': lastName ?? '',
        'page': page,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);

    final users = (data['users'] as List)
        .map((u) => ManagedUser.fromJson(u as Map<String, dynamic>))
        .toList();

    return UserPage(
      users: users,
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 0,
      pageSize: (data['pageSize'] as num?)?.toInt() ?? 10,
    );
  }

  // ===== เพิ่ม role ให้ผู้ใช้ =====
  static Future<void> addRole(
    String profileId,
    String role, {
    String? village, // หมู่บ้าน (จำเป็นถ้าเป็นผู้ใหญ่บ้าน)
  }) async {
    final response = await _supabase.functions.invoke(
      'admin-users',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'add-role',
        'profileId': profileId,
        'role': role,
        'village': village,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }

  // ===== ลบ role ออกจากผู้ใช้ =====
  static Future<void> removeRole(String profileId, String role) async {
    final response = await _supabase.functions.invoke(
      'admin-users',
      body: {
        'accessToken': AppSession.accessToken,
        'action': 'remove-role',
        'profileId': profileId,
        'role': role,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
  }
}