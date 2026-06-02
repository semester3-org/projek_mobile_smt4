import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/payment_methods.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';

class TransactionReceiptPage extends StatelessWidget {
  const TransactionReceiptPage({
    super.key,
    required this.receipt,
  });

  final Map<String, dynamic> receipt;

  List<Map<String, dynamic>> get _items {
    return (receipt['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String get _orderCode => _text('orderCode', fallback: 'Pesanan');
  String get _fileName => 'struk_${_orderCode.replaceAll('#', '')}.pdf';
  double get _total => (receipt['totalAmount'] as num?)?.toDouble() ?? 0;

  String _text(String key, {String fallback = '-'}) {
    final value = receipt[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final items = _items;
    final paymentMethod = PaymentMethodHelper.getDisplayName(
      receipt['paymentMethod'] as String?,
    );

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#0B66B7'),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BUKTI PEMBAYARAN',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _orderCode,
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _pdfInfoGrid([
            ('Waktu', _text('createdAt')),
            ('Merchant', _text('merchantName')),
            ('Pelanggan', _text('customerName')),
            ('Metode', paymentMethod),
          ]),
          pw.SizedBox(height: 18),
          pw.Text(
            'Rincian Pembayaran',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D7DEE8')),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration:
                    pw.BoxDecoration(color: PdfColor.fromHex('#F1F6FC')),
                children: [
                  _pdfTableCell('Item', bold: true),
                  _pdfTableCell('Qty', bold: true),
                  _pdfTableCell('Subtotal', bold: true, alignRight: true),
                ],
              ),
              ...items.map((item) {
                final subtotal = (item['subtotal'] as num?)?.toDouble() ??
                    (item['price'] as num?)?.toDouble() ??
                    0;
                return pw.TableRow(
                  children: [
                    _pdfTableCell(item['name']?.toString() ?? 'Item'),
                    _pdfTableCell('${item['quantity'] ?? 1}'),
                    _pdfTableCell(
                      formatUserCurrency(subtotal),
                      alignRight: true,
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F7FAFC'),
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromHex('#D7DEE8')),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Total Pembayaran',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text(
                  formatUserCurrency(_total),
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#0B66B7'),
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_text('deliveryAddress', fallback: '').isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Alamat Pengiriman',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(_text('deliveryAddress')),
          ],
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfInfoGrid(List<(String, String)> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#D7DEE8')),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        children: rows
            .map(
              (row) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 86,
                      child: pw.Text(
                        row.$1,
                        style: const pw.TextStyle(color: PdfColors.grey700),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        row.$2,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  pw.Widget _pdfTableCell(
    String value, {
    bool bold = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        value,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: _fileName);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyiapkan PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final paymentMethod = PaymentMethodHelper.getDisplayName(
      receipt['paymentMethod'] as String?,
    );

    return Scaffold(
      backgroundColor: UserTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Struk Transaksi',
          style: TextStyle(
            color: UserTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Bagikan PDF',
            onPressed: () => _sharePdf(context),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [UserTheme.softShadow(opacity: 0.06)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'BUKTI PEMBAYARAN',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: UserTheme.primaryDark,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7EF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'LUNAS',
                        style: TextStyle(
                          color: Color(0xFF167246),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _line('Kode Pesanan', _orderCode),
                _line('Waktu', _text('createdAt')),
                _line('Merchant', _text('merchantName')),
                _line('Pelanggan', _text('customerName')),
                const Divider(height: 30),
                const Text(
                  'Rincian Pembayaran',
                  style: TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...items.map(_itemLine),
                const Divider(height: 30),
                _line('Metode', paymentMethod),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total Pembayaran',
                        style: TextStyle(
                          color: UserTheme.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      formatUserCurrency(_total),
                      style: const TextStyle(
                        color: UserTheme.primaryDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _sharePdf(context),
            style: FilledButton.styleFrom(
              backgroundColor: UserTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Unduh / Bagikan PDF'),
          ),
        ],
      ),
    );
  }

  Widget _itemLine(Map<String, dynamic> item) {
    final subtotal = (item['subtotal'] as num?)?.toDouble() ??
        (item['price'] as num?)?.toDouble() ??
        0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? 'Item',
                  style: const TextStyle(
                    color: UserTheme.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['quantity'] ?? 1} x ${formatUserCurrency((item['price'] as num?)?.toDouble() ?? 0)}',
                  style: const TextStyle(
                    color: UserTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatUserCurrency(subtotal),
            style: const TextStyle(
              color: UserTheme.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: const TextStyle(color: UserTheme.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: UserTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
