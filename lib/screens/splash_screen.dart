import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';
import '../widgets/update_dialog.dart';
import 'citizen_home_screen.dart';
import 'welcome_screen.dart';

// หน้าแรกสุดตอนเปิดแอป
// เช็คว่าเคยล็อกอินไว้ไหม -> ถ้าใช่เข้าหน้า Home เลย (ไม่ต้องล็อกอินซ้ำ)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    // เช็คเวอร์ชันใหม่ก่อน (เฉพาะ Android/iOS ไม่เกี่ยวกับเว็บ)
    // ถ้าเช็คไม่ได้/ไม่มีอัปเดตใหม่ ก็ผ่านไปเข้าแอปตามปกติ ไม่บล็อกผู้ใช้
    if (!kIsWeb) {
      final update = await UpdateService.checkForUpdate();
      if (update != null && mounted) {
        await showUpdateDialog(context, update);
      }
    }

    if (!mounted) return;

    // ลองล็อกอินอัตโนมัติด้วย token ที่เคยเก็บไว้
    final result = await AuthService.tryAutoLogin();

    if (!mounted) return;

    if (result != null) {
      // เข้าได้เลย
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CitizenHomeScreen(
            roles: rolesFromStrings(result.roles),
            profile: result.profile,
          ),
        ),
      );
    } else {
      // ยังไม่เคยล็อกอิน หรือ token หมดอายุ
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon.png',
              width: 110,
              height: 110,
              fit: BoxFit.contain,
            ),
              const SizedBox(height: 20),
            const Text(
              'ระบบประปาหมู่บ้าน',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}