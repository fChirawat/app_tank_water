import 'package:flutter/material.dart';
import '../data/complaint.dart';
import '../services/complaint_service.dart';
import '../theme/app_colors.dart';
import 'budget_detail_screen.dart';

// หน้าผู้ใหญ่บ้าน "อนุมัติงบประมาณ"
// แสดงเรื่องสถานะ budget_review (รับเรื่องแล้ว รออนุมัติ) เฉพาะหมู่บ้านที่ดูแล
class BudgetApproveScreen extends StatefulWidget {
  const BudgetApproveScreen({super.key});

  @override
  State<BudgetApproveScreen> createState() => _BudgetApproveScreenState();
}

class _BudgetApproveScreenState extends State<BudgetApproveScreen> {
  List<Complaint> _list = [];
  bool _loading = true;
  String? _error;

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
      final list = await ComplaintService.villageHeadList('budget_review');
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

  Future<void> _openDetail(Complaint c) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BudgetDetailScreen(complaint: c, mode: BudgetMode.approve),
      ),
    );
    if (changed == true) _load();
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
                child: _buildBody(),
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
            child: Column(
              children: [
                Text('อนุมัติงบประมาณ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('เรื่องที่รอการอนุมัติงบ',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            ),
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
            Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.textGrey, size: 46),
            SizedBox(height: 12),
            Text('ไม่มีเรื่องรออนุมัติ',
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

  Widget _card(Complaint c) {
    return GestureDetector(
      onTap: () => _openDetail(c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เหตุ : ${c.problemType}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            if (c.tankName != null) _line('ชื่อแทงค์ : ${c.tankName}'),
            if (c.tankType != null) _line('ประเภท : ${c.tankType}'),
            if (c.tankVillage != null)
              _line('หมู่ ${c.tankMoo ?? '-'} ${c.tankVillage}'),
            const SizedBox(height: 12),
            Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFB08A00).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('ดูรายละเอียด / ตัดสินงบ',
                  style: TextStyle(
                      color: Color(0xFF8A6D00),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(text,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
    );
  }
}