import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_exception.dart';
import '../../data/member_repository.dart';
import '../../models/customer.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';

/// Thu ngân xác định khách thành viên: quét QR trên app của khách bằng camera,
/// hoặc nhập mã thẻ bằng tay (khi camera không dùng được).
///
/// Tìm thấy khách thì đóng màn hình và trả [Customer] về cho màn Thanh toán
/// qua `Navigator.pop(customer)`.
class ScanMemberScreen extends StatefulWidget {
  const ScanMemberScreen({super.key});

  @override
  State<ScanMemberScreen> createState() => _ScanMemberScreenState();
}

class _ScanMemberScreenState extends State<ScanMemberScreen> {
  /// mobile_scanner chỉ hỗ trợ Android, iOS, macOS và web. Bản Windows/Linux
  /// desktop không có camera quét nên chỉ hiện ô nhập mã tay.
  static bool get _cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  final MobileScannerController? _scanner = _cameraSupported
      ? MobileScannerController(
          // Một mã chỉ báo một lần, tránh xử lý lặp khi camera còn nhìn thấy mã.
          detectionSpeed: DetectionSpeed.noDuplicates,
          formats: const [BarcodeFormat.qrCode],
        )
      : null;

  final _codeController = TextEditingController();
  String? _error;

  /// Đang gọi API → bật indicator, khóa nút tìm.
  bool _looking = false;

  /// Đã tìm thấy khách và đang đóng màn hình: bỏ qua các lần quét tiếp theo.
  bool _done = false;

  @override
  void dispose() {
    _scanner?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _lookup(value);
        return;
      }
    }
  }

  Future<void> _lookup(String raw) async {
    if (_done || _looking) return;
    final code = raw.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã thành viên');
      return;
    }

    setState(() {
      _looking = true;
      _error = null;
    });

    try {
      final customer = await MemberRepository.instance.lookupByCode(code);
      if (!mounted) return;
      _done = true;
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(customer);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tìm thấy thành viên có mã "$code"');
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          const AppHeaderBand(
            title: 'Quét thẻ thành viên',
            subtitle: 'Quét QR trên app của khách hoặc nhập mã thẻ',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                FadeSlideIn(child: _scanner != null ? _buildCamera(_scanner) : _buildNoCamera()),
                const SizedBox(height: 22),
                Text('Hoặc nhập mã thành viên',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.search,
                        enabled: !_looking,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: _lookup,
                        decoration: const InputDecoration(
                          hintText: 'Mã trên thẻ, vd DF-000123',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 88,
                      child: AppButton(
                        label: 'Tìm',
                        isLoading: _looking,
                        onPressed: () => _lookup(_codeController.text),
                      ),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: AppMotion.fast,
                  child: _error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(_error),
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Khung camera vuông, bo góc, có khung ngắm trắng ở giữa.
  Widget _buildCamera(MobileScannerController scanner) {
    return Center(
      child: ConstrainedBox(
        // Màn rộng (tablet/desktop) không để khung camera to quá.
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: AppPalette.dark.background),
                MobileScanner(controller: scanner, onDetect: _onDetect),
                // Overlay loading khi đang tra API sau khi quét
                if (_looking)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    ),
                  ),
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    heightFactor: 0.62,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Text(
                    'Đưa mã QR thành viên vào trong khung',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thiết bị không quét được (vd bản Windows desktop): hướng dẫn nhập tay.
  Widget _buildNoCamera() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Icon(Icons.no_photography_outlined, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Thiết bị này không hỗ trợ quét bằng camera. Vui lòng nhập mã in trên thẻ thành viên của khách.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
