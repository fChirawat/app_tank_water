import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
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
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.water_drop,
                  color: Colors.white, size: 48),
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