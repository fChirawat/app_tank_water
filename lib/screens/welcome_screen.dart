import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../services/auth_service.dart';
import 'line_register_screen.dart';
import 'citizen_home_screen.dart';

// หน้าต้อนรับ — เข้าสู่ระบบด้วย LINE (ของจริงแล้ว)
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const Color lineGreen = Color(0xFF06C755);

  bool _loading = false; // กำลังล็อกอินอยู่ไหม (กันกดซ้ำ)

  Future<void> _onLineLogin() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // เว็บไม่มี LINE native SDK — ใช้ช่องทาง OAuth ผ่านเบราว์เซอร์แทน
      final result = kIsWeb
          ? await AuthService.loginWithLineWeb()
          : await AuthService.loginWithLine();

      if (!mounted) return;

      if (result.isNewUser) {
        // คนใหม่ -> ไปหน้ากรอกข้อมูลสมาชิก พร้อมส่งข้อมูลจาก LINE ไปด้วย
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LineRegisterScreen(
              lineUserId: result.lineUserId!,
              displayName: result.displayName ?? '',
              pictureUrl: result.pictureUrl,
            ),
          ),
        );
      } else {
        // คนเก่า -> เข้าหน้า Home ตาม role ที่มี
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CitizenHomeScreen(
              roles: rolesFromStrings(result.roles),
              profile: result.profile,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'เข้าสู่ระบบไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 36),
              _buildLogo(),
              const SizedBox(height: 18),
              const Text(
                'ระบบประปาหมู่บ้าน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'เข้าสู่ระบบด้วยบัญชี LINE',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _buildWhiteCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icon.png',
      width: 110,
      height: 110,
      fit: BoxFit.contain,
    );
  }

  Widget _buildWhiteCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยินดีต้อนรับ',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'เข้าสู่ระบบเพื่อแจ้งปัญหาและติดตามสถานะระบบประปา',
            style: TextStyle(color: AppColors.textGrey, fontSize: 14),
          ),
          const SizedBox(height: 36),
          _buildLineButton(),
          const SizedBox(height: 22),
          const Center(
            child: Column(
              children: [
                Text(
                  'เมื่อเข้าสู่ระบบครั้งแรก',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'ระบบจะให้กรอกข้อมูลเพิ่มเติมเพื่อสมัครสมาชิก',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildInfoBox(),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'Version 1.0',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _loading ? null : _onLineLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: lineGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            // กำลังล็อกอิน -> โชว์วงกลมหมุน
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'L',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'เข้าสู่ระบบด้วย LINE',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ข้อมูลที่ต้องกรอกครั้งแรก',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          _bullet('คำนำหน้า ชื่อ นามสกุล'),
          _bullet('บ้านเลขที่ ตำบล หมู่บ้าน'),
          _bullet('เชื่อมบัญชี LINE กับสมาชิกอัตโนมัติ'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: AppColors.textDark)),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(color: AppColors.textDark, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}