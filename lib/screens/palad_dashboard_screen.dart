import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/complaint_service.dart';
import '../theme/app_colors.dart';

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

  // ช่วงเวลาที่เลือก
  DashboardPeriod? _selected;

  // 1 หมู่บ้าน = 1 หมู่ ตายตัว
  static const Map<String, int> _villageMooMap = {
    'บุญเรืองเหนือ': 1,
    'บุญเรืองใต้': 2,
    'บ้านซาววา': 3,
    'บ้านหก': 4,
    'ต้นปล้อง': 5,
    'แดนเมือง': 6,
    'บ้านป่าเคาะ': 7,
    'บ้านต้นปล้องใต้': 8,
    'บ้านป่าอ้อ': 9,
    'บ้านภูแกง': 10,
  };

  // สีประจำหมู่บ้านแบบตายตัว
  static const Map<String, Color> _villageColors = {
    'บุญเรืองเหนือ': Color(0xFF7C5CFC),
    'บุญเรืองใต้': Color(0xFF4CAF50),
    'บ้านซาววา': Color(0xFFFF9800),
    'บ้านหก': Color(0xFF2196F3),
    'ต้นปล้อง': Color(0xFFE91E63),
    'แดนเมือง': Color(0xFF00BCD4),
    'บ้านป่าเคาะ': Color(0xFFFFC107),
    'บ้านต้นปล้องใต้': Color(0xFF9C27B0),
    'บ้านป่าอ้อ': Color(0xFF8BC34A),
    'บ้านภูแกง': Color(0xFFFF5722),
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

  Color _villageColor(String village) {
    return _villageColors[village] ?? AppColors.textGrey;
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
          const SizedBox(width: 44),
        ],
      ),
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
          _buildPeriodDropdown(data.periods),
          const SizedBox(height: 16),
          _buildStatCards(data),
          const SizedBox(height: 16),
          _buildDonutCard(data),
          const SizedBox(height: 16),
          _buildBarCard(data),
        ],
      ),
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
            setState(() => _selected = period);
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

  Widget _buildDonutCard(DashboardData data) {
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
            'เรื่องที่ส่งมาเทศบาล แยกตามหมู่บ้าน',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'จำนวนเรื่องที่งบผู้ใหญ่บ้านไม่เพียงพอและส่งต่อมาเทศบาล',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (data.donut.isEmpty)
            _emptyChart(
              icon: Icons.pie_chart_outline,
              message: 'ยังไม่มีเรื่องส่งมาในช่วงนี้',
            )
          else
            SizedBox(
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

  Widget _buildBarCard(DashboardData data) {
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
            'เฉพาะเรื่องที่เทศบาลสมทบงบแล้ว หน่วยเป็นบาท',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (data.bar.isEmpty)
            _emptyChart(
              icon: Icons.bar_chart,
              message: 'ยังไม่มีการสมทบงบในช่วงนี้',
            )
          else
            SizedBox(
              height: 270,
              child: BarChart(_barData(data)),
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

    final maxY = highestBudget == 0
        ? 100.0
        : _roundChartMax(highestBudget * 1.2);
    final interval = maxY / 4;

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
              final moo = mooOfVillage(village);

              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  moo == null ? village : 'หมู่ $moo',
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

  double _roundChartMax(double value) {
    if (value <= 100) return (value / 10).ceil() * 10;
    if (value <= 1000) return (value / 100).ceil() * 100;
    if (value <= 10000) return (value / 1000).ceil() * 1000;
    if (value <= 100000) return (value / 10000).ceil() * 10000;
    if (value <= 1000000) return (value / 100000).ceil() * 100000;
    return (value / 1000000).ceil() * 1000000;
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
