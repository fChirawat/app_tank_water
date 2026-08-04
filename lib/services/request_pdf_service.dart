import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/complaint.dart';
import '../data/repair.dart';

/// สร้างเอกสาร "ใบคำร้องทั่วไป" เป็น PDF ขนาด A4
/// ใช้โครงสร้างตามแบบฟอร์มราชการในภาพตัวอย่าง
class RequestPdfService {
  static const double _bodyFontSize = 12.2;
  static const double _smallFontSize = 10.4;

  static Future<Uint8List> build({
    required Complaint complaint,
    required List<RepairItem> items,
    required String officerName,
  }) async {
    final document = pw.Document();

    final regularFont = await PdfGoogleFonts.sarabunRegular();
    final boldFont = await PdfGoogleFonts.sarabunBold();

    final images = await _loadImages(complaint.imageUrls);

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

    // โมเดลปัจจุบันมี shortfall แต่ไม่มี availableBudget โดยตรง
    // จึงคำนวณงบประมาณที่มีจาก total - shortfall
    final systemShortfall = complaint.shortfall;
    final shortfall = systemShortfall == null
        ? total
        : systemShortfall.clamp(0, double.infinity).toDouble();
    final availableBudget =
        (total - shortfall).clamp(0, double.infinity).toDouble();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 30, 42, 28),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (context) => [
          _header(
            date: complaint.createdAt,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 15),
          _fieldLine(
            label: 'เรื่อง',
            value: subject,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 7),
          pw.Text(
            'เรียน  นายกเทศมนตรีตำบลบุญเรือง',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: _bodyFontSize,
            ),
          ),
          pw.SizedBox(height: 13),
          _placeLine(moo: moo, village: village),
          pw.SizedBox(height: 7),
          _fieldLine(
            label: 'มีความประสงค์',
            value: purpose,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 14),
          pw.SizedBox(height: 2),
          _contentFrame(
            images: images,
            items: items,
            total: total,
            availableBudget: availableBudget,
            shortfall: shortfall,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 9),
          _closingText(),
          pw.SizedBox(height: 20),
          _signatureBlock(officerName: formattedOfficerName),
        ],
      ),
    );

    return document.save();
  }

  static Future<List<pw.MemoryImage>> _loadImages(
    List<String> imageUrls,
  ) async {
    final images = <pw.MemoryImage>[];

    for (final rawUrl in imageUrls) {
      final url = rawUrl.trim();
      if (url.isEmpty) continue;

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          images.add(pw.MemoryImage(response.bodyBytes));
        }
      } catch (_) {
        // ข้ามรูปที่โหลดไม่ได้ เพื่อให้ PDF ส่วนอื่นยังสร้างต่อได้
      }
    }

    return images;
  }

  static pw.Widget _header({
    required DateTime date,
    required pw.Font boldFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            'ใบคำร้องทั่วไป',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 18,
            ),
          ),
        ),

        // เว้นพื้นที่หลังชื่อเอกสาร แล้ววางกลุ่มข้อมูลไว้ด้านขวาบน
        pw.SizedBox(height: 18),

        pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.SizedBox(
            // ความกว้างของกลุ่มอิงตามบรรทัดวันที่
            // ข้อความสำนักงาน 2 บรรทัดจะจัดกึ่งกลางอยู่เหนือวันที่
            width: 285,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'สำนักงานเทศบาลตำบลบุญเรือง',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: _bodyFontSize,
                  ),
                ),
                pw.Text(
                  'อำเภอเชียงของ จังหวัดเชียงราย',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: _bodyFontSize,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Center(
                  child: _dateLine(date),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _dateLine(DateTime date) {
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

    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('วันที่ ', style: const pw.TextStyle(fontSize: _bodyFontSize)),
        _compactValue('${date.day}', width: 32),
        pw.Text(' เดือน ', style: const pw.TextStyle(fontSize: _bodyFontSize)),
        _compactValue(months[date.month], width: 72),
        pw.Text(' พ.ศ. ', style: const pw.TextStyle(fontSize: _bodyFontSize)),
        _compactValue('$buddhistYear', width: 48),
      ],
    );
  }

  static pw.Widget _fieldLine({
    required String label,
    required String value,
    required pw.Font boldFont,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          '$label  ',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: _bodyFontSize,
          ),
        ),
        pw.Expanded(
          child: _lineValue(
            value,
            textAlign: pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  static pw.Widget _placeLine({
    required String moo,
    required String village,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text('หมู่ที่ ', style: const pw.TextStyle(fontSize: _smallFontSize)),
        _compactValue(moo, width: 34),
        pw.SizedBox(width: 5),
        pw.Text('หมู่บ้าน ', style: const pw.TextStyle(fontSize: _smallFontSize)),
        _compactValue(village, width: 108),
        pw.SizedBox(width: 5),
        pw.Text(
          'ตำบล บุญเรือง',
          style: const pw.TextStyle(fontSize: _smallFontSize),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          'อำเภอ เชียงของ',
          style: const pw.TextStyle(fontSize: _smallFontSize),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          'จังหวัด เชียงราย',
          style: const pw.TextStyle(fontSize: _smallFontSize),
        ),
      ],
    );
  }

  static pw.Widget _lineValue(
    String value, {
    pw.TextAlign textAlign = pw.TextAlign.center,
  }) {
    return pw.Container(
      height: 18,
      padding: const pw.EdgeInsets.fromLTRB(4, 0, 4, 1),
      alignment: pw.Alignment.bottomLeft,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            width: 0.6,
            style: pw.BorderStyle.dotted,
          ),
        ),
      ),
      child: pw.Text(
        value,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        textAlign: textAlign,
        style: const pw.TextStyle(fontSize: _bodyFontSize),
      ),
    );
  }

  static pw.Widget _compactValue(String value, {required double width}) {
    return pw.Container(
      width: width,
      height: 17,
      padding: const pw.EdgeInsets.fromLTRB(2, 0, 2, 1),
      alignment: pw.Alignment.bottomCenter,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            width: 0.55,
            style: pw.BorderStyle.dotted,
          ),
        ),
      ),
      child: pw.Text(
        value,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: _smallFontSize),
      ),
    );
  }

  static pw.Widget _contentFrame({
    required List<pw.MemoryImage> images,
    required List<RepairItem> items,
    required double total,
    required double availableBudget,
    required double shortfall,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.85),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('รูปภาพประกอบ', boldFont),
          pw.SizedBox(height: 5),
          _imageArea(
            images,
            itemCount: items.length,
          ),
          pw.SizedBox(height: 8),
          _sectionTitle('รายการวัสดุ', boldFont),
          pw.SizedBox(height: 4),
          _itemsTable(items, boldFont),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(8, 4, 5, 3),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 0.5),
              ),
            ),
            child: _summaryBlock(
              total: total,
              availableBudget: availableBudget,
              shortfall: shortfall,
              boldFont: boldFont,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, pw.Font boldFont) {
    return pw.Container(
      height: 22,
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.55),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: _bodyFontSize,
        ),
      ),
    );
  }

  static pw.Widget _imageArea(
    List<pw.MemoryImage> images, {
    required int itemCount,
  }) {
    final shownImages = images.take(4).toList();

    // ลดความสูงของรูปลงอัตโนมัติเมื่อมีรายการวัสดุหลายรายการ
    // เพื่อรักษาสมดุลและไม่ให้เอกสารล้น A4 หน้าเดียว
    final hasManyItems = itemCount >= 6;

    if (shownImages.isEmpty) {
      return pw.Container(
        height: hasManyItems ? 62 : 82,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.45),
        ),
        child: pw.Text(
          'ไม่มีรูปภาพประกอบ',
          style: const pw.TextStyle(fontSize: _smallFontSize),
        ),
      );
    }

    // มีรูปเดียว: ใช้หนึ่งแถวใหญ่เต็มความกว้าง
    if (shownImages.length == 1) {
      return pw.Container(
        width: double.infinity,
        height: hasManyItems ? 92 : 128,
        padding: const pw.EdgeInsets.all(5),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.5),
        ),
        child: pw.Image(
          shownImages.first,
          fit: pw.BoxFit.contain,
        ),
      );
    }

    // มี 2 รูป: แสดงหนึ่งแถว สองช่องขนาดเท่ากัน
    if (shownImages.length == 2) {
      final height = hasManyItems ? 78.0 : 102.0;
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: _imageCell(shownImages[0], height: height),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: _imageCell(shownImages[1], height: height),
          ),
        ],
      );
    }

    // มี 3–4 รูป: แสดงสองคอลัมน์และแบ่งเป็นสองแถว
    final cellHeight = hasManyItems ? 55.0 : 68.0;
    final rows = <pw.Widget>[];

    for (var index = 0; index < shownImages.length; index += 2) {
      final rightIndex = index + 1;

      rows.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            bottom: rightIndex + 1 < shownImages.length ? 5 : 0,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(
                child: _imageCell(
                  shownImages[index],
                  height: cellHeight,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: rightIndex < shownImages.length
                    ? _imageCell(
                        shownImages[rightIndex],
                        height: cellHeight,
                      )
                    : pw.Container(
                        height: cellHeight,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _imageCell(
    pw.MemoryImage image, {
    required double height,
  }) {
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5),
      ),
      child: pw.Image(
        image,
        fit: pw.BoxFit.contain,
      ),
    );
  }

  static pw.Widget _itemsTable(List<RepairItem> items, pw.Font boldFont) {
    pw.Widget headerCell(String text) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: boldFont, fontSize: _smallFontSize),
        ),
      );
    }

    pw.Widget valueCell(
      String text, {
      pw.Alignment alignment = pw.Alignment.centerLeft,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        alignment: alignment,
        child: pw.Text(
          text,
          style: const pw.TextStyle(fontSize: _smallFontSize),
        ),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          headerCell('ลำดับ'),
          headerCell('ชื่อสินค้า'),
          headerCell('จำนวน'),
          headerCell('ราคาต่อชิ้น'),
          headerCell('ราคารวม'),
        ],
      ),
    ];

    if (items.isEmpty) {
      rows.add(
        pw.TableRow(
          children: [
            valueCell('-', alignment: pw.Alignment.center),
            valueCell('ไม่มีรายการวัสดุ', alignment: pw.Alignment.center),
            valueCell('-', alignment: pw.Alignment.center),
            valueCell('-', alignment: pw.Alignment.center),
            valueCell('-', alignment: pw.Alignment.center),
          ],
        ),
      );
    } else {
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final rowTotal = item.quantity * item.unitPrice;

        rows.add(
          pw.TableRow(
            children: [
              valueCell('${index + 1}', alignment: pw.Alignment.center),
              valueCell(item.name.trim()),
              valueCell('${item.quantity}', alignment: pw.Alignment.center),
              valueCell(
                _money(item.unitPrice),
                alignment: pw.Alignment.centerRight,
              ),
              valueCell(
                _money(rowTotal),
                alignment: pw.Alignment.centerRight,
              ),
            ],
          ),
        );
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(40),
        1: const pw.FlexColumnWidth(3.8),
        2: const pw.FixedColumnWidth(52),
        3: const pw.FixedColumnWidth(80),
        4: const pw.FixedColumnWidth(80),
      },
      children: rows,
    );
  }

  static pw.Widget _summaryBlock({
    required double total,
    required double availableBudget,
    required double shortfall,
    required pw.Font boldFont,
  }) {
    pw.Widget amountRow(
      String label,
      double value, {
      bool bold = false,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 125,
              child: pw.Text(
                label,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: bold ? boldFont : null,
                  fontSize: _smallFontSize,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.SizedBox(
              width: 115,
              child: pw.Text(
                '${_money(value)} บาท',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: bold ? boldFont : null,
                  fontSize: _smallFontSize,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        amountRow('ราคารวมทั้งหมด', total),
        amountRow('งบประมาณที่มี', availableBudget),
        amountRow('เงินที่ขาด', shortfall, bold: true),
      ],
    );
  }

  static pw.Widget _closingText() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Text(
        '        ขอให้ดำเนินการให้ข้าพเจ้าตามความประสงค์ด้วย '
        'หากมีค่าธรรมเนียม ข้าพเจ้ายินดีปฏิบัติตามระเบียบของทางราชการ',
        textAlign: pw.TextAlign.left,
        style: const pw.TextStyle(
          fontSize: _bodyFontSize,
          lineSpacing: 2.5,
        ),
      ),
    );
  }

  static pw.Widget _signatureBlock({required String officerName}) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 275,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'ขอแสดงความนับถือ',
              style: const pw.TextStyle(fontSize: _bodyFontSize),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'ลงชื่อ ................................................',
              style: const pw.TextStyle(fontSize: _bodyFontSize),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              officerName.isEmpty
                  ? '(........................................)'
                  : '($officerName)',
              style: const pw.TextStyle(fontSize: _bodyFontSize),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'ปลัดเทศบาลตำบลบุญเรือง',
              style: const pw.TextStyle(fontSize: _bodyFontSize),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isOtherProblem(String problemType) {
    final normalized = problemType.replaceAll(' ', '');
    return normalized == 'อื่นๆ';
  }

  static String _formatOfficerName(String value) {
    var result = value.trim().replaceAll(RegExp(r'\s+'), ' ');

    // จัดคำนำหน้าไม่ให้แยกออกจากชื่อ เช่น "นาย จิรวัฒน์" -> "นายจิรวัฒน์"
    for (final prefix in ['นาย', 'นาง', 'นางสาว']) {
      if (result.startsWith('$prefix ')) {
        result = '$prefix${result.substring(prefix.length + 1)}';
        break;
      }
    }

    return result;
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
