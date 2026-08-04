import 'package:flutter/material.dart';
import '../data/announcement.dart';
import '../services/announcement_service.dart';
import '../services/session.dart';
import '../theme/app_colors.dart';
import '../widgets/app_dialog.dart';

// หน้ารายการประกาศทั้งหมด (ประชาชนดู / เจ้าหน้าที่ลบได้)
class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() =>
      _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  List<Announcement> _list = [];
  bool _loading = true;
  String? _error;

  bool get _isOfficer => AppSession.roles.contains('officer');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AnnouncementService.list();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบประกาศ'),
        content: Text('ต้องการลบประกาศ "${a.title}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD9534F),
              foregroundColor: Colors.white,
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await AnnouncementService.delete(a.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'ลบไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
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
            child: Text('ประกาศทั้งหมด',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textGrey, size: 40),
            const SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_outlined,
                color: AppColors.textGrey, size: 46),
            SizedBox(height: 12),
            Text('ไม่มีประกาศ',
                style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        itemCount: _list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(_list[i]),
      ),
    );
  }

  Widget _card(Announcement a) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(a.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  a.villageLabel,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_dateText(a),
              style:
                  const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          if (a.detail != null && a.detail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a.detail!,
                style: const TextStyle(
                    color: AppColors.textDark, fontSize: 14)),
          ],
          if (a.createdByName != null) ...[
            const SizedBox(height: 8),
            Text('โดย ${a.createdByName}',
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 12)),
          ],
          // ปุ่มลบ (เฉพาะเจ้าหน้าที่)
          if (_isOfficer) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _delete(a),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.delete_outline,
                        color: Color(0xFFD9534F), size: 18),
                    SizedBox(width: 4),
                    Text('ลบ',
                        style: TextStyle(
                            color: Color(0xFFD9534F),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _dateText(Announcement a) {
    const months = [
      '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final d = a.eventDate;
    final date = '${d.day} ${months[d.month]} ${d.year + 543}';
    if (a.startTime != null && a.endTime != null) {
      return '$date เวลา ${a.startTime} - ${a.endTime} น.';
    } else if (a.startTime != null) {
      return '$date เวลา ${a.startTime} น.';
    }
    return date;
  }
}