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
  static String get redirectUri => '$supabaseUrl/functions/v1/line-callback';

  // URL หน้าล็อกอินของ LINE
  static String buildLineAuthUrl(String state) {
    final params = {
      'response_type': 'code',
      'client_id': lineChannelId,
      'redirect_uri': redirectUri,
      'state': state,
      'scope': 'profile openid',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://access.line.me/oauth2/v2.1/authorize?$query';
  }
}