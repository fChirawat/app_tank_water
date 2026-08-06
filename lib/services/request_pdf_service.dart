import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_native_html_to_pdf/flutter_native_html_to_pdf.dart';
import 'package:http/http.dart' as http;

import '../data/complaint.dart';
import '../data/repair.dart';

/// สร้างเอกสาร "ใบคำร้องทั่วไป" เป็น PDF ขนาด A4
/// โดยใช้ Native WebView จัดวางภาษาไทยผ่าน HTML/CSS
class RequestPdfService {
  static final HtmlToPdfConverter _converter = HtmlToPdfConverter();

  static Future<Uint8List> build({
    required Complaint complaint,
    required List<RepairItem> items,
    required String officerName,
  }) async {
    final problemType = complaint.problemType.trim();
    final detail = (complaint.detail ?? '').trim();
    final subject = _isOtherProblem(problemType) && detail.isNotEmpty
        ? detail
        : problemType;

    final moo = complaint.tankMoo?.toString().trim() ?? '';
    final village = (complaint.tankVillage ?? '').trim();
    final purpose = (complaint.surveyNote ?? '').trim();
    final formattedOfficerName = _formatOfficerName(officerName);

    final total = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );

    final systemShortfall = complaint.shortfall;
    final shortfall = systemShortfall == null
        ? total
        : systemShortfall.clamp(0, double.infinity).toDouble();
    final availableBudget =
        (total - shortfall).clamp(0, double.infinity).toDouble();

    final imageDataUrls = await _loadImagesAsDataUrls(
      complaint.imageUrls,
      maxImages: 4,
    );

    final html = _buildHtml(
      date: complaint.createdAt,
      subject: subject,
      moo: moo,
      village: village,
      purpose: purpose,
      officerName: formattedOfficerName,
      images: imageDataUrls,
      items: items,
      total: total,
      availableBudget: availableBudget,
      shortfall: shortfall,
    );

    final bytes = await _converter.convertHtmlToPdfBytes(html: html);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('ไม่สามารถสร้างไฟล์ PDF ได้');
    }

    return bytes;
  }

  static String _buildHtml({
    required DateTime date,
    required String subject,
    required String moo,
    required String village,
    required String purpose,
    required String officerName,
    required List<String> images,
    required List<RepairItem> items,
    required double total,
    required double availableBudget,
    required double shortfall,
  }) {
    const months = <String>[
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];

    final buddhistYear = date.year + 543;

    final imageHtml = images.isEmpty
        ? '<div class="empty-image">ไม่มีรูปภาพประกอบ</div>'
        : '''
          <div class="image-grid count-${images.length}">
            ${images.map((dataUrl) => '''
              <div class="image-cell">
                <img src="$dataUrl" alt="รูปภาพประกอบ">
              </div>
            ''').join()}
          </div>
        ''';

    final itemRows = items.isEmpty
        ? '''
          <tr>
            <td class="center">-</td>
            <td class="center">ไม่มีรายการวัสดุ</td>
            <td class="center">-</td>
            <td class="center">-</td>
            <td class="center">-</td>
          </tr>
        '''
        : List.generate(items.length, (index) {
            final item = items[index];
            final rowTotal = item.quantity * item.unitPrice;
            return '''
              <tr>
                <td class="center">${index + 1}</td>
                <td>${_escapeHtml(item.name.trim())}</td>
                <td class="center">${item.quantity}</td>
                <td class="right">${_money(item.unitPrice)}</td>
                <td class="right">${_money(rowTotal)}</td>
              </tr>
            ''';
          }).join();

    return '''
<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    @page { size: A4 portrait; margin: 10mm 12mm 9mm; }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      color: #000;
      background: #fff;
      font-family: "Noto Sans Thai", "Sarabun", Tahoma, sans-serif;
      font-size: 21px;
      line-height: 1.4;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .document-title {
      margin: 0 0 17px;
      padding-top: 10px;
      text-align: center;
      font-size: 38px;
      line-height: 1.7;
      font-weight: 700;
    }
    .office-block {
      width: 285px;
      margin: 0 0 11px auto;
      text-align: center;
      line-height: 1.4;
    }
    .date-row {
      display: flex;
      justify-content: center;
      align-items: baseline;
      gap: 8px;
      margin-top: 5px;
      white-space: nowrap;
    }
    .date-value {
      display: inline-block;
      min-width: 40px;
      margin: 0 4px;
      padding: 2px 6px 1px;
      border-bottom: 1px dotted #000;
      line-height: 1.5;
      text-align: center;
    }
    .date-month { min-width: 110px; }
    .date-year { min-width: 60px; }
    .field-row {
      display: flex;
      align-items: flex-end;
      flex-wrap: wrap;
      gap: 2px 4px;
      width: 100%;
      margin-bottom: 9px;
    }
    .field-label {
      flex: 0 0 auto;
      font-size: 20px;
      font-weight: 700;
      line-height: 1.5;
      white-space: nowrap;
    }
    .field-value {
      flex: 0 1 auto;
      min-width: 40px;
      min-height: 20px;
      padding: 2px 6px 1px;
      border-bottom: 1px dotted #000;
      line-height: 1.5;
      text-align: center;
      overflow-wrap: anywhere;
    }
    .field-plain {
      flex: 0 1 auto;
      line-height: 1.5;
      padding-bottom: 1px;
    }
    .place-line .field-value { min-width: 30px; }
    .place-line .field-plain { font-weight: 700; }
    .place-row {
      display: flex;
      align-items: flex-end;
      gap: 5px;
      width: 100%;
      margin: 10px 0 7px;
      font-size: 18px;
      white-space: nowrap;
    }
    .place-value {
      display: inline-block;
      min-height: 21px;
      padding: 0 3px 0px;
      border-bottom: 1px dotted #000;
      text-align: center;
      line-height: 1.5;
    }
    .moo-value { width: 34px; }
    .village-value {
      width: 112px;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .content-frame {
      width: 100%;
      margin-top: 14px;
      padding: 8px;
      border: 1px solid #000;
      break-inside: avoid;
    }
    .section-title {
      min-height: 23px;
      padding: 2px 7px 4px;
      border-bottom: 1px solid #777;
      font-weight: 700;
      line-height: 1.45;
    }
    .image-grid {
      display: grid;
      width: 100%;
      gap: 6px;
      margin: 5px 0 8px;
    }
    .image-grid.count-1 { grid-template-columns: 1fr; }
    .image-grid.count-2,
    .image-grid.count-3,
    .image-grid.count-4 { grid-template-columns: repeat(2, 1fr); }
    .image-cell {
      display: flex;
      align-items: center;
      justify-content: center;
      height: 165px;
      padding: 4px;
      border: 1px solid #888;
      overflow: hidden;
    }
    .image-grid.count-1 .image-cell { height: 240px; }
    .image-cell img {
      display: block;
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
    }
    .empty-image {
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100px;
      margin: 5px 0 8px;
      border: 1px solid #888;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      table-layout: fixed;
      margin-top: 4px;
      font-size: 18px;
    }
    th, td {
      padding: 3px 4px;
      border: 1px solid #555;
      vertical-align: middle;
      line-height: 1.35;
      word-break: break-word;
    }
    th { font-weight: 700; text-align: center; }
    .col-index { width: 8%; }
    .col-name { width: 47%; }
    .col-quantity { width: 13%; }
    .col-price, .col-total { width: 16%; }
    .center { text-align: center; }
    .right { text-align: right; }
    .summary {
      width: 340px;
      margin: 6px 0 0 auto;
      padding-top: 4px;
      border-top: 1px solid #888;
      font-size: 18px;
    }
    .summary-row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      column-gap: 10px;
      line-height: 1.6;
      white-space: nowrap;
    }
    .summary-label { text-align: left; }
    .summary-value { text-align: right; }
    .summary-row.strong { font-weight: 700; }
    .closing {
      margin: 9px 28px 0;
      font-size: 21px;
      line-height: 1.65;
      text-indent: 26px;
    }

    .subject-value {
      position: relative;
      top: 2px;
    }

    .moo-value-fix {
      position: relative;
      top: 5px;
    }

    .village-value-fix {
      position: relative;
      top: 4.5px;
    }

    .purpose-value {
      position: relative;
      top: 2px;
    }
    .signature {
      width: 330px;
      margin: 17px 20px 0 auto;
      text-align: center;
      font-size: 21px;
      line-height: 1.5;
      break-inside: avoid;
    }
    .signature-space { height: 25px; }
    .signature-line { margin-bottom: 3px; white-space: nowrap; }
    @media print {
      html, body { width: 210mm; }
      .content-frame, table, .signature { break-inside: avoid; }
    }
  </style>
</head>
<body>
  <h1 class="document-title">ใบคำร้องทั่วไป</h1>

  <div class="office-block">
    <div>สำนักงานเทศบาลตำบลบุญเรือง</div>
    <div>อำเภอเชียงของ จังหวัดเชียงราย</div>
    <div class="date-row">
      <span>วันที่</span>
      <span class="date-value">${date.day}</span>
      <span>เดือน</span>
      <span class="date-value date-month">${months[date.month]}</span>
      <span>พ.ศ.</span>
      <span class="date-value date-year">$buddhistYear</span>
    </div>
  </div>

  <div class="field-row">
    <div class="field-label">เรื่อง</div>
    <div class="field-value">${_escapeHtml(subject)}</div>
  </div>

  <div class="field-row">
    <div class="field-label">เรียน</div>
    <div class="field-plain">นายกเทศมนตรีตำบลบุญเรือง</div>
  </div>

  <div class="field-row place-line">
    <div class="field-label">หมู่ที่</div>
    <div class="field-value">${_escapeHtml(moo)}</div>
    <div class="field-plain">บ้าน</div>
    <div class="field-value">${_escapeHtml(village)}</div>
    <div class="field-plain">ตำบล</div>
    <div class="field-value">บุญเรือง</div>
    <div class="field-plain">อำเภอ</div>
    <div class="field-value">เชียงของ</div>
    <div class="field-plain">จังหวัด</div>
    <div class="field-value">เชียงราย</div>
  </div>

  <div class="field-row">
    <div class="field-label">มีความประสงค์</div>
    <div class="field-value">${_escapeHtml(purpose)}</div>
  </div>

  <section class="content-frame">
    <div class="section-title">รูปภาพประกอบ</div>
    $imageHtml
    <div class="section-title">รายการวัสดุ</div>

    <table>
      <colgroup>
        <col class="col-index">
        <col class="col-name">
        <col class="col-quantity">
        <col class="col-price">
        <col class="col-total">
      </colgroup>
      <thead>
        <tr>
          <th>ลำดับ</th>
          <th>ชื่อสินค้า</th>
          <th>จำนวน</th>
          <th>ราคาต่อชิ้น</th>
          <th>ราคารวม</th>
        </tr>
      </thead>
      <tbody>$itemRows</tbody>
    </table>

    <div class="summary">
      <div class="summary-row">
        <div class="summary-label">ราคารวมทั้งหมด</div>
        <div class="summary-value">${_money(total)} บาท</div>
      </div>
      <div class="summary-row">
        <div class="summary-label">งบประมาณที่มี</div>
        <div class="summary-value">${_money(availableBudget)} บาท</div>
      </div>
      <div class="summary-row strong">
        <div class="summary-label">เงินที่ขาด</div>
        <div class="summary-value">${_money(shortfall)} บาท</div>
      </div>
    </div>
  </section>

  <div class="closing">
    ขอให้ดำเนินการให้ข้าพเจ้าตามความประสงค์ด้วย
    หากมีค่าธรรมเนียม ข้าพเจ้ายินดีปฏิบัติตามระเบียบของทางราชการ
  </div>

  <div class="signature">
    <div>ขอแสดงความนับถือ</div>
    <div class="signature-space"></div>
    <div class="signature-line">ลงชื่อ ...........................</div>
    <div>(นายธนศักดิ์ แอ่นปัญญา)</div>
    <div>นายกเทศมนตรีตำบลบุญเรือง</div>
  </div>
</body>
</html>
''';
  }

  static Future<List<String>> _loadImagesAsDataUrls(
    List<String> imageUrls, {
    required int maxImages,
  }) async {
    final images = <String>[];

    for (final rawUrl in imageUrls.take(maxImages)) {
      final url = rawUrl.trim();
      if (url.isEmpty) continue;

      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          continue;
        }

        final contentType =
            response.headers['content-type']?.split(';').first.trim();
        final mimeType = _supportedImageMimeType(contentType);
        if (mimeType == null) continue;

        images.add('data:$mimeType;base64,${base64Encode(response.bodyBytes)}');
      } catch (_) {
        // ข้ามรูปที่โหลดไม่ได้ เพื่อให้ส่วนอื่นของ PDF สร้างต่อได้
      }
    }

    return images;
  }

  static String? _supportedImageMimeType(String? value) {
    switch (value?.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'image/jpeg';
      case 'image/png':
        return 'image/png';
      case 'image/webp':
        return 'image/webp';
      case 'image/gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  static bool _isOtherProblem(String problemType) {
    final normalized = problemType.replaceAll(' ', '');
    return normalized == 'อื่นๆ';
  }

  static String _formatOfficerName(String value) {
    var result = value.trim().replaceAll(RegExp(r'\s+'), ' ');

    for (final prefix in ['นาย', 'นาง', 'นางสาว']) {
      if (result.startsWith('$prefix ')) {
        result = '$prefix${result.substring(prefix.length + 1)}';
        break;
      }
    }

    return result;
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