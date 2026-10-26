import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../widgets/ui.dart';

/// The visual receipt (used both on-screen and as the printed PDF source).
class ReceiptDocument extends StatelessWidget {
  const ReceiptDocument({super.key, required this.receipt, this.width = 430});

  final Receipt receipt;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isCard = receipt.method == 'card';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: width,
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF111113), Color(0xFF2E2907)],
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بخدمتك',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'منصة الخدمات المنزلية',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white60,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'وصل دفع خدمة',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        receipt.invoiceNo,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.gold,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Meta(label: 'التاريخ', value: fmtDate(receipt.createdAt)),
                      _Meta(label: 'الوقت', value: fmtTimeOfDay(receipt.createdAt)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Meta(label: 'الزبون', value: receipt.customerName ?? 'زبون'),
                      _Meta(label: 'الهاتف', value: receipt.customerPhone ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFECECE3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF7F7F1),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text('البيان',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF5F5F66))),
                              ),
                              Text('المبلغ',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF5F5F66))),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          receipt.serviceTitle ?? receipt.title,
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w800),
                                        ),
                                        if (receipt.workerName != null)
                                          Text('الفني: ${receipt.workerName}',
                                              style: const TextStyle(
                                                  fontSize: 9.5, color: Color(0xFF5F5F66))),
                                        if (receipt.bookingId != null)
                                          Text('رقم الحجز: #${receipt.bookingId}',
                                              style: const TextStyle(
                                                  fontSize: 9.5, color: Color(0xFF5F5F66))),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    fmtMoney(receipt.amount),
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('الإجمالي المدفوع',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text(
                          fmtMoney(receipt.amount),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isCard ? Icons.credit_card_rounded : Icons.payments_outlined,
                        size: 15,
                        color: const Color(0xFF5F5F66),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCard
                            ? '${receipt.cardBrand ?? 'Card'} •••• ${receipt.last4 ?? ''}'
                            : 'الدفع نقداً عند الوصول',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF5F5F66)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: (receipt.paid ? AppColors.success : AppColors.danger)
                              .withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: (receipt.paid ? AppColors.success : AppColors.danger)
                                .withValues(alpha: .3),
                          ),
                        ),
                        child: Text(
                          receipt.paid ? 'مدفوع' : 'غير مدفوع',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: receipt.paid ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFECECE3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: QrImageView(
                          data:
                              '${receipt.invoiceNo}|${receipt.amount.round()}|${fmtDateShort(receipt.createdAt)}|BKHIDMATK',
                          size: 56,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'امسح الرمز للتحقق من صحة الوصل.\nهذا الوصل صادر إلكترونياً من تطبيق بخدمتك.',
                          style: TextStyle(fontSize: 8.5, height: 1.7, color: Color(0xFF5F5F66)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: const Color(0xFFECECE3)),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.support_agent_rounded, size: 12, color: Color(0xFF5F5F66)),
                      SizedBox(width: 4),
                      Text('الدعم: 0770 000 0000 · بخدمتك تسعد بخدمتك',
                          style: TextStyle(fontSize: 8.5, color: Color(0xFF5F5F66))),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 8.5, color: Color(0xFF8A8A92), fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class ReceiptActions {
  static final ScreenshotController _controller = ScreenshotController();

  static Future<Uint8List?> _renderPng(Receipt receipt) async {
    try {
      final image = await _controller.captureFromWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(430, 900), devicePixelRatio: 3),
          child: Theme(
            data: AppTheme.light(),
            child: Material(
              color: Colors.white,
              child: RepaintBoundary(child: ReceiptDocument(receipt: receipt)),
            ),
          ),
        ),
        pixelRatio: 3,
        delay: const Duration(milliseconds: 200),
        context: null,
        targetSize: const Size(430, 780),
      );
      return image;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> buildPdf(Receipt receipt) async {
    final png = await _renderPng(receipt);
    if (png == null) return null;
    final doc = pw.Document(
      title: receipt.invoiceNo,
      author: 'بخدمتك',
      creator: 'Bkhidmatk',
    );
    final image = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(12),
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    return doc.save();
  }

  static Future<bool> print(BuildContext context, Receipt receipt) async {
    final bytes = await buildPdf(receipt);
    if (bytes == null) {
      if (context.mounted) {
        AppSnack.show(context, 'تعذر إنشاء الوصل، حاول مرة أخرى', error: true);
      }
      return false;
    }
    await Printing.layoutPdf(
      name: receipt.invoiceNo,
      onLayout: (format) async => bytes,
    );
    return true;
  }

  static Future<void> share(BuildContext context, Receipt receipt) async {
    final bytes = await buildPdf(receipt);
    if (bytes == null) {
      if (context.mounted) {
        AppSnack.show(context, 'تعذر إنشاء الوصل، حاول مرة أخرى', error: true);
      }
      return;
    }
    await Printing.sharePdf(bytes: bytes, filename: '${receipt.invoiceNo}.pdf');
  }

  static Future<ui.Image?> debugRender(Receipt receipt) async {
    final png = await _renderPng(receipt);
    if (png == null) return null;
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class ReceiptPreviewScreen extends StatelessWidget {
  const ReceiptPreviewScreen({super.key, required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة الوصل'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => ReceiptActions.share(context, receipt),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ReceiptDocument(receipt: receipt),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline)),
          ),
          child: PrimaryButton(
            label: 'طباعة الوصل',
            icon: Icons.print_rounded,
            onPressed: () => ReceiptActions.print(context, receipt),
          ),
        ),
      ),
    );
  }
}
