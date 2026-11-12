import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/routes.dart';
import '../../models/invoice.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/dashed_divider.dart';

/// Hóa đơn thanh toán dạng tờ hoá đơn. Dùng lại cho cả hóa đơn vừa tạo và xem
/// lại hóa đơn trong Lịch sử.
///
/// Nút "In hóa đơn": gọi [Printing.layoutPdf] → mở hộp thoại in hệ thống.
/// Nút "Chia sẻ":    gọi [Printing.sharePdf] → mở share sheet hệ thống để
///                   chia sẻ file PDF qua email, Zalo, v.v.
///
/// Cả hai đều dùng package `pdf` (tạo PDF thuần Dart) và `printing`
/// (cầu nối giữa PDF thuần Dart với máy in / share sheet của iOS / Android).
class InvoiceScreen extends StatelessWidget {
  final Invoice invoice;
  const InvoiceScreen({super.key, required this.invoice});

  /// Tạo dữ liệu PDF từ hoá đơn. Hàm này trả về [Uint8List] — chuỗi byte
  /// của file .pdf — mà cả `Printing.layoutPdf` và `Printing.sharePdf` đều cần.
  Future<Uint8List> _buildPdfBytes() async {
    final doc = pw.Document(
      title: 'Hóa đơn DineFlow #${invoice.displayCode}',
      author: 'DineFlow',
    );

    // Tải font hệ thống hỗ trợ tiếng Việt (Google Fonts Noto Sans).
    // `PdfGoogleFonts` là helper của package `printing` — tải font trực tiếp
    // từ Google Fonts API, không cần nhúng file .ttf vào assets.
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    doc.addPage(
      pw.Page(
        // Khổ giấy hóa đơn nhiệt 80mm × dài tùy nội dung.
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 8 * PdfPageFormat.mm),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // ── Logo & tên nhà hàng ────────────────────────────────────────
            pw.Text(
              'DineFlow',
              style: pw.TextStyle(font: fontBold, fontSize: 18),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Nhà hàng & Quán cafe',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.SizedBox(height: 10),
            _pdfDivider(),
            pw.SizedBox(height: 6),

            // ── Thông tin hoá đơn ──────────────────────────────────────────
            _pdfRow('Mã hóa đơn', '#${invoice.displayCode}', font: font, fontBold: fontBold, bold: true),
            _pdfRow('Ngày giờ', AppFormatters.dateTime(invoice.createdAt), font: font, fontBold: fontBold),
            _pdfRow('Bàn', invoice.tableNumber ?? 'Đặt qua app', font: font, fontBold: fontBold),
            _pdfRow('Thu ngân', invoice.cashierName, font: font, fontBold: fontBold),
            pw.SizedBox(height: 6),
            _pdfDivider(),
            pw.SizedBox(height: 6),

            // ── Danh sách món ──────────────────────────────────────────────
            for (final item in invoice.items)
              _pdfRow(
                '${item.foodName} ×${item.quantity}',
                AppFormatters.currency(item.total),
                font: font,
                fontBold: fontBold,
              ),
            pw.SizedBox(height: 6),
            _pdfDivider(),
            pw.SizedBox(height: 6),

            // ── Tổng tiền ──────────────────────────────────────────────────
            _pdfRow('Tạm tính', AppFormatters.currency(invoice.subtotal), font: font, fontBold: fontBold),
            _pdfRow('Giảm giá', '-${AppFormatters.currency(invoice.discount)}',
                font: font, fontBold: fontBold),
            if (invoice.hasDeposit)
              _pdfRow('Đã cọc (đặt bàn)', '-${AppFormatters.currency(invoice.depositAmount)}',
                  font: font, fontBold: fontBold),
            _pdfRow('Phương thức', invoice.paymentMethod.label, font: font, fontBold: fontBold),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Thành tiền',
                    style: pw.TextStyle(font: fontBold, fontSize: 13)),
                pw.Text(
                  AppFormatters.currency(invoice.total),
                  style: pw.TextStyle(font: fontBold, fontSize: 15),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            _pdfDivider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Cảm ơn quý khách!\nHẹn gặp lại tại DineFlow.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── Helpers PDF ──────────────────────────────────────────────────────────────

  static pw.Widget _pdfDivider() => pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey400);

  static pw.Widget _pdfRow(
    String label,
    String value, {
    required pw.Font font,
    required pw.Font fontBold,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(font: bold ? fontBold : font, fontSize: 11)),
          ),
          pw.SizedBox(width: 8),
          pw.Text(value,
              style: pw.TextStyle(font: bold ? fontBold : font, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Hành động in / chia sẻ ──────────────────────────────────────────────────

  Future<void> _print(BuildContext context) async {
    try {
      // Printing.layoutPdf mở hộp thoại in hệ thống (AirPrint / máy in Android).
      // onLayout() được gọi với PdfPageFormat phù hợp với máy in đã chọn,
      // nhưng ta vẫn dùng khổ nhiệt 80mm.
      await Printing.layoutPdf(
        onLayout: (_) => _buildPdfBytes(),
        name: 'DineFlow_${invoice.displayCode}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Không thể in: $e')));
      }
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final bytes = await _buildPdfBytes();
      // Printing.sharePdf lưu PDF vào thư mục tạm và mở share sheet hệ thống.
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'DineFlow_${invoice.displayCode}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Không thể chia sẻ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(
            title: 'Hóa đơn',
            subtitle: 'Đã thanh toán · đơn #${invoice.displayOrderCode}',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                FadeSlideIn(child: _Receipt(invoice: invoice)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'In hóa đơn',
                          icon: Icons.print_outlined,
                          variant: AppButtonVariant.outlined,
                          dense: true,
                          onPressed: () => _print(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Chia sẻ',
                          icon: Icons.ios_share_rounded,
                          variant: AppButtonVariant.outlined,
                          dense: true,
                          onPressed: () => _share(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'Hoàn tất',
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.cashierDashboard, (route) => false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tờ hoá đơn: logo, thông tin hoá đơn, danh sách món, tổng tiền; các phần
/// ngăn bằng đường kẻ đứt.
class _Receipt extends StatelessWidget {
  final Invoice invoice;

  const _Receipt({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.restaurant_rounded, color: AppColors.textOnPrimary, size: 24),
          ),
          const SizedBox(height: 10),
          Text('DineFlow',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('Nhà hàng & Quán cafe', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          const DashedDivider(),
          const SizedBox(height: 12),
          _ReceiptRow(label: 'Mã hóa đơn', value: '#${invoice.displayCode}', bold: true),
          _ReceiptRow(label: 'Ngày giờ', value: AppFormatters.dateTime(invoice.createdAt)),
          _ReceiptRow(label: 'Bàn', value: invoice.tableNumber ?? 'Đặt qua app'),
          _ReceiptRow(label: 'Thu ngân', value: invoice.cashierName),
          const SizedBox(height: 10),
          const DashedDivider(),
          const SizedBox(height: 10),
          for (final item in invoice.items)
            _ReceiptRow(
                label: '${item.foodName} ×${item.quantity}', value: AppFormatters.currency(item.total)),
          const SizedBox(height: 10),
          const DashedDivider(),
          const SizedBox(height: 10),
          _ReceiptRow(label: 'Tạm tính', value: AppFormatters.currency(invoice.subtotal)),
          _ReceiptRow(label: 'Giảm giá', value: '-${AppFormatters.currency(invoice.discount)}'),
          if (invoice.hasDeposit)
            _ReceiptRow(
              label: 'Đã cọc (đặt bàn)',
              value: '-${AppFormatters.currency(invoice.depositAmount)}',
            ),
          _ReceiptRow(label: 'Phương thức', value: invoice.paymentMethod.label),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Thành tiền',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(AppFormatters.currency(invoice.total),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        )),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const DashedDivider(),
          const SizedBox(height: 12),
          Text(
            'Cảm ơn quý khách!\nHẹn gặp lại tại DineFlow.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// Một dòng nhãn - giá trị trên tờ hoá đơn.
class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _ReceiptRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.3)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.topRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
