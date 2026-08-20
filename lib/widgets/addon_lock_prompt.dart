import 'package:flutter/material.dart';
import '../screens/addon_features_screen.dart';
import '../services/feature_unlock_service.dart';
import '../theme/app_colors.dart';

// เช็คว่าฟีเจอร์เสริมตัวนี้ปลดล็อกหรือยัง
// ยังไม่ปลดล็อก -> โชว์ dialog ชวนไปหน้า "ฟีเจอร์เสริม" แล้วคืน false
// ปลดล็อกแล้ว -> คืน true (เรียกฟีเจอร์ต่อได้เลย)
Future<bool> ensureFeatureUnlocked(
  BuildContext context,
  String featureId,
  String featureTitle,
) async {
  final unlocked = await FeatureUnlockService.isUnlocked(featureId);
  if (!context.mounted) return false;
  if (unlocked) return true;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('ฟีเจอร์นี้ยังไม่ได้ปลดล็อก'),
      content: Text(
        'ต้องปลดล็อกฟีเจอร์ "$featureTitle" ก่อนถึงจะใช้งานได้',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child:
              const Text('ปิด', style: TextStyle(color: AppColors.textGrey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('ไปปลดล็อก'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddonFeaturesScreen()),
    );
  }
  return false;
}
