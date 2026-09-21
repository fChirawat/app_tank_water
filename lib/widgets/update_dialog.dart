import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';

// ===== ป๊อปอัปแจ้งว่ามีแอปเวอร์ชันใหม่ + ปุ่มดาวน์โหลด/ติดตั้งในตัว =====
// ใช้ตอนเปิดแอป (ดู splash_screen.dart) — ถ้า forceUpdate = true จะปิดป๊อปอัป
// หรือกดข้ามไม่ได้ ต้องอัปเดตก่อนถึงจะใช้แอปต่อได้
Future<void> showUpdateDialog(BuildContext context, AppUpdateInfo info) {
  return showDialog(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (ctx) => PopScope(
      canPop: !info.forceUpdate,
      child: _UpdateDialogContent(info: info),
    ),
  );
}

class _UpdateDialogContent extends StatefulWidget {
  final AppUpdateInfo info;

  const _UpdateDialogContent({required this.info});

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      await UpdateService.downloadAndInstall(
        widget.info.apkUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) setState(() => _downloading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = 'อัปเดตไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_alt,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'มีอัปเดตใหม่ v${info.versionName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            if (info.changelog != null && info.changelog!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                info.changelog!,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13.5, height: 1.5),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEDEDF2),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'กำลังดาวน์โหลด ${(_progress * 100).toStringAsFixed(0)}%',
                style:
                    const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFD9534F), fontSize: 13)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (!info.forceUpdate && !_downloading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ไว้ทีหลัง',
                        style: TextStyle(color: AppColors.textGrey)),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _downloading ? null : _startUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_downloading ? 'กำลังโหลด...' : 'อัปเดตเลย'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
