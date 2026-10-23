import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Product {
  final String id;
  final String name;
  final int price;
  const Product({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory Product.fromJson(Map<String, dynamic> j) =>
      Product(id: j['id'] as String, name: j['name'] as String, price: j['price'] as int);
}

// ---------- format ----------

const _months = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
];
const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String monthName(int m) => _months[m - 1];
String shortMonth(int m) => _months[m - 1].substring(0, 3);
String dayName(DateTime d) => _days[d.weekday - 1];
String fmtDate(DateTime d) => '${d.day} ${shortMonth(d.month)} ${d.year}';
String fmtLong(DateTime d) => '${dayName(d)}, ${d.day} ${monthName(d.month)} ${d.year}';

String group(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  return b.toString();
}

String rp(num v) {
  final neg = v < 0;
  return '${neg ? '-' : ''}Rp ${group(v.abs().round().toString())}';
}

int parseMoney(String s) => int.tryParse(s.replaceAll('.', '')) ?? 0;

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String periodText(NoteData n) {
  final keys = n.dayKeys;
  if (keys.isEmpty) return 'Belum ada penjualan dicatat';
  if (keys.first == keys.last) return fmtDate(parseKey(keys.first));
  return '${fmtDate(parseKey(keys.first))} - ${fmtDate(parseKey(keys.last))}';
}

/// Angka dengan tanda: rugi diberi "-", profit diberi "+".
String signedRp(int v) => v > 0 ? '+${rp(v)}' : rp(v);

// ---------- data catatan ----------

enum Standing { rugi, balikModal, profit }

/// Satu catatan lengkap (modal, produk, penjualan) beserta hitungannya.
class NoteData {
  int modal;
  List<Product> products;

  /// tanggal (yyyy-MM-dd) -> id produk -> jumlah terjual
  final Map<String, Map<String, int>> sales;

  NoteData({this.modal = 0, List<Product>? products, Map<String, Map<String, int>>? sales})
      : products = products ?? [],
        sales = sales ?? {};

  int dayRevenue(String key) {
    final d = sales[key];
    if (d == null) return 0;
    var t = 0;
    for (final p in products) {
      t += (d[p.id] ?? 0) * p.price;
    }
    return t;
  }

  int dayUnits(String key) => (sales[key] ?? {}).values.fold(0, (a, b) => a + b);

  int productUnits(String id) => sales.values.fold(0, (a, d) => a + (d[id] ?? 0));

  int get revenue => sales.keys.fold(0, (a, k) => a + dayRevenue(k));
  int get totalUnits => sales.keys.fold(0, (a, k) => a + dayUnits(k));
  int get result => revenue - modal;

  Standing get standing => revenue < modal
      ? Standing.rugi
      : (revenue == modal ? Standing.balikModal : Standing.profit);

  List<String> get dayKeys => sales.keys.toList()..sort();

  /// Status tiap hari berdasarkan pendapatan kumulatif:
  /// rugi sebelum modal tercapai, balik modal di hari modal tercapai, profit sesudahnya.
  Map<String, Standing> get dayStandings {
    final out = <String, Standing>{};
    var cum = 0;
    var reached = false;
    for (final k in dayKeys) {
      cum += dayRevenue(k);
      if (modal > 0 && cum >= modal) {
        out[k] = reached ? Standing.profit : Standing.balikModal;
        reached = true;
      } else {
        out[k] = Standing.rugi;
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'modal': modal,
        'products': products.map((p) => p.toJson()).toList(),
        'sales': sales,
      };

  void loadJson(Map<String, dynamic> j) {
    modal = j['modal'] as int;
    products = [
      for (final p in j['products'] as List) Product.fromJson(p as Map<String, dynamic>)
    ];
    sales.clear();
    (j['sales'] as Map<String, dynamic>).forEach((k, v) {
      sales[k] = (v as Map<String, dynamic>).map((a, b) => MapEntry(a, b as int));
    });
  }
}

/// Catatan lama yang disimpan di Riwayat.
class ArchivedNote extends NoteData {
  final String id;
  final DateTime savedAt;
  ArchivedNote({
    required this.id,
    required this.savedAt,
    required super.modal,
    required super.products,
    required super.sales,
  });

  @override
  Map<String, dynamic> toJson() =>
      {...super.toJson(), 'id': id, 'savedAt': savedAt.toIso8601String()};

  factory ArchivedNote.fromJson(Map<String, dynamic> j) {
    final n = NoteData()..loadJson(j);
    return ArchivedNote(
      id: j['id'] as String,
      savedAt: DateTime.parse(j['savedAt'] as String),
      modal: n.modal,
      products: n.products,
      sales: n.sales,
    );
  }
}

// ---------- state ----------

class AppState extends NoteData with ChangeNotifier {
  static const _storeKey = 'modalku_v2';

  final List<ArchivedNote> history = [];

  bool get isSetup => modal > 0 && products.isNotEmpty;

  Future<void> setup(int newModal, List<Product> newProducts) async {
    modal = newModal;
    products = List.of(newProducts);
    sales.clear();
    await _save();
    notifyListeners();
  }

  Future<void> saveDay(String key, Map<String, int> qty) async {
    final clean = {
      for (final e in qty.entries)
        if (e.value > 0) e.key: e.value
    };
    if (clean.isEmpty) {
      sales.remove(key);
    } else {
      sales[key] = clean;
    }
    await _save();
    notifyListeners();
  }

  /// Mulai catatan baru. Catatan yang sudah punya penjualan disimpan ke Riwayat.
  Future<void> startNew() async {
    if (isSetup && sales.isNotEmpty) {
      history.insert(
        0,
        ArchivedNote(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          savedAt: DateTime.now(),
          modal: modal,
          products: List.of(products),
          sales: {for (final e in sales.entries) e.key: Map.of(e.value)},
        ),
      );
    }
    modal = 0;
    products = [];
    sales.clear();
    await _save();
    notifyListeners();
  }

  Future<void> deleteHistory(String id) async {
    history.removeWhere((h) => h.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey) ?? prefs.getString('modalku_v1');
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      loadJson(j);
      history.clear();
      for (final h in (j['history'] as List? ?? [])) {
        history.add(ArchivedNote.fromJson(h as Map<String, dynamic>));
      }
    } catch (_) {
      // data rusak: mulai dari kosong
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      jsonEncode({...toJson(), 'history': history.map((h) => h.toJson()).toList()}),
    );
  }
}
