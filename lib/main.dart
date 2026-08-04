import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'screens/splash_screen.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ตั้งค่า Firebase (สำหรับแจ้งเตือน)
  await Firebase.initializeApp();

  // ตั้งค่าแจ้งเตือน (ขออนุญาต + ขอรหัสเครื่อง)
  await PushService.init();

  // ตั้งค่า LINE SDK (ต้องเรียกก่อนใช้ฟังก์ชันล็อกอินของ LINE)
  await LineSDK.instance.setup(AppConfig.lineChannelId);

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