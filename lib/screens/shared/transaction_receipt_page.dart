import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/payment_methods.dart';
import '../user/user_theme.dart';
import '../user/user_widgets.dart';

class TransactionReceiptPage extends StatelessWidget {
  const TransactionReceiptPage({
    super.key,
    required this.receipt,
  });

  final Map<String, dynamic> receipt;

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final items = receipt['items'] as List<dynamic>? ?? [];
  final total = (receipt['totalAmount'] as num?)?.toDouble() ?? 0;

    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BUKTI TRANSAKSI',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Sentra Ruang / KosFinder'),
            pw.Divider(),
            pw.Text('Kode: ${receipt['orderCode']}'),
            pw.Text('Tanggal: ${receipt['createdAt']}'),
            pw.Text('Merchant: ${receipt['merchantName']}'),
            pw.Text('Pelanggan: ${receipt['customerName']}'),
            pw.SizedBox(height: 12),
            pw.Text('Item:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...items.map((item) {
              final m = item as Map<String, dynamic>;
              return pw.Text(
                '- ${m['name']} x${m['quantity']} @ ${m['price']}',
              );
            }),
            pw.Divider(),
            pw.Text(
              'Total: Rp ${total.toStringAsFixed(0)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Bayar: ${PaymentMethodHelper.getDisplayName(receipt['paymentMethod'] as String?)}',
            ),
            pw.Text('Status: ${receipt['paymentStatus']}'),
          ],
        ),
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final items = receipt['items'] as List<dynamic>? ?? [];
    final total = (receipt['totalAmount'] as num?)?.toDouble() ?? 0;

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
            tooltip: 'Unduh PDF',
            onPressed: () async {
              final bytes = await _buildPdf();
              await Printing.sharePdf(
                bytes: bytes,
                filename: 'struk_${receipt['orderCode']}.pdf',
              );
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Bagikan',
            onPressed: () async {
              final bytes = await _buildPdf();
              await Printing.layoutPdf(onLayout: (_) async => bytes);
            },
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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [UserTheme.softShadow(opacity: 0.05)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BUKTI PEMBAYARAN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: UserTheme.primaryDark,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                _line('Kode Pesanan', '${receipt['orderCode']}'),
                _line('Waktu', '${receipt['createdAt']}'),
                _line('Merchant', '${receipt['merchantName']}'),
                _line('Pelanggan', '${receipt['customerName']}'),
                const Divider(height: 28),
                ...items.map((raw) {
                  final item = raw as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item['name']} x${item['quantity']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(formatUserCurrency(
                            (item['subtotal'] as num?)?.toDouble() ??
                                (item['price'] as num?)?.toDouble() ??
                                0)),
                      ],
                    ),
                  );
                }),
                const Divider(height: 28),
                _line(
                  'Total',
                  formatUserCurrency(total),
                  bold: true,
                ),
                _line(
                  'Metode',
                  PaymentMethodHelper.getDisplayName(
                    receipt['paymentMethod'] as String?,
                  ),
                ),
                _line('Status', '${receipt['paymentStatus']}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final bytes = await _buildPdf();
              await Share.shareXFiles(
                [
                  XFile.fromData(
                    bytes,
                    name: 'struk_${receipt['orderCode']}.pdf',
                    mimeType: 'application/pdf',
                  ),
                ],
                text: 'Struk ${receipt['orderCode']}',
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: UserTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Unduh / Bagikan PDF'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: UserTheme.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                color: UserTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
