import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'theme.dart';

// ---------- input uang ----------

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 12) digits = digits.substring(0, 12);
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    final f = group(digits);
    return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}

class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsFormatter()],
      onChanged: onChanged,
      style: display(22),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        prefixStyle: display(22, color: C.mute),
      ),
    );
  }
}

// ---------- tombol ----------

class ChunkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool dark;
  final IconData? icon;
  const ChunkButton({super.key, required this.label, this.onTap, this.dark = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? C.yellow : C.ink;
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: dark ? C.ink : C.yellow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: C.ink, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, color: fg, size: 22), const SizedBox(width: 8)],
                Text(label, style: display(18, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- bar target ----------

Color targetColor(double f) => f <= 0.5
    ? Color.lerp(C.red, C.yellow, f / 0.5)!
    : Color.lerp(C.yellow, C.green, (f - 0.5) / 0.5)!;

/// Kiri = Rugi (merah), tengah = Balik modal (kuning), kanan = Profit (hijau).
/// Titik tengah bar adalah saat pendapatan sama dengan modal.
class TargetBar extends StatelessWidget {
  final int revenue;
  final int modal;
  const TargetBar({super.key, required this.revenue, required this.modal});

  double get frac => modal <= 0 ? 0 : (revenue / (modal * 2)).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final standing = revenue < modal
        ? Standing.rugi
        : (revenue == modal ? Standing.balikModal : Standing.profit);
    final valueColor = switch (standing) {
      Standing.rugi => C.red,
      Standing.balikModal => C.ink,
      Standing.profit => C.greenText,
    };
    TextStyle label(Standing s, Color c) => display(15, color: c).copyWith(
          fontWeight: standing == s ? FontWeight.w700 : FontWeight.w500,
          decoration: standing == s ? TextDecoration.underline : TextDecoration.none,
          decorationThickness: 2,
        );
    return Semantics(
      label: 'Target: ${modal <= 0 ? '-' : '${(revenue * 100 / modal).round()}% dari modal'}',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Rugi', style: label(Standing.rugi, C.red))),
              Text('Balik modal', style: label(Standing.balikModal, C.ink)),
              Expanded(
                child: Text('Profit', textAlign: TextAlign.right,
                    style: label(Standing.profit, C.greenText)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            final inner = c.maxWidth - 4;
            return Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                border: Border.all(color: C.ink, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    width: inner * frac,
                    decoration: BoxDecoration(
                      color: targetColor(frac),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  Center(child: Container(width: 2, color: C.ink.withOpacity(0.55))),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          // Nilai: "-Rp ..." saat rugi (rata kiri), "+Rp ..." saat profit (rata kanan).
          SizedBox(
            width: double.infinity,
            child: Text(
              signedRp(revenue - modal),
              textAlign: standing == Standing.rugi
                  ? TextAlign.left
                  : (standing == Standing.profit ? TextAlign.right : TextAlign.center),
              style: display(24, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- kalender ----------

class CalendarView extends StatefulWidget {
  final AppState state;
  final ValueChanged<DateTime> onPick;
  const CalendarView({super.key, required this.state, required this.onPick});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int by) => setState(() => month = DateTime(month.year, month.month + by));

  Widget _legend(Color fill, Color border, String text) => Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: border, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final offset = DateTime(month.year, month.month, 1).weekday - 1;
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + daysIn) / 7).ceil();
    final standings = widget.state.dayStandings;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Widget cell(int index) {
      final day = index - offset + 1;
      if (day < 1 || day > daysIn) return const Expanded(child: SizedBox());
      final date = DateTime(month.year, month.month, day);
      final st = standings[dateKey(date)];
      final has = st != null;
      final fill = switch (st) {
        Standing.rugi => const Color(0xFFFFD9D4),
        Standing.balikModal => C.yellow,
        Standing.profit => C.green,
        null => Colors.white,
      };
      final textColor = st == Standing.profit ? Colors.white : C.ink;
      final borderColor = switch (st) {
        Standing.rugi => C.red,
        Standing.balikModal => C.ink,
        Standing.profit => C.ink,
        null => C.ink.withOpacity(0.12),
      };
      final isToday = date == today;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AspectRatio(
            aspectRatio: 1,
            child: Semantics(
              button: true,
              label: '${fmtLong(date)}${switch (st) { Standing.rugi => ', rugi', Standing.balikModal => ', balik modal', Standing.profit => ', profit', null => '' }}',
              child: Material(
                color: fill,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onPick(date),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isToday ? C.ink : borderColor,
                        width: isToday ? 3 : (has ? 2 : 1.5),
                      ),
                    ),
                    child: Text('$day', style: display(17, color: textColor)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Bulan sebelumnya',
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded, size: 32),
            ),
            Expanded(
              child: Center(
                child: Text('${monthName(month.month)} ${month.year}', style: display(21)),
              ),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded, size: 32),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
              Expanded(
                child: Center(
                  child: Text(d, style: const TextStyle(color: C.mute, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++) Row(children: [for (var c = 0; c < 7; c++) cell(r * 7 + c)]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(const Color(0xFFFFD9D4), C.red, 'Rugi'),
            const SizedBox(width: 18),
            _legend(C.yellow, C.ink, 'Balik modal'),
            const SizedBox(width: 18),
            _legend(C.green, C.ink, 'Profit'),
          ],
        ),
      ],
    );
  }
}
