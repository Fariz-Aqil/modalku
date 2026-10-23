import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'app_state.dart';
import 'report_pdf.dart';
import 'theme.dart';
import 'widgets.dart';

Color standingColor(Standing s) => switch (s) {
      Standing.rugi => C.red,
      Standing.balikModal => C.ink,
      Standing.profit => C.greenText,
    };

String standingText(NoteData s) => switch (s.standing) {
      Standing.rugi => 'Rugi ${rp(s.result)}',
      Standing.balikModal => 'Balik modal',
      Standing.profit => 'Profit +${rp(s.result)}',
    };

// =====================================================================
// HALAMAN UTAMA
// =====================================================================

class HomePage extends StatelessWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  void _openSetup(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SetupPage(state: state)));

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.cream,
        title: Text('Mulai catatan baru?', style: display(20)),
        content: Text(state.sales.isEmpty
            ? 'Catatan ini belum ada penjualan, jadi tidak disimpan ke Riwayat.'
            : 'Catatan saat ini disimpan ke Riwayat, lalu kamu mulai dari awal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: C.ink))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mulai baru', style: TextStyle(fontWeight: FontWeight.w800, color: C.ink))),
        ],
      ),
    );
    if (ok == true) await state.startNew();
  }

  Widget _barButton(IconData icon, String label, VoidCallback onTap) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: C.ink),
        label: Text(label, style: display(16)),
        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final ready = state.isSetup;
        return Scaffold(
          backgroundColor: C.cream,
          body: Column(
            children: [
              // ---- atas (kuning) ----
              Container(
                width: double.infinity,
                color: C.yellow,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: ready
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TargetBar(revenue: state.revenue, modal: state.modal),
                              const SizedBox(height: 4),
                              Text('Pendapatan ${rp(state.revenue)} dari modal ${rp(state.modal)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          )
                        : const SizedBox(height: 40),
                  ),
                ),
              ),
              // ---- isi (krem) ----
              Expanded(
                child: ready
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                        children: [
                          CalendarView(
                            state: state,
                            onPick: (d) => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SalesPage(state: state, date: d)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Center(
                            child: Text('Ketuk tanggal untuk mencatat penjualan',
                                style: TextStyle(color: C.mute, fontStyle: FontStyle.italic)),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up_rounded, size: 110, color: Color(0xFFBDBDBD)),
                                const SizedBox(height: 14),
                                const Text('Catatan belum dibuat',
                                    style: TextStyle(fontSize: 19, color: C.mute, fontStyle: FontStyle.italic)),
                                const SizedBox(height: 4),
                                const Text('Ketuk + untuk mulai',
                                    style: TextStyle(color: C.mute)),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 24,
                            bottom: 24,
                            child: Semantics(
                              button: true,
                              label: 'Buat catatan baru',
                              child: Material(
                                color: C.yellow,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openSetup(context),
                                  child: const SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: Icon(Icons.add_rounded, size: 40, color: Color(0xFF222222)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              // ---- bawah (kuning) ----
              Container(
                width: double.infinity,
                color: C.yellow,
                child: SafeArea(
                  top: false,
                  child: (ready || state.history.isNotEmpty)
                      ? Row(
                          children: [
                            if (ready)
                              Expanded(
                                child: _barButton(Icons.description_outlined, 'Laporan',
                                    () => Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => ReportPage(state: state)))),
                              ),
                            Expanded(
                              child: _barButton(Icons.history_rounded, 'Riwayat',
                                  () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => HistoryPage(state: state)))),
                            ),
                            if (ready)
                              Expanded(
                                child: _barButton(Icons.restart_alt_rounded, 'Baru',
                                    () => _confirmReset(context)),
                              ),
                          ],
                        )
                      : const SizedBox(height: 28),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =====================================================================
// PENGATURAN CATATAN (modal -> produk)
// =====================================================================

class SetupPage extends StatefulWidget {
  final AppState state;
  const SetupPage({super.key, required this.state});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  int step = 0;
  final modalC = TextEditingController();
  final nameC = TextEditingController();
  final priceC = TextEditingController();
  final List<Product> items = [];

  int get modal => parseMoney(modalC.text);
  int get price => parseMoney(priceC.text);
  bool get draftReady => nameC.text.trim().isNotEmpty && price > 0;

  @override
  void dispose() {
    modalC.dispose();
    nameC.dispose();
    priceC.dispose();
    super.dispose();
  }

  void _addItem() {
    if (!draftReady) return;
    setState(() {
      items.add(Product(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: nameC.text.trim(),
        price: price,
      ));
      nameC.clear();
      priceC.clear();
    });
  }

  Future<void> _save() async {
    if (draftReady) _addItem();
    if (items.isEmpty || modal <= 0) return;
    await widget.state.setup(modal, items);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = items.isNotEmpty || draftReady;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.yellow,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => step == 1 ? setState(() => step = 0) : Navigator.pop(context),
        ),
        title: Text('Langkah ${step + 1} dari 2', style: display(19)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: step == 0 ? _modalStep() : _productStep(),
        ),
      ),
    );
  }

  List<Widget> _modalStep() => [
        Text('Modal usaha', style: display(30)),
        const SizedBox(height: 8),
        const Text('Berapa uang yang kamu keluarkan untuk memulai dagang?',
            style: TextStyle(fontSize: 16, height: 1.4)),
        const SizedBox(height: 24),
        MoneyField(
            controller: modalC, label: 'Modal', autofocus: true, onChanged: (_) => setState(() {})),
        const SizedBox(height: 24),
        ChunkButton(
          label: 'Lanjut',
          icon: Icons.arrow_forward_rounded,
          onTap: modal > 0 ? () => setState(() => step = 1) : null,
        ),
      ];

  List<Widget> _productStep() => [
        Text('Produk dagang', style: display(30)),
        const SizedBox(height: 8),
        Text('Modal kamu ${rp(modal)}. Masukkan nama dan harga jual per produk.',
            style: const TextStyle(fontSize: 16, height: 1.4)),
        const SizedBox(height: 20),
        TextField(
          controller: nameC,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Nama produk'),
        ),
        const SizedBox(height: 12),
        MoneyField(controller: priceC, label: 'Harga jual', onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        if (price > 0) PriceEstimate(modal: modal, price: price),
        const SizedBox(height: 14),
        ChunkButton(
          label: 'Tambah produk',
          icon: Icons.add_rounded,
          onTap: draftReady ? _addItem : null,
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Produk (${items.length})', style: display(20)),
          const SizedBox(height: 8),
          for (final p in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.ink.withOpacity(0.15), width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(rp(p.price), style: const TextStyle(color: C.mute)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus ${p.name}',
                    onPressed: () => setState(() => items.remove(p)),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        ChunkButton(label: 'Simpan catatan', dark: true, onTap: canSave ? _save : null),
      ];
}

/// Estimasi rugi / untung dari harga yang sedang diketik.
class PriceEstimate extends StatefulWidget {
  final int modal;
  final int price;
  const PriceEstimate({super.key, required this.modal, required this.price});

  @override
  State<PriceEstimate> createState() => _PriceEstimateState();
}

class _PriceEstimateState extends State<PriceEstimate> {
  double units = 10;

  @override
  Widget build(BuildContext context) {
    final be = (widget.modal / widget.price).ceil();
    final maxUnits = (be * 2 < 10 ? 10 : be * 2).toDouble();
    final n = units.clamp(0, maxUnits).round();
    final result = n * widget.price - widget.modal;
    final Color rc = result < 0 ? C.red : (result == 0 ? C.ink : C.greenText);
    final String rt = result < 0
        ? 'Rugi ${rp(-result)}'
        : (result == 0 ? 'Balik modal' : 'Untung ${rp(result)}');

    final String advice = be > 100
        ? 'Perlu $be unit untuk balik modal. Pertimbangkan harga lebih tinggi.'
        : (be <= 3
            ? 'Hanya $be unit untuk balik modal. Pastikan harga ini masih wajar bagi pembeli.'
            : 'Setiap unit setelah itu menambah ${rp(widget.price)} untung.');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.yellow.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Balik modal di', style: display(15))),
              Text('$be unit', style: display(24)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Belum ada yang terjual: rugi ${rp(widget.modal)}',
              style: const TextStyle(color: C.red, fontWeight: FontWeight.w600)),
          const Divider(height: 24, color: Colors.black26),
          Text('Jika terjual $n unit', style: display(15)),
          Slider(
            value: n.toDouble(),
            min: 0,
            max: maxUnits,
            onChanged: (v) => setState(() => units = v),
          ),
          Text(rt, style: display(26, color: rc)),
          Text('Pendapatan ${rp(n * widget.price)}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(advice, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}

// =====================================================================
// CATAT PENJUALAN HARIAN
// =====================================================================

class SalesPage extends StatefulWidget {
  final AppState state;
  final DateTime date;
  const SalesPage({super.key, required this.state, required this.date});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late final Map<String, int> qty = {...?widget.state.sales[dateKey(widget.date)]};

  int get units => qty.values.fold(0, (a, b) => a + b);
  int get total {
    var t = 0;
    for (final p in widget.state.products) {
      t += (qty[p.id] ?? 0) * p.price;
    }
    return t;
  }

  int get dayNumber {
    final keys = widget.state.dayKeys;
    var start = widget.date;
    if (keys.isNotEmpty) {
      final first = parseKey(keys.first);
      if (first.isBefore(start)) start = first;
    }
    return widget.date.difference(start).inDays + 1;
  }

  void _change(String id, int by) {
    setState(() {
      final v = ((qty[id] ?? 0) + by).clamp(0, 99999);
      qty[id] = v;
    });
  }

  Future<void> _done() async {
    await widget.state.saveDay(dateKey(widget.date), qty);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.yellow,
        surfaceTintColor: Colors.transparent,
        title: Text('Hari ke-$dayNumber', style: display(20)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(fmtLong(widget.date), style: display(22)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                for (final p in widget.state.products) _tile(p),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: C.cream,
              border: Border(top: BorderSide(color: C.ink, width: 2)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('$units unit terjual', style: const TextStyle(fontSize: 16))),
                        Text(rp(total), style: display(24)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ChunkButton(label: 'Selesai', icon: Icons.check_rounded, onTap: _done),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Product p) {
    final q = qty[p.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: q > 0 ? C.yellow.withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: q > 0 ? C.ink : C.ink.withOpacity(0.15), width: q > 0 ? 2 : 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 2),
                Text(rp(p.price), style: const TextStyle(color: C.mute)),
              ],
            ),
          ),
          _roundBtn(Icons.remove_rounded, q > 0 ? () => _change(p.id, -1) : null, 'Kurangi ${p.name}'),
          SizedBox(
            width: 52,
            child: Center(child: Text('$q', style: display(26))),
          ),
          _roundBtn(Icons.add_rounded, () => _change(p.id, 1), 'Tambah ${p.name}'),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback? onTap, String tip) => Opacity(
        opacity: onTap == null ? 0.3 : 1,
        child: Material(
          color: C.yellow,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Tooltip(
              message: tip,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: C.ink, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28),
              ),
            ),
          ),
        ),
      );
}

// =====================================================================
// LAPORAN
// =====================================================================

class ReportPage extends StatelessWidget {
  final NoteData state;
  const ReportPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final keys = state.dayKeys;
    final period = periodText(state);

    Widget row(String l, String r, {Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(l, style: const TextStyle(fontSize: 15))),
              Text(r,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: color)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.yellow,
        surfaceTintColor: Colors.transparent,
        title: Text('Laporan', style: display(20)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(period, style: const TextStyle(color: C.mute, fontSize: 15)),
            const SizedBox(height: 6),
            Text(standingText(state), style: display(34, color: standingColor(state.standing))),
            const SizedBox(height: 18),
            TargetBar(revenue: state.revenue, modal: state.modal),
            const SizedBox(height: 22),
            row('Modal usaha', rp(state.modal)),
            row('Pendapatan', rp(state.revenue)),
            row('Unit terjual', '${state.totalUnits}'),
            row('Hasil', signedRp(state.result),
                color: standingColor(state.standing), bold: true),
            const SizedBox(height: 22),
            Text('Per produk', style: display(20)),
            const SizedBox(height: 6),
            for (final p in state.products)
              row('${p.name}  (${state.productUnits(p.id)} x ${rp(p.price)})',
                  rp(state.productUnits(p.id) * p.price)),
            const SizedBox(height: 22),
            Text('Per hari', style: display(20)),
            const SizedBox(height: 6),
            if (keys.isEmpty)
              const Text('Belum ada data.', style: TextStyle(color: C.mute))
            else
              for (var i = 0; i < keys.length; i++)
                row('Hari ke-${parseKey(keys[i]).difference(parseKey(keys.first)).inDays + 1}  -  ${fmtDate(parseKey(keys[i]))}',
                    rp(state.dayRevenue(keys[i]))),
            const SizedBox(height: 28),
            ChunkButton(
              label: 'Cetak PDF',
              icon: Icons.picture_as_pdf_rounded,
              dark: true,
              onTap: () => Printing.layoutPdf(
                name: 'Laporan-ModalKu.pdf',
                onLayout: (_) => buildReportPdf(state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// RIWAYAT
// =====================================================================

class HistoryPage extends StatelessWidget {
  final AppState state;
  const HistoryPage({super.key, required this.state});

  Future<void> _delete(BuildContext context, ArchivedNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.cream,
        title: Text('Hapus dari Riwayat?', style: display(20)),
        content: Text('Catatan ${periodText(n)} akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: C.ink))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: C.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) await state.deleteHistory(n.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: C.yellow,
          surfaceTintColor: Colors.transparent,
          title: Text('Riwayat penjualan', style: display(20)),
        ),
        body: state.history.isEmpty
            ? const Center(
                child: Text('Belum ada riwayat.\nCatatan lama muncul di sini setelah kamu memulai catatan baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: C.mute, fontStyle: FontStyle.italic, height: 1.5)),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final n in state.history)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: standingColor(n.standing), width: 2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => ReportPage(state: n))),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(periodText(n), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(standingText(n),
                                        style: display(22, color: standingColor(n.standing))),
                                    const SizedBox(height: 4),
                                    Text(
                                        'Modal ${rp(n.modal)}  |  ${n.dayKeys.length} hari  |  ${n.totalUnits} unit',
                                        style: const TextStyle(color: C.mute, fontSize: 13)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hapus',
                                onPressed: () => _delete(context, n),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
