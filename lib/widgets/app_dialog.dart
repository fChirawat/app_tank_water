import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ===== ป๊อปอัปกลางจอแบบมีปุ่ม =====
// - AppDialog.warn  : เตือนให้กรอก/แก้ไข (ปุ่ม "ตกลง")
// - AppDialog.error : แจ้งข้อผิดพลาด (ปุ่ม "ลองใหม่อีกครั้ง")
class AppDialog {
  // ===== เตือน (สีส้ม, ปุ่มตกลง) =====
  static Future<void> warn(BuildContext context, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => _DialogBox(
        icon: Icons.info_outline,
        color: const Color(0xFFE8923A),
        message: message,
        actions: [
          _btn(ctx, 'ตกลง', filled: true, color: const Color(0xFFE8923A)),
        ],
      ),
    );
  }

  // ===== error (สีแดง, ปุ่มลองใหม่) =====
  // คืน true ถ้ากด "ลองใหม่อีกครั้ง", false/null ถ้าปิด
  static Future<bool?> error(
    BuildContext context,
    String message, {
    String retryLabel = 'ลองใหม่อีกครั้ง',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _DialogBox(
        icon: Icons.error_outline,
        color: const Color(0xFFD9534F),
        message: message,
        actions: [
          // ปิดเฉยๆ
          _btn(ctx, 'ปิด', filled: false, color: AppColors.textGrey,
              value: false),
          // ลองใหม่
          _btn(ctx, retryLabel,
              filled: true, color: const Color(0xFFD9534F), value: true),
        ],
      ),
    );
  }

  // ปุ่มในกล่อง
  static Widget _btn(
    BuildContext ctx,
    String label, {
    required bool filled,
    required Color color,
    Object? value,
  }) {
    if (filled) {
      return ElevatedButton(
        onPressed: () => Navigator.pop(ctx, value),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    return TextButton(
      onPressed: () => Navigator.pop(ctx, value),
      child: Text(label, style: TextStyle(color: color)),
    );
  }
}

class _DialogBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final List<Widget> actions;

  const _DialogBox({
    required this.icon,
    required this.color,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: actions.length == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceEvenly,
              children: actions
                  .map((a) => actions.length == 1
                      ? SizedBox(width: 160, child: a)
                      : Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: a,
                          ),
                        ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}