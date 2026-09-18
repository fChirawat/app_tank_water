import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';

import '../data/villages.dart';
import '../services/complaint_service.dart';
import '../services/dashboard_pdf_service.dart';
import '../services/feature_unlock_service.dart';
import '../services/web_print/web_print.dart';
import '../theme/app_colors.dart';
import '../widgets/addon_lock_prompt.dart';
import '../widgets/app_dialog.dart';

// Dashboard เทศบาล: วงกลมเรื่องที่ส่งมาเทศบาล + แท่งงบสมทบ
class PaladDashboardScreen extends StatefulWidget {
  const PaladDashboardScreen({super.key});

  @override
  State<PaladDashboardScreen> createState() =>
      _PaladDashboardScreenState();
}

class _PaladDashboardScreenState extends State<PaladDashboardScreen> {
  DashboardData? _data;
  bool _loading = true;
  String? _error;
  bool _printing = false;

  // ไว้แคปรูปกราฟจริงจากหน้าจอ ตอนสร้างรายงาน PDF
  // (ตอนเทียบ แผนภูมิแท่งจะใช้ key เดียวกันนี้แหละ เพราะแสดงแทนกัน ไม่ได้อยู่พร้อมกัน)
  final _donutKey = GlobalKey();
  final _compareDonutKey = GlobalKey();
  final _barKey = GlobalKey();

  // ช่วงเวลาที่เลือก
  DashboardPeriod? _selected;

  // ฟีเจอร์เสริม: พิมพ์ PDF — ซ่อนปุ่มไปเลยถ้ายังไม่ปลดล็อก
  bool _printUnlocked = false;

  // ฟีเจอร์เสริม: เปรียบเทียบกับอีกช่วงเวลาหนึ่ง (เลือกเองได้อิสระ)
  // ซ่อนสวิตช์นี้ไปเลยถ้ายังไม่ปลดล็อก (เช็คตอนโหลดหน้า/ดึงข้อมูลใหม่)
  bool _compareMode = false;
  bool _compareUnlocked = false;
  DashboardPeriod? _comparePeriod;
  DashboardData? _compareData;
  bool _loadingCompare = false;

  // 1 หมู่บ้าน = 1 หมู่ ตายตัว
  // หมายเหตุ: "บ้านบุญเรืองใต้" ใช้ชื่อซ้ำกันทั้งหมู่ 2 และหมู่ 9 (คนละหมู่จริง)
  // แผนภูมิที่กลุ่มข้อมูลตามชื่อจากฝั่งเซิร์ฟเวอร์จะยังแยกหมู่ 2/9 ไม่ได้
  // จนกว่าจะแก้ query ฝั่ง backend ให้กลุ่มตามหมู่แทนชื่อ (ยังไม่ได้แก้จุดนี้)
  static const Map<String, int> _villageMooMap = {
    'บ้านบุญเรืองเหนือ': 1,
    'บ้านบุญเรืองใต้': 2,
    'บ้านซาววา': 3,
    'บ้านหก': 4,
    'บ้านต้นปล้อง': 5,
    'บ้านแดนเมือง': 6,
    'บ้านป่าเคาะ': 7,
    'บ้านต้นปล้องใต้': 8,
    'บ้านภูแกง': 10,
  };

  // สีประจำหมู่บ้านแบบตายตัว — คีย์ด้วยเลขหมู่ (ไม่ใช่ชื่อ) กันหมู่ 2/9 สีชนกัน
  static const Map<int, Color> _villageColorsByMoo = {
    1: Color(0xFF7C5CFC),
    2: Color(0xFF4CAF50),
    3: Color(0xFFFF9800),
    4: Color(0xFF2196F3),
    5: Color(0xFFE91E63),
    6: Color(0xFF00BCD4),
    7: Color(0xFFFFC107),
    8: Color(0xFF9C27B0),
    9: Color(0xFF3F51B5),
    10: Color(0xFFFF5722),
  };

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

    final printUnlocked = await FeatureUnlockService.isUnlocked('dashboard_print');
    final compareUnlocked =
        await FeatureUnlockService.isUnlocked('dashboard_compare');
    if (!mounted) return;
    setState(() {
      _printUnlocked = printUnlocked;
      _compareUnlocked = compareUnlocked;
    });

    try {
      final now = DateTime.now();
      final mode = _selected?.type ?? 'month';
      final year = _selected?.year ?? now.year;
      final int? month = _selected?.type == 'year'
          ? null
          : (_selected?.month ?? now.month);

      final data = await ComplaintService.fetchPaladDashboard(
        mode: mode,
        year: year,
        month: month,
      );

      if (!mounted) return;

      if (_selected == null) {
        DashboardPeriod? defaultPeriod;

        for (final period in data.periods) {
          if (period.type == 'month' &&
              period.year == year &&
              period.month == month) {
            defaultPeriod = period;
            break;
          }
        }

        if (defaultPeriod != null) {
          _selected = defaultPeriod;
        } else if (data.periods.isNotEmpty) {
          _selected = data.periods.first;
        } else {
          _selected = DashboardPeriod(
            type: 'month',
            year: year,
            month: month,
            label: 'เดือนนี้',
          );
        }
      }

      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ: $e';
        _loading = false;
      });
    }
  }

  int? mooOfVillage(String? villageName) {
    if (villageName == null) return null;
    return _villageMooMap[villageName];
  }

  String villageWithMoo(String villageName) {
    final moo = _villageMooMap[villageName];
    if (moo == null) return villageName;
    return 'หมู่ $moo $villageName';
  }

  // village ที่ส่งเข้ามาเป็น label เต็ม "หมู่ X ชื่อ" อยู่แล้ว (จาก fetchPaladDashboard)
  // ต้องแกะเลขหมู่มาเทียบสี ไม่ใช้ชื่อ เพราะชื่อซ้ำกันได้ระหว่างหมู่ 2/9
  Color _villageColor(String village) {
    final moo = mooFromLabel(village) ?? mooOfVillage(village);
    if (moo == null) return AppColors.textGrey;
    return _villageColorsByMoo[moo] ?? AppColors.textGrey;
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F5FD),
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
            child: Text(
              'ภาพรวมสถิติ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!_printUnlocked)
            const SizedBox(width: 44, height: 44)
          else
            GestureDetector(
              onTap: _printing ? null : _onPrint,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: _printing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.print_outlined, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // พิมพ์รายงาน Dashboard เป็น PDF — ฟีเจอร์เสริม ต้องปลดล็อกก่อน
  Future<void> _onPrint() async {
    final ok = await ensureFeatureUnlocked(
        context, 'dashboard_print', 'พิมพ์รายงาน Dashboard');
    if (!ok || !mounted) return;

    final data = _data;
    if (data == null) return;

    setState(() => _printing = true);
    try {
      final comparing = _compareMode && _compareData != null;
      final cmp = _compareData;

      String? donutImage;
      List<DashboardReportRow> donutRows = const [];
      String? barImage;
      List<DashboardReportRow> barRows = const [];
      List<DashboardCompareBarRow> compareBreakdown = const [];
      String? compareBarImage;
      String? olderLabel;
      String? newerLabel;
      int? olderTotalReports;
      int? newerTotalReports;
      double? olderTotalBudget;
      double? newerTotalBudget;

      if (comparing) {
        final selectedIsOlder =
            _periodSortKey(_selected!) <= _periodSortKey(_comparePeriod!);
        final olderData = selectedIsOlder ? data : cmp!;
        final newerData = selectedIsOlder ? cmp! : data;
        olderLabel = selectedIsOlder ? _selected!.label : _comparePeriod!.label;
        newerLabel = selectedIsOlder ? _comparePeriod!.label : _selected!.label;
        olderTotalReports = olderData.totalReports;
        newerTotalReports = newerData.totalReports;
        olderTotalBudget = olderData.totalBudget;
        newerTotalBudget = newerData.totalBudget;

        final entries = _mergeBarEntries(olderData.bar, newerData.bar);
        compareBreakdown = entries
            .map((e) => DashboardCompareBarRow(
                  label: villageWithMoo(e.village),
                  olderValue: e.olderBudget,
                  newerValue: e.newerBudget,
                ))
            .toList();
        compareBarImage =
            entries.isEmpty ? null : await _captureChartAsDataUrl(_barKey);
      } else {
        donutImage = data.donut.isEmpty
            ? null
            : await _captureChartAsDataUrl(_donutKey);
        donutRows = data.donut
            .map((d) =>
                DashboardReportRow(label: villageWithMoo(d.village), count: d.count))
            .toList();
        barImage =
            data.bar.isEmpty ? null : await _captureChartAsDataUrl(_barKey);
        barRows = data.bar
            .map((d) => DashboardReportRow(
                  label: villageWithMoo(d.village),
                  amount: d.budget,
                ))
            .toList();
      }

      if (kIsWeb) {
        // เว็บไม่มีตัวแปลง HTML -> PDF ให้เปิดรายงานเป็นหน้าเว็บในแท็บใหม่แทน
        // ผู้ใช้กด Print ของเบราว์เซอร์ (Ctrl+P) -> Save as PDF เอง
        final html = DashboardPdfService.buildHtml(
          title: 'ภาพรวมสถิติเทศบาล',
          periodLabel: _selected?.label ?? '',
          totalReports: data.totalReports,
          totalBudget: data.totalBudget,
          donutTitle: 'เรื่องที่ส่งมาเทศบาล แยกตามหมู่บ้าน',
          donutRows: donutRows,
          donutImageDataUrl: donutImage,
          barTitle: 'งบที่เทศบาลสมทบ แยกตามหมู่บ้าน',
          barRows: barRows,
          barImageDataUrl: barImage,
          showSinglePeriodSections: !comparing,
          olderLabel: olderLabel,
          olderTotalReports: olderTotalReports,
          olderTotalBudget: olderTotalBudget,
          newerLabel: newerLabel,
          newerTotalReports: newerTotalReports,
          newerTotalBudget: newerTotalBudget,
          compareBarBreakdown: comparing ? compareBreakdown : null,
          compareBarImageDataUrl: compareBarImage,
        );
        if (!mounted) return;
        setState(() => _printing = false);
        await openHtmlForPrint(html);
        return;
      }

      final bytes = await DashboardPdfService.build(
        title: 'ภาพรวมสถิติเทศบาล',
        periodLabel: _selected?.label ?? '',
        totalReports: data.totalReports,
        totalBudget: data.totalBudget,
        donutTitle: 'เรื่องที่ส่งมาเทศบาล แยกตามหมู่บ้าน',
        donutRows: donutRows,
        donutImageDataUrl: donutImage,
        barTitle: 'งบที่เทศบาลสมทบ แยกตามหมู่บ้าน',
        barRows: barRows,
        barImageDataUrl: barImage,
        showSinglePeriodSections: !comparing,
        olderLabel: olderLabel,
        olderTotalReports: olderTotalReports,
        olderTotalBudget: olderTotalBudget,
        newerLabel: newerLabel,
        newerTotalReports: newerTotalReports,
        newerTotalBudget: newerTotalBudget,
        compareBarBreakdown: comparing ? compareBreakdown : null,
        compareBarImageDataUrl: compareBarImage,
      );
      if (!mounted) return;
      setState(() => _printing = false);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _printing = false);
      AppDialog.error(context, 'สร้าง PDF ไม่สำเร็จ');
    }
  }

  // แคปกราฟที่ผูกกับ key นี้เป็นรูป PNG แล้วแปลงเป็น data URL ไว้ฝังใน PDF
  Future<String?> _captureChartAsDataUrl(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      return 'data:image/png;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null; // แคปไม่ได้ก็ยังพิมพ์ต่อได้ แค่ไม่มีรูปกราฟ
    }
  }

  // ===== ฟีเจอร์เสริม: เปรียบเทียบกับอีกช่วงเวลาหนึ่ง (เลือกเองได้อิสระ) =====
  Widget _buildCompareToggle() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'เปรียบเทียบกับอีกช่วงเวลาหนึ่ง',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        Switch(
          value: _compareMode,
          activeThumbColor: AppColors.primary,
          onChanged: _onCompareToggle,
        ),
      ],
    );
  }

  Future<void> _onCompareToggle(bool value) async {
    if (!value) {
      setState(() {
        _compareMode = false;
        _comparePeriod = null;
        _compareData = null;
      });
      return;
    }
    final ok = await ensureFeatureUnlocked(
        context, 'dashboard_compare', 'เปรียบเทียบสถิติย้อนหลัง');
    if (!ok || !mounted) return;
    setState(() => _compareMode = true);
  }

  Future<void> _loadCompare(DashboardPeriod period) async {
    setState(() {
      _comparePeriod = period;
      _loadingCompare = true;
    });
    try {
      final data = await ComplaintService.fetchPaladDashboard(
        mode: period.type,
        year: period.year,
        month: period.month,
      );
      if (!mounted) return;
      setState(() {
        _compareData = data;
        _loadingCompare = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCompare = false);
      AppDialog.error(context, 'โหลดข้อมูลเปรียบเทียบไม่สำเร็จ');
    }
  }

  // การ์ดข้อมูลของช่วงที่เอามาเทียบ (โชว์ตัวเลขของมันเองไปเลย)
  Widget _buildCompareStatCards() {
    final cmp = _compareData;
    final period = _comparePeriod;
    if (cmp == null || period == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ข้อมูลของ ${period.label}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _statCard(
                label: 'เรื่องที่ส่งมา',
                value: '${cmp.totalReports}',
                unit: 'เรื่อง',
                icon: Icons.assignment_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                label: 'งบสมทบรวม',
                value: _money(cmp.totalBudget),
                unit: 'บาท',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
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
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return const Center(
        child: Text(
          'ไม่พบข้อมูล Dashboard',
          style: TextStyle(color: AppColors.textGrey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          if (_compareUnlocked) ...[
            _buildCompareToggle(),
            if (_compareMode) ...[
              const SizedBox(height: 8),
              _loadingCompare
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: AppColors.primary),
                        ),
                      ),
                    )
                  : _buildCompareDropdown(_periodsExcludingSelected(data.periods)),
            ],
            const SizedBox(height: 10),
          ],
          _buildPeriodDropdown(data.periods),
          const SizedBox(height: 12),
          if (_selected != null) ...[
            Text(
              'ข้อมูลของ ${_selected!.label}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _buildStatCards(data),
          if (_compareMode && _compareData != null) ...[
            const SizedBox(height: 16),
            _buildCompareStatCards(),
          ],
          const SizedBox(height: 16),
          if (_compareMode && _compareData != null)
            _buildCompareDonutCard(data)
          else
            _buildDonutCard(data),
          const SizedBox(height: 16),
          if (_compareMode && _compareData != null)
            _buildCombinedChartsCard(data)
          else
            _buildBarCard(data),
        ],
      ),
    );
  }

  // ตัดช่วงเวลาที่เลือกไว้เป็นหลักออกจากตัวเลือกฝั่งเปรียบเทียบ (กันเลือกซ้ำกันจนช่องหลักว่าง)
  List<DashboardPeriod> _periodsExcludingSelected(List<DashboardPeriod> periods) {
    final selected = _selected;
    if (selected == null) return periods;
    return periods
        .where((p) =>
            p.type != selected.type ||
            p.year != selected.year ||
            p.month != selected.month)
        .toList();
  }

  // เรียงลำดับเวลาไว้เทียบว่าอันไหนเก่ากว่า (ปีที่ * 100 + เดือน, ปีอย่างเดียวถือเป็นต้นปี)
  int _periodSortKey(DashboardPeriod p) => p.year * 100 + (p.month ?? 0);

  // รวมงบของ 2 ช่วงเวลาต่อหมู่บ้าน 1 อัน (เอาไว้วาดกราฟแท่งคู่)
  List<({String village, double olderBudget, double newerBudget})> _mergeBarEntries(
    List<VillageBudget> older,
    List<VillageBudget> newer,
  ) {
    final map = <String, ({String village, double olderBudget, double newerBudget})>{};
    for (final v in older) {
      map[v.village] = (village: v.village, olderBudget: v.budget, newerBudget: 0);
    }
    for (final v in newer) {
      final existing = map[v.village];
      map[v.village] = (
        village: v.village,
        olderBudget: existing?.olderBudget ?? 0,
        newerBudget: v.budget,
      );
    }
    final list = map.values.toList();
    list.sort(
        (a, b) => (b.olderBudget + b.newerBudget).compareTo(a.olderBudget + a.newerBudget));
    return list;
  }

  // 2 การ์ดโดนัท เทียบเรื่องที่ส่งมาของ 2 ช่วงเวลาแยกกันคนละใบ (เก่า/ใหม่)
  Widget _buildCompareDonutCard(DashboardData data) {
    final cmp = _compareData!;
    final selectedIsOlder =
        _periodSortKey(_selected!) <= _periodSortKey(_comparePeriod!);

    final olderData = selectedIsOlder ? data : cmp;
    final olderLabel = selectedIsOlder ? _selected!.label : _comparePeriod!.label;
    final newerData = selectedIsOlder ? cmp : data;
    final newerLabel = selectedIsOlder ? _comparePeriod!.label : _selected!.label;

    return Column(
      children: [
        _buildDonutCard(
          newerData,
          repaintKey: _donutKey,
          subtitle: 'ข้อมูลของ $newerLabel',
        ),
        const SizedBox(height: 16),
        _buildDonutCard(
          olderData,
          repaintKey: _compareDonutKey,
          subtitle: 'ข้อมูลของ $olderLabel',
        ),
      ],
    );
  }

  // การ์ดกราฟแท่งคู่ เทียบงบ 2 ช่วงเวลาต่อหมู่บ้านในกราฟเดียว (เก่า/ใหม่)
  Widget _buildCombinedChartsCard(DashboardData data) {
    final cmp = _compareData!;
    final selectedIsOlder =
        _periodSortKey(_selected!) <= _periodSortKey(_comparePeriod!);

    final olderData = selectedIsOlder ? data : cmp;
    final olderLabel = selectedIsOlder ? _selected!.label : _comparePeriod!.label;
    final newerData = selectedIsOlder ? cmp : data;
    final newerLabel = selectedIsOlder ? _comparePeriod!.label : _selected!.label;

    final entries = _mergeBarEntries(olderData.bar, newerData.bar);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'งบที่เทศบาลสมทบ แยกตามหมู่บ้าน',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'เทียบ 2 ช่วงเวลาต่อหมู่บ้าน (แท่งซ้าย = เก่า, แท่งขวา = ใหม่)',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legendDot(_compareOlderColor),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(olderLabel,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textDark))),
              const SizedBox(width: 16),
              _legendDot(_compareNewerColor),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(newerLabel,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textDark))),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _emptyChart(icon: Icons.bar_chart, message: 'ไม่มีข้อมูลในทั้ง 2 ช่วงเวลา')
          else
            RepaintBoundary(
              key: _barKey,
              child: Container(
                color: Colors.white,
                child: SizedBox(
                  height: 280,
                  child: BarChart(
                    _compareBarData(entries, olderLabel, newerLabel),
                    // ปิด animation กันแคปรูปไปพิมพ์ PDF ตอนแท่งยังโตไม่เต็ม
                    duration: Duration.zero,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _compareOlderColor = Color(0xFFE8923A);
  static const _compareNewerColor = Color(0xFF7C5CFC);

  Widget _legendDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }

  BarChartData _compareBarData(
    List<({String village, double olderBudget, double newerBudget})> entries,
    String olderLabel,
    String newerLabel,
  ) {
    final highest = entries.fold<double>(
        0, (a, e) => [a, e.olderBudget, e.newerBudget].reduce((x, y) => x > y ? x : y));
    final rawMax = highest <= 0 ? 100.0 : highest * 1.2;
    final niceRange = _niceNumber(rawMax, false);
    final interval = _niceNumber(niceRange / 4, true);
    final maxY = (niceRange / interval).ceilToDouble() * interval;
    final barWidth = entries.length > 5 ? 9.0 : 15.0;

    return BarChartData(
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final entry = entries[group.x];
            final label = rodIndex == 0 ? olderLabel : newerLabel;
            return BarTooltipItem(
              '${villageWithMoo(entry.village)}\n$label: ${_money(rod.toY)} บาท',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value < 0 || value > maxY) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(_compactMoney(value),
                    style: const TextStyle(fontSize: 9.5, color: AppColors.textGrey)),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= entries.length) return const SizedBox();
              final village = entries[index].village;
              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  villageWithMoo(village),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textGrey),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: AppColors.border.withValues(alpha: 0.7), strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(entries.length, (i) {
        final e = entries[i];
        return BarChartGroupData(
          x: i,
          barsSpace: 3,
          barRods: [
            BarChartRodData(
              toY: e.olderBudget,
              color: _compareOlderColor,
              width: barWidth,
              borderRadius:
                  const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: e.newerBudget,
              color: _compareNewerColor,
              width: barWidth,
              borderRadius:
                  const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPeriodDropdown(List<DashboardPeriod> periods) {
    if (periods.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'ยังไม่มีช่วงเวลาให้เลือก',
          style: TextStyle(color: AppColors.textGrey, fontSize: 14),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DashboardPeriod>(
          value: _dropdownValue(periods),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.primary,
          ),
          items: periods.map((period) {
            return DropdownMenuItem<DashboardPeriod>(
              value: period,
              child: Text(
                period.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            );
          }).toList(),
          onChanged: (period) {
            if (period == null) return;
            final cmp = _comparePeriod;
            final sameAsCompare = cmp != null &&
                cmp.type == period.type &&
                cmp.year == period.year &&
                cmp.month == period.month;
            setState(() {
              _selected = period;
              if (sameAsCompare) {
                _comparePeriod = null;
                _compareData = null;
              }
            });
            _load();
          },
        ),
      ),
    );
  }

  DashboardPeriod? _dropdownValue(List<DashboardPeriod> periods) {
    if (periods.isEmpty) return null;
    if (_selected == null) return periods.first;

    for (final period in periods) {
      if (period.type == _selected!.type &&
          period.year == _selected!.year &&
          period.month == _selected!.month) {
        return period;
      }
    }

    return periods.first;
  }

  // ดรอปดาวน์เลือกช่วงเวลาที่จะเอามาเทียบ (เลือกได้อิสระจากลิสต์เดียวกัน)
  Widget _buildCompareDropdown(List<DashboardPeriod> periods) {
    DashboardPeriod? resolved;
    if (_comparePeriod != null) {
      for (final period in periods) {
        if (period.type == _comparePeriod!.type &&
            period.year == _comparePeriod!.year &&
            period.month == _comparePeriod!.month) {
          resolved = period;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryLight, width: 1.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DashboardPeriod>(
          value: resolved,
          isExpanded: true,
          hint: const Text('เลือกช่วงเวลาที่จะเทียบ',
              style: TextStyle(color: AppColors.textGrey, fontSize: 14.5)),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
          items: periods.map((period) {
            return DropdownMenuItem<DashboardPeriod>(
              value: period,
              child: Text(
                period.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            );
          }).toList(),
          onChanged: (period) {
            if (period != null) _loadCompare(period);
          },
        ),
      ),
    );
  }

  Widget _buildStatCards(DashboardData data) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'เรื่องที่ส่งมา',
            value: '${data.totalReports}',
            unit: 'เรื่อง',
            icon: Icons.assignment_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'งบสมทบรวม',
            value: _money(data.totalBudget),
            unit: 'บาท',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutCard(
    DashboardData data, {
    GlobalKey? repaintKey,
    String? title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? 'เรื่องที่ส่งมาเทศบาล แยกตามหมู่บ้าน',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'จำนวนเรื่องที่งบผู้ใหญ่บ้านไม่เพียงพอและส่งต่อมาเทศบาล',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (data.donut.isEmpty)
            _emptyChart(
              icon: Icons.pie_chart_outline,
              message: 'ยังไม่มีเรื่องส่งมาในช่วงนี้',
            )
          else
            RepaintBoundary(
              key: repaintKey ?? _donutKey,
              child: Container(
                color: Colors.white,
                child: SizedBox(
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 55,
                          sections: _donutSections(data),
                        ),
                        duration: Duration.zero,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${data.totalReports}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Text(
                            'เรื่อง',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (data.donut.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildLegend(data),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _donutSections(DashboardData data) {
    return data.donut.map((item) {
      final color = _villageColor(item.village);
      return PieChartSectionData(
        value: item.count.toDouble(),
        title: '${item.count}',
        color: color,
        radius: 38,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(DashboardData data) {
    return Column(
      children: data.donut.map((item) {
        final color = _villageColor(item.village);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  villageWithMoo(item.village),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '${item.count} เรื่อง',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarCard(
    DashboardData data, {
    GlobalKey? repaintKey,
    String? title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? 'งบที่เทศบาลสมทบ แยกตามหมู่บ้าน',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'เฉพาะเรื่องที่เทศบาลสมทบงบแล้ว หน่วยเป็นบาท',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (data.bar.isEmpty)
            _emptyChart(
              icon: Icons.bar_chart,
              message: 'ยังไม่มีการสมทบงบในช่วงนี้',
            )
          else
            RepaintBoundary(
              key: repaintKey ?? _barKey,
              child: Container(
                color: Colors.white,
                child: SizedBox(
                  height: 270,
                  child: BarChart(_barData(data), duration: Duration.zero),
                ),
              ),
            ),
          if (data.bar.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildBudgetLegend(data),
          ],
        ],
      ),
    );
  }

  BarChartData _barData(DashboardData data) {
    final highestBudget = data.bar
        .map((item) => item.budget)
        .fold<double>(0, (a, b) => a > b ? a : b);

    final rawMax = highestBudget <= 0 ? 100.0 : highestBudget * 1.2;
    final niceRange = _niceNumber(rawMax, false);
    final interval = _niceNumber(niceRange / 4, true);
    final maxY = (niceRange / interval).ceilToDouble() * interval;

    return BarChartData(
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final item = data.bar[group.x];
            return BarTooltipItem(
              '${villageWithMoo(item.village)}\n${_money(rod.toY)} บาท',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            interval: interval,
            getTitlesWidget: (value, meta) {
              if (value < 0 || value > maxY) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _compactMoney(value),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textGrey,
                  ),
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 42,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.bar.length) {
                return const SizedBox();
              }

              final village = data.bar[index].village;

              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  villageWithMoo(village),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppColors.border.withValues(alpha: 0.7),
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(data.bar.length, (index) {
        final item = data.bar[index];
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: item.budget,
              color: _villageColor(item.village),
              width: data.bar.length > 7 ? 16 : 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBudgetLegend(DashboardData data) {
    return Column(
      children: data.bar.map((item) {
        final color = _villageColor(item.village);
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  villageWithMoo(item.village),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '${_money(item.budget)} บาท',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyChart({
    required IconData icon,
    required String message,
  }) {
    return Container(
      height: 130,
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.border, size: 42),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ปัดตัวเลขให้ "กลม" สวยๆ (1, 2, 5, 10 คูณเลขยกกำลัง 10) แทนการหารตรงๆ
  // กันเส้นกริด/ป้ายแกนกราฟออกมาเป็นเลขทศนิยมแปลกๆ เช่น 5.3 พัน, 19.5 พัน
  double _niceNumber(double range, bool round) {
    if (range <= 0) return 1;
    final exponent = (math.log(range) / math.ln10).floor();
    final fraction = range / math.pow(10, exponent);
    late double niceFraction;
    if (round) {
      if (fraction < 1.5) {
        niceFraction = 1;
      } else if (fraction < 3) {
        niceFraction = 2;
      } else if (fraction < 7) {
        niceFraction = 5;
      } else {
        niceFraction = 10;
      }
    } else {
      if (fraction <= 1) {
        niceFraction = 1;
      } else if (fraction <= 2) {
        niceFraction = 2;
      } else if (fraction <= 5) {
        niceFraction = 5;
      } else {
        niceFraction = 10;
      }
    }
    return niceFraction * math.pow(10, exponent);
  }

  String _compactMoney(double value) {
    if (value >= 1000000) {
      final number = value / 1000000;
      return '${number.toStringAsFixed(number % 1 == 0 ? 0 : 1)}ล.';
    }

    if (value >= 1000) {
      final number = value / 1000;
      return '${number.toStringAsFixed(number % 1 == 0 ? 0 : 1)}พัน';
    }

    return value.toStringAsFixed(0);
  }

  String _money(double number) {
    final value = number.toStringAsFixed(0);
    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(value[i]);
    }

    return buffer.toString();
  }
}
