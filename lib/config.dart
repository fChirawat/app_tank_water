// ===== ค่าตั้งต้นของแอป =====
// หา Supabase URL/anon key: Dashboard -> Project Settings -> API
// หา LINE Channel ID: LINE Developers -> Channel -> Basic settings
//
// 3 ค่านี้ปลอดภัยที่จะอยู่ในแอป
// (Channel SECRET กับ service_role key ห้ามอยู่ในแอปเด็ดขาด)
class AppConfig {
  static const String supabaseUrl = 'https://qyvgtiotpgqucnrblwen.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_ME27_NmPRnOT3Vc1o3PLwQ_rl5bg_49';
  static const String lineChannelId = '2010662821';

  // scheme ที่ตั้งไว้ใน AndroidManifest.xml
  static const String callbackScheme = 'waterapp';

  // URL ที่ LINE จะส่ง code กลับมา (ต้องตรงกับที่ตั้งใน LINE Console เป๊ะๆ)
  // ใช้บนมือถือเท่านั้น — LINE ต้อง redirect ไปที่ https ก่อน แล้วค่อยเด้งเข้า
  // แอปด้วย custom scheme (ดู supabase/functions/line-callback)
  static String get redirectUri => '$supabaseUrl/functions/v1/line-callback';

  // URL ที่ LINE จะส่ง code กลับมา — สำหรับเว็บ
  // เว็บไม่ต้องผ่านตัวเชื่อม (line-callback) เพราะเบราว์เซอร์รับ https ตรงได้อยู่แล้ว
  // ใช้ origin ปัจจุบันเสมอ (localhost ตอน dev / โดเมนจริงตอน deploy) จะได้ไม่ต้อง
  // แก้โค้ดตอนเปลี่ยนโดเมน — แค่ไปเพิ่ม URL นี้ใน LINE Developers Console ก็พอ
  // ต้องมีไฟล์ web/auth.html รับ callback (ตาม setup ของ flutter_web_auth_2)
  static String get webRedirectUri => '${Uri.base.origin}/auth.html';

  // VAPID key สำหรับขอรหัสเครื่อง (FCM token) บนเว็บ
  // หาได้ที่ Firebase Console -> Project settings -> Cloud Messaging ->
  // Web configuration -> Web Push certificates
  static const String fcmVapidKey = 'TODO-ใส่ค่าจริงจาก Firebase Console';

  // URL หน้าล็อกอินของ LINE
  static String buildLineAuthUrl(String state, {String? redirectUriOverride}) {
    final params = {
      'response_type': 'code',
      'client_id': lineChannelId,
      'redirect_uri': redirectUriOverride ?? redirectUri,
      'state': state,
      'scope': 'profile openid',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://access.line.me/oauth2/v2.1/authorize?$query';
  }
}