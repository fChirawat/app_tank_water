import 'dart:typed_data';

import 'package:flutter_native_html_to_pdf/flutter_native_html_to_pdf.dart';

// แถวข้อมูล 1 แถวในตารางรายงาน (ใช้ได้ทั้งตารางจำนวนเรื่องและตารางงบ)
class DashboardReportRow {
  final String label;
  final int? count;
  final double? amount;

  const DashboardReportRow({required this.label, this.count, this.amount});
}

// แถวเปรียบเทียบงบ 1 แทงค์/หมู่บ้าน ระหว่าง 2 ช่วงเวลา
class DashboardCompareBarRow {
  final String label;
  final double olderValue;
  final double newerValue;

  const DashboardCompareBarRow({
    required this.label,
    required this.olderValue,
    required this.newerValue,
  });
}

/// สร้างรายงานสรุป Dashboard เป็น PDF (ฟีเจอร์เสริม ต้องปลดล็อกก่อนถึงจะเรียกใช้)
/// ใช้ร่วมกันได้ทั้ง Dashboard ผู้ใหญ่บ้านและเทศบาล
class DashboardPdfService {
  static final HtmlToPdfConverter _converter = HtmlToPdfConverter();

  static Future<Uint8List> build({
    required String title,
    required String periodLabel,
    required int totalReports,
    required double totalBudget,
    required String donutTitle,
    required List<DashboardReportRow> donutRows,
    required String barTitle,
    required List<DashboardReportRow> barRows,
    // รูปกราฟจริงจากหน้าจอ (base64 data URL) — ไม่ใส่มาก็ยังพิมพ์ได้ปกติ
    // แค่ไม่มีรูปกราฟ เหลือแต่ตาราง
    String? donutImageDataUrl,
    String? barImageDataUrl,
    // ฟีเจอร์เสริม: เปรียบเทียบกับอีกช่วงเวลาหนึ่ง — ไม่ใส่ olderLabel มา =
    // ไม่พิมพ์ส่วนนี้ (เทียบเฉพาะงบเป็นกราฟแท่งคู่ ไม่มีโดนัทตอนเทียบ)
    // ต้องเรียงเป็น "เก่า" ก่อน "ใหม่" เสมอ (ไม่ใช่ตามลำดับที่ผู้ใช้กดเลือก)
    String? olderLabel,
    int? olderTotalReports,
    double? olderTotalBudget,
    String? newerLabel,
    int? newerTotalReports,
    double? newerTotalBudget,
    List<DashboardCompareBarRow>? compareBarBreakdown,
    String? compareBarImageDataUrl,
    // false = ไม่พิมพ์ส่วนโดนัท/แท่งของช่วงเวลาเดียว (ใช้ตอนเทียบ 2 ช่วง ที่
    // หน้าจอเองก็ไม่โชว์กราฟเดี่ยวแล้วเหมือนกัน)
    bool showSinglePeriodSections = true,
  }) async {
    final html = buildHtml(
      title: title,
      periodLabel: periodLabel,
      totalReports: totalReports,
      totalBudget: totalBudget,
      donutTitle: donutTitle,
      donutRows: donutRows,
      barTitle: barTitle,
      barRows: barRows,
      donutImageDataUrl: donutImageDataUrl,
      barImageDataUrl: barImageDataUrl,
      olderLabel: olderLabel,
      olderTotalReports: olderTotalReports,
      olderTotalBudget: olderTotalBudget,
      newerLabel: newerLabel,
      newerTotalReports: newerTotalReports,
      newerTotalBudget: newerTotalBudget,
      compareBarBreakdown: compareBarBreakdown,
      compareBarImageDataUrl: compareBarImageDataUrl,
      showSinglePeriodSections: showSinglePeriodSections,
    );

    final bytes = await _converter.convertHtmlToPdfBytes(html: html);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('ไม่สามารถสร้างไฟล์ PDF ได้');
    }
    return bytes;
  }

  // เปิดเป็น public ไว้ให้ฝั่งเว็บเรียกตรงๆ ได้ (ดู web_print.dart) —
  // เว็บไม่มี flutter_native_html_to_pdf ให้แปลงเป็น PDF bytes เลยเปิด HTML
  // นี้ในแท็บใหม่แทน แล้วให้ผู้ใช้กด Print ของเบราว์เซอร์ -> Save as PDF เอา
  static String buildHtml({
    required String title,
    required String periodLabel,
    required int totalReports,
    required double totalBudget,
    required String donutTitle,
    required List<DashboardReportRow> donutRows,
    required String barTitle,
    required List<DashboardReportRow> barRows,
    String? donutImageDataUrl,
    String? barImageDataUrl,
    String? olderLabel,
    int? olderTotalReports,
    double? olderTotalBudget,
    String? newerLabel,
    int? newerTotalReports,
    double? newerTotalBudget,
    List<DashboardCompareBarRow>? compareBarBreakdown,
    String? compareBarImageDataUrl,
    bool showSinglePeriodSections = true,
  }) {
    final comparing = olderLabel != null && newerLabel != null;
    final now = DateTime.now();
    final printedAt =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year + 543} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} น.';

    return '''
<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <style>
    * { box-sizing: border-box; }
    @page { size: A4 portrait; margin: 14mm 12mm; }
    html, body {
      margin: 0;
      padding: 0;
      color: #000;
      font-family: "Noto Sans Thai", "Sarabun", Tahoma, sans-serif;
      font-size: 15px;
      line-height: 1.4;
    }
    h1 {
      text-align: center;
      font-size: 24px;
      margin: 0 0 4px;
    }
    .subtitle {
      text-align: center;
      color: #555;
      font-size: 14px;
      margin-bottom: 20px;
    }
    .stats {
      display: flex;
      gap: 12px;
      margin-bottom: 22px;
    }
    .stat-box {
      flex: 1;
      border: 1px solid #999;
      border-radius: 8px;
      padding: 10px 14px;
    }
    .stat-label { font-size: 12px; color: #555; }
    .stat-value { font-size: 20px; font-weight: 700; margin-top: 2px; }
    h2 {
      font-size: 16px;
      border-bottom: 1px solid #999;
      padding-bottom: 4px;
      margin-top: 26px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 8px;
      font-size: 13px;
    }
    th, td {
      border: 1px solid #999;
      padding: 5px 8px;
    }
    th { background: #f0f0f0; text-align: left; }
    td.num { text-align: right; }
    .empty { color: #777; font-style: italic; padding: 10px 0; }
    .chart-img {
      display: block;
      max-width: 100%;
      max-height: 260px;
      margin: 10px auto 0;
    }
    .compare-up { color: #3B7DD8; font-weight: 700; }
    .compare-down { color: #D9534F; font-weight: 700; }
    .compare-flat { color: #777; font-weight: 700; }
    .footer {
      margin-top: 28px;
      font-size: 11px;
      color: #777;
      text-align: right;
    }
  </style>
</head>
<body>
  <h1>${_escapeHtml(title)}</h1>
  <div class="subtitle">${_escapeHtml(
      comparing ? 'เปรียบเทียบ $olderLabel กับ $newerLabel' : periodLabel,
    )}</div>

  ${!comparing ? '''
  <div class="stats">
    <div class="stat-box">
      <div class="stat-label">จำนวนเรื่อง</div>
      <div class="stat-value">$totalReports เรื่อง</div>
    </div>
    <div class="stat-box">
      <div class="stat-label">งบรวม</div>
      <div class="stat-value">${_money(totalBudget)} บาท</div>
    </div>
  </div>
  ''' : _compareSection(
            olderLabel: olderLabel,
            newerLabel: newerLabel,
            olderTotalReports: olderTotalReports ?? 0,
            newerTotalReports: newerTotalReports ?? 0,
            olderTotalBudget: olderTotalBudget ?? 0,
            newerTotalBudget: newerTotalBudget ?? 0,
          )}

  ${!showSinglePeriodSections ? '' : '''
  <h2>${_escapeHtml(donutTitle)}</h2>
  ${donutImageDataUrl == null ? '' : '<img class="chart-img" src="$donutImageDataUrl">'}
  ${_countTable(donutRows)}

  <h2>${_escapeHtml(barTitle)}</h2>
  ${barImageDataUrl == null ? '' : '<img class="chart-img" src="$barImageDataUrl">'}
  ${_amountTable(barRows)}
  '''}

  ${!comparing ? '' : '''
  <h2>${_escapeHtml(barTitle)} — เปรียบเทียบ</h2>
  ${compareBarImageDataUrl == null ? '' : '<img class="chart-img" src="$compareBarImageDataUrl">'}
  ${_compareBarTable(compareBarBreakdown ?? const [], olderLabel, newerLabel)}
  '''}

  <div class="footer">พิมพ์เมื่อ $printedAt</div>
</body>
</html>
''';
  }

  static String _compareSection({
    required String olderLabel,
    required String newerLabel,
    required int olderTotalReports,
    required int newerTotalReports,
    required double olderTotalBudget,
    required double newerTotalBudget,
  }) {
    return '''
      <h2>สรุปตัวเลขรวม</h2>
      <table>
        <thead>
          <tr>
            <th>ตัวชี้วัด</th>
            <th>${_escapeHtml(olderLabel)}</th>
            <th>${_escapeHtml(newerLabel)}</th>
            <th>เปลี่ยนแปลง</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>จำนวนเรื่อง</td>
            <td class="num">$olderTotalReports</td>
            <td class="num">$newerTotalReports</td>
            <td class="num">${_deltaHtml(newerTotalReports.toDouble(), olderTotalReports.toDouble(), isMoney: false)}</td>
          </tr>
          <tr>
            <td>งบรวม (บาท)</td>
            <td class="num">${_money(olderTotalBudget)}</td>
            <td class="num">${_money(newerTotalBudget)}</td>
            <td class="num">${_deltaHtml(newerTotalBudget, olderTotalBudget)}</td>
          </tr>
        </tbody>
      </table>
    ''';
  }

  static String _compareBarTable(
    List<DashboardCompareBarRow> rows,
    String olderLabel,
    String newerLabel,
  ) {
    if (rows.isEmpty) return '<div class="empty">ไม่มีข้อมูลในช่วงนี้</div>';
    final body = rows.map((r) => '''
      <tr>
        <td>${_escapeHtml(r.label)}</td>
        <td class="num">${_money(r.olderValue)}</td>
        <td class="num">${_money(r.newerValue)}</td>
        <td class="num">${_deltaHtml(r.newerValue, r.olderValue)}</td>
      </tr>
    ''').join();
    return '''
      <table>
        <thead>
          <tr>
            <th>รายการ</th>
            <th>${_escapeHtml(olderLabel)}</th>
            <th>${_escapeHtml(newerLabel)}</th>
            <th>เปลี่ยนแปลง</th>
          </tr>
        </thead>
        <tbody>$body</tbody>
      </table>
    ''';
  }

  // เทียบ "ใหม่" กับ "เก่า" (current, compare) เสมอ ไม่ว่าจะโชว์คอลัมน์ไหนก่อน
  static String _deltaHtml(double current, double compare, {bool isMoney = true}) {
    final diff = current - compare;
    if (diff == 0) return '<span class="compare-flat">เท่าเดิม</span>';
    final pctText = compare == 0
        ? (isMoney ? _money(diff.abs()) : diff.abs().round().toString())
        : '${(diff / compare * 100).abs().toStringAsFixed(0)}%';
    final cls = diff > 0 ? 'compare-up' : 'compare-down';
    final arrow = diff > 0 ? '▲' : '▼';
    return '<span class="$cls">$arrow $pctText</span>';
  }

  static String _countTable(List<DashboardReportRow> rows) {
    if (rows.isEmpty) return '<div class="empty">ไม่มีข้อมูลในช่วงนี้</div>';
    final body = rows.map((r) => '''
      <tr>
        <td>${_escapeHtml(r.label)}</td>
        <td class="num">${r.count ?? 0}</td>
      </tr>
    ''').join();
    return '''
      <table>
        <thead><tr><th>รายการ</th><th>จำนวน (เรื่อง)</th></tr></thead>
        <tbody>$body</tbody>
      </table>
    ''';
  }

  static String _amountTable(List<DashboardReportRow> rows) {
    if (rows.isEmpty) return '<div class="empty">ไม่มีข้อมูลในช่วงนี้</div>';
    final body = rows.map((r) => '''
      <tr>
        <td>${_escapeHtml(r.label)}</td>
        <td class="num">${_money(r.amount ?? 0)}</td>
      </tr>
    ''').join();
    return '''
      <table>
        <thead><tr><th>รายการ</th><th>งบ (บาท)</th></tr></thead>
        <tbody>$body</tbody>
      </table>
    ''';
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  static String _money(num value) {
    final fixed = value.toDouble().toStringAsFixed(2);
    final parts = fixed.split('.');
    final integerPart = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$integerPart.${parts.last}';
  }
}
