import 'package:flutter/material.dart';
import '../data/addon_feature.dart';
import '../services/admin_service.dart';
import '../services/feature_unlock_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_toast.dart';

// หน้ารายการฟีเจอร์เสริม (เฉพาะ admin) — ปลดล็อกทีละตัวด้วยรหัส
// รหัสจริงเช็คฝั่งเซิร์ฟเวอร์เท่านั้น ไม่มีอยู่ในตัวแอปเลย
class AddonFeaturesScreen extends StatefulWidget {
  const AddonFeaturesScreen({super.key});

  @override
  State<AddonFeaturesScreen> createState() => _AddonFeaturesScreenState();
}

class _AddonFeaturesScreenState extends State<AddonFeaturesScreen> {
  Set<String> _unlockedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await FeatureUnlockService.unlockedFeatureIds();
    if (!mounted) return;
    setState(() {
      _unlockedIds = ids;
      _loading = false;
    });
  }

  // ปิด -> เปิด (ต้องกรอกรหัสให้ถูกก่อน) / เปิด -> ปิด (ล็อกกลับได้เอง ไม่ต้องใช้รหัส)
  Future<void> _onToggle(AddonFeature feature, bool turnOn) async {
    if (!turnOn) {
      await FeatureUnlockService.lock(feature.id);
      if (!mounted) return;
      setState(() => _unlockedIds.remove(feature.id));
      return;
    }

    final code = await _askCode(feature);
    if (code == null || code.isEmpty) return;

    bool ok;
    try {
      ok = await AdminService.verifyFeatureUnlock(feature.id, code);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;

    if (!ok) {
      AppDialog.error(context, 'รหัสไม่ถูกต้อง');
      return;
    }

    await FeatureUnlockService.markUnlocked(feature.id);
    if (!mounted) return;
    setState(() => _unlockedIds.add(feature.id));
    AppToast.show(context, 'ปลดล็อก "${feature.title}" สำเร็จ');
  }

  Future<String?> _askCode(AddonFeature feature) async {
    final codeCtrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('ปลดล็อก "${feature.title}"'),
          content: TextField(
            controller: codeCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'รหัสปลดล็อก'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก',
                  style: TextStyle(color: AppColors.textGrey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, codeCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('ปลดล็อก'),
            ),
          ],
        ),
      );
    } finally {
      codeCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: _loading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: kAddonFeatures.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _featureCard(kAddonFeatures[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'ฟีเจอร์เสริม',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ปลดล็อกทีละฟีเจอร์ด้วยรหัส',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _featureCard(AddonFeature feature) {
    final unlocked = _unlockedIds.contains(feature.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      unlocked ? Icons.lock_open : Icons.lock_outline,
                      size: 18,
                      color: unlocked
                          ? const Color(0xFF5CB888)
                          : AppColors.textGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        feature.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  feature.description,
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked ? 'ปลดล็อกแล้ว' : 'ยังไม่ปลดล็อก',
                  style: TextStyle(
                    color:
                        unlocked ? const Color(0xFF5CB888) : AppColors.textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: unlocked,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => _onToggle(feature, v),
          ),
        ],
      ),
    );
  }
}
