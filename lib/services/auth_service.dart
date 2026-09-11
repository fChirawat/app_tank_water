import 'dart:math';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'push_service.dart';
import 'session.dart';

// ===== ผลลัพธ์ของการล็อกอิน =====
class LoginResultData {
  final bool isNewUser;

  // กรณีผู้ใช้ใหม่ — เอาไปเติมในหน้ากรอกข้อมูล
  final String? lineUserId;
  final String? displayName;
  final String? pictureUrl;

  // กรณีผู้ใช้เก่า — มี profile + roles แล้ว
  final Map<String, dynamic>? profile;
  final List<String> roles;

  LoginResultData({
    required this.isNewUser,
    this.lineUserId,
    this.displayName,
    this.pictureUrl,
    this.profile,
    this.roles = const [],
  });
}

class AuthService {
  static final _supabase = Supabase.instance.client;

  // เรียก Edge Function (line-login / line-register / complaints) + แกะ error
  // ให้อ่านง่าย (functions.invoke() throw FunctionException ตรงๆ เมื่อ status
  // ไม่ใช่ 2xx ถ้าไม่แกะเอง จะโชว์ FunctionException(status: .., details: ..)
  // ดิบๆ ให้ผู้ใช้เห็น)
  static Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await _supabase.functions.invoke(functionName, body: body);
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

  // สุ่มค่า state เพื่อกันการปลอมแปลงคำขอ (CSRF)
  static String _randomState() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // แปลงผลลัพธ์จาก Edge Function -> LoginResultData + เก็บ session
  static Future<LoginResultData> _handleLoginResponse(
    Map<String, dynamic> data,
  ) async {
    final token = data['accessToken'] as String?;

    if (data['isNewUser'] == true) {
      // คนใหม่ — ยังไม่มี profile เก็บแค่ token ไว้ก่อน
      await AppSession.save(token: token ?? '');
      return LoginResultData(
        isNewUser: true,
        lineUserId: data['lineUserId'] as String?,
        displayName: data['displayName'] as String?,
        pictureUrl: data['pictureUrl'] as String?,
      );
    }

    final profile = data['profile'] as Map<String, dynamic>?;
    final roles = (data['roles'] as List?)?.cast<String>() ?? const <String>[];

    await AppSession.save(
      token: token ?? '',
      profileData: profile,
      roleList: roles,
      officerVillageArg: data['officerVillage'] as String?,
      headVillageArg: data['headVillage'] as String?,
    );

    // ผูกเครื่องนี้กับบัญชี เพื่อให้ส่งแจ้งเตือนหาได้
    await PushService.syncToken();

    return LoginResultData(
      isNewUser: false,
      profile: profile,
      roles: roles,
    );
  }

  // ===== ล็อกอินด้วย LINE (ผ่านแอป LINE) =====
  // 1) เปิดแอป LINE ให้กดยินยอม (ถ้าเครื่องไม่มีแอป SDK จะเปิดเบราว์เซอร์ให้เอง)
  // 2) ได้ accessToken กลับมาเลย ไม่ต้องผ่าน callback URL
  // 3) ส่ง token ให้ Edge Function ตรวจสอบ + เช็คฐานข้อมูล
  static Future<LoginResultData> loginWithLine() async {
    final result = await LineSDK.instance.login(
      scopes: const ['profile', 'openid'],
    );

    final data = await _invoke('line-login', {
      'accessToken': result.accessToken.value,
    });

    return _handleLoginResponse(data);
  }

  // ===== ล็อกอินแบบเว็บ =====
  // ใช้ตอนรันบน Flutter Web (kIsWeb) แทน loginWithLine() ที่พึ่ง LINE native SDK
  // ซึ่งไม่มีบนเว็บ — เปิดหน้าล็อกอิน LINE ในหน้าต่างใหม่ แล้วรอ callback ที่
  // web/auth.html (ต้องไปเพิ่ม webRedirectUri ใน LINE Developers Console ก่อน)
  static Future<LoginResultData> loginWithLineWeb() async {
    final state = _randomState();
    final redirectUri = AppConfig.webRedirectUri;

    // เปิดหน้าล็อกอิน แล้วรอ URL ที่เด้งกลับเข้าแอป
    final resultUrl = await FlutterWebAuth2.authenticate(
      url: AppConfig.buildLineAuthUrl(state, redirectUriOverride: redirectUri),
      callbackUrlScheme: AppConfig.callbackScheme,
    );

    final uri = Uri.parse(resultUrl);

    // ผู้ใช้กดยกเลิก หรือ LINE แจ้ง error
    final error = uri.queryParameters['error'];
    if (error != null) {
      throw Exception('LINE แจ้งข้อผิดพลาด: $error');
    }

    // เช็คว่า state ตรงกับที่ส่งไป (กันการปลอมแปลงคำขอ)
    if (uri.queryParameters['state'] != state) {
      throw Exception('state ไม่ตรงกัน อาจถูกปลอมแปลงคำขอ');
    }

    final code = uri.queryParameters['code'];
    if (code == null) {
      throw Exception('ไม่ได้รับ code จาก LINE');
    }

    // เรียก Edge Function: line-login
    // redirectUri ต้องตรงกับที่ใช้ตอนขอ code เป๊ะๆ (LINE เช็ค exact match)
    final data = await _invoke('line-login', {
      'code': code,
      'redirectUri': redirectUri,
    });

    return _handleLoginResponse(data);
  }

  // ===== สมัครสมาชิกใหม่ (หลังกรอกข้อมูลในฟอร์ม) =====
  // ส่ง accessToken ไปให้ server ตรวจกับ LINE เองแล้วดึง lineUserId ตัวจริงมาใช้
  // (กันปลอม lineUserId มาสมัครแทนคนอื่น)
  static Future<LoginResultData> registerNewUser({
    required String? title,
    required String firstName,
    required String lastName,
    required String? houseNo,
    required String? village,
    String? avatarUrl,
  }) async {
    final data = await _invoke('line-register', {
      'accessToken': AppSession.accessToken,
      'title': title,
      'firstName': firstName,
      'lastName': lastName,
      'houseNo': houseNo,
      'village': village,
      'avatarUrl': avatarUrl,
    });

    final profile = data['profile'] as Map<String, dynamic>?;
    final roles =
        (data['roles'] as List?)?.cast<String>() ?? const <String>['citizen'];

    // อัปเดต AppSession ให้มี profile + role หลังสมัครเสร็จ
    await AppSession.save(
      token: AppSession.accessToken ?? '',
      profileData: profile,
      roleList: roles,
    );

    await PushService.syncToken();

    return LoginResultData(
      isNewUser: false,
      profile: profile,
      roles: roles,
    );
  }

  // ===== ออกจากระบบ =====
  static Future<void> logout() async {
    // ลบรหัสเครื่องออกก่อน (ต้องทำตอนยังมี token อยู่)
    // กันแจ้งเตือนของคนเก่าเด้งใส่คนที่มาใช้เครื่องต่อ
    await PushService.removeToken();

    // ออกจาก LINE SDK ด้วย (ถ้าไม่เคยล็อกอินผ่าน SDK จะ error เฉยๆ ไม่เป็นไร)
    try {
      await LineSDK.instance.logout();
    } catch (_) {}
    await AppSession.clear();
  }

  // ===== ล็อกอินอัตโนมัติตอนเปิดแอป =====
  // อ่าน token ที่เคยเก็บไว้ แล้วถามเซิร์ฟเวอร์ว่ายังใช้ได้ไหม
  // ได้ role ล่าสุดด้วย (เผื่อ admin เปลี่ยนสิทธิ์ให้)
  //
  // คืน LoginResultData ถ้าเข้าได้ / คืน null ถ้าต้องล็อกอินใหม่
  static Future<LoginResultData?> tryAutoLogin() async {
    // ไม่มี token เก่าเก็บไว้
    final hasToken = await AppSession.restore();
    if (!hasToken) return null;

    try {
      final data = await _invoke('complaints', {
        'accessToken': AppSession.accessToken,
        'action': 'me',
      });

      final profile = data['profile'] as Map<String, dynamic>?;
      final roles =
          (data['roles'] as List?)?.cast<String>() ?? const <String>[];

      await AppSession.updateProfile(
        profileData: profile,
        roleList: roles,
        officerVillageArg: data['officerVillage'] as String?,
        headVillageArg: data['headVillage'] as String?,
      );

      // อัปเดตรหัสเครื่องทุกครั้งที่เปิดแอป (เผื่อ Firebase เปลี่ยนให้ใหม่)
      await PushService.syncToken();

      return LoginResultData(
        isNewUser: false,
        profile: profile,
        roles: roles,
      );
    } catch (_) {
      // token หมดอายุ / ถูกลบออกจากระบบ / เน็ตล่ม -> ให้ล็อกอินใหม่
      return null;
    }
  }
}
