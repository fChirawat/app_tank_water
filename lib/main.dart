import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ตั้งค่า Firebase (สำหรับแจ้งเตือน)
  // เว็บไม่มี google-services.json ให้อ่านเอง ต้องส่ง options ตรงๆ
  // มือถือ (Android/iOS) ยังคงอ่านจากไฟล์ native เหมือนเดิม ไม่ต้องส่ง options
  try {
    await Firebase.initializeApp(
      options: kIsWeb ? DefaultFirebaseOptions.web : null,
    );

    // ตั้งค่าแจ้งเตือน (ขออนุญาต + ขอรหัสเครื่อง)
    await PushService.init();
  } catch (e) {
    // ยังไม่ได้ตั้งค่า Firebase สำหรับเว็บ (ดู lib/firebase_options.dart) —
    // ปล่อยผ่าน ไม่ให้แอปเปิดไม่ได้ แค่ยังไม่มีแจ้งเตือน push
    debugPrint('ตั้งค่า Firebase ไม่สำเร็จ: $e');
  }

  // ตั้งค่า LINE SDK (ต้องเรียกก่อนใช้ฟังก์ชันล็อกอินของ LINE)
  // เว็บไม่มี native SDK ตัวนี้ ล็อกอินฝั่งเว็บใช้ช่องทาง OAuth ผ่านเบราว์เซอร์แทน
  if (!kIsWeb) {
    await LineSDK.instance.setup(AppConfig.lineChannelId);
  }

  // ตั้งค่า Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบประปาหมู่บ้าน',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}