import 'dart:html' as html;

// เปิดหน้าต่าง print ของเบราว์เซอร์ให้เองอัตโนมัติ (ไม่ต้องให้ผู้ใช้กด Ctrl+P เอง)
// พอเปิดจอ print แล้ว เลือกปลายทางเป็น "Save as PDF" ก็จะมีปุ่มบันทึกให้ตามปกติ
const String _autoPrintScript = '''
<script>
  window.addEventListener('load', function () {
    setTimeout(function () { window.print(); }, 200);
  });
</script>
''';

Future<void> openHtmlForPrint(String htmlContent) async {
  final blob = html.Blob(['$htmlContent$_autoPrintScript'], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}
