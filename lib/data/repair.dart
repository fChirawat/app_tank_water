// ===== รายการวัสดุซ่อม 1 รายการ =====
class RepairItem {
  final String id;
  final String name; // ชื่อวัสดุ
  final int quantity; // จำนวน
  final double unitPrice; // ราคาต่อชิ้น

  const RepairItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  // ราคารวมของรายการนี้ (จำนวน x ราคาต่อชิ้น)
  double get total => quantity * unitPrice;

  factory RepairItem.fromJson(Map<String, dynamic> json) {
    return RepairItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
    );
  }
}

// ===== บันทึกความคืบหน้าการซ่อม 1 ครั้ง =====
class RepairLog {
  final String id;
  final String note; // วันนี้ทำอะไรไปบ้าง
  final DateTime createdAt;

  const RepairLog({
    required this.id,
    required this.note,
    required this.createdAt,
  });

  factory RepairLog.fromJson(Map<String, dynamic> json) {
    return RepairLog(
      id: json['id'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}