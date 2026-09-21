import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ===== ข้อมูลเวอร์ชันล่าสุดที่เก็บไว้ใน Supabase (ตาราง app_version) =====
class AppUpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String? changelog;
  final bool forceUpdate;

  AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.changelog,
    required this.forceUpdate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionCode: json['version_code'] as int,
      versionName: json['version_name'] as String,
      apkUrl: json['apk_url'] as String,
      changelog: json['changelog'] as String?,
      forceUpdate: json['force_update'] as bool? ?? false,
    );
  }
}

// ===== เช็ค/ดาวน์โหลด/ติดตั้งอัปเดตแอป (เฉพาะ Android, นอกระบบ Play Store) =====
class UpdateService {
  static final _supabase = Supabase.instance.client;

  // เทียบเลขเวอร์ชันในเครื่องกับเลขล่าสุดที่ตั้งไว้ใน Supabase
  // คืน null = ไม่มีอัปเดตใหม่ หรือเช็คไม่ได้ (ไม่ให้แอปเปิดไม่ได้เพราะเช็คพัง)
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final data = await _supabase
          .from('app_version')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (data == null) return null;

      final info = AppUpdateInfo.fromJson(data);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (info.versionCode <= currentCode) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  // ดาวน์โหลด APK มาเก็บในเครื่อง แล้วเปิดหน้าจอติดตั้งของ Android ให้ผู้ใช้กดยืนยันเอง
  // (Android บังคับให้ผู้ใช้กดยืนยันติดตั้งเสมอ ข้ามขั้นตอนนี้ไม่ได้)
  static Future<void> downloadAndInstall(
    String url, {
    required void Function(double progress) onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('ดาวน์โหลดไม่สำเร็จ (รหัส ${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final bytes = <int>[];

    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (total > 0) onProgress(received / total);
    }

    final dir = await getExternalStorageDirectory() ??
        await getTemporaryDirectory();
    final file = File('${dir.path}/water_app_update.apk');
    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
  }
}
