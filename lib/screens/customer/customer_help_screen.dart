import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';

/// Màn hình Trợ giúp & hỗ trợ:
/// - Câu hỏi thường gặp (FAQ accordion)
/// - Gửi phản hồi (loại + nội dung → xác nhận)
class CustomerHelpScreen extends StatefulWidget {
  const CustomerHelpScreen({super.key});

  @override
  State<CustomerHelpScreen> createState() => _CustomerHelpScreenState();
}

class _CustomerHelpScreenState extends State<CustomerHelpScreen> {
  final _feedbackController = TextEditingController();
  String _feedbackType = 'Góp ý';
  bool _submitted = false;

  static const _faqs = [
    (
      q: 'Làm thế nào để đặt bàn?',
      a: 'Vào tab "Đặt bàn" ở thanh điều hướng bên dưới. Chọn ngày giờ, số khách, khu vực và bàn phù hợp. Bạn có thể đặt món trước hoặc bỏ qua và gọi món khi đến.',
    ),
    (
      q: 'Tôi có thể hủy đặt bàn không?',
      a: 'Có. Vào "Lịch đặt bàn" → chọn lượt đặt → nhấn Hủy. Chỉ có thể hủy trước giờ hẹn ít nhất 2 tiếng.',
    ),
    (
      // Giữ nội dung khớp với data/loyalty_rules.dart khi đổi quy tắc.
      q: 'Điểm thưởng được tính như thế nào?',
      a: 'Mỗi 10.000đ thanh toán bạn nhận 2 điểm. Điểm dùng để xét hạng thành viên: '
          'Bạc, Vàng (từ 500 điểm, giảm 5% mỗi hoá đơn), Kim cương (từ 1.500 điểm, giảm 10%). '
          'Điểm chỉ được cộng, không bị trừ khi bạn được giảm giá. '
          'Ưu đãi hạng không cộng dồn với voucher — áp dụng mức giảm cao hơn.',
    ),
    (
      q: 'QR thành viên dùng để làm gì?',
      a: 'Thu ngân quét mã QR khi thanh toán để áp dụng ưu đãi theo hạng và cộng điểm tự động. Vào tab Tài khoản → QR thành viên để xem mã của bạn.',
    ),
    (
      q: 'Đơn đặt trước thanh toán bằng cách nào?',
      a: 'Khi đặt bàn kèm món trước, bạn thanh toán tiền cọc qua QR hoặc tiền mặt. Phần còn lại thanh toán khi đến nhà hàng.',
    ),
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập nội dung phản hồi'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    var idx = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: idx++, child: child);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            step(const AppPageHeader(title: 'Trợ giúp & hỗ trợ')),
            const SizedBox(height: 22),

            // --- FAQ ---
            step(_GroupLabel('Câu hỏi thường gặp')),
            const SizedBox(height: 10),
            step(Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _faqs.length; i++)
                    _FaqTile(
                      question: _faqs[i].q,
                      answer: _faqs[i].a,
                      isFirst: i == 0,
                      isLast: i == _faqs.length - 1,
                    ),
                ],
              ),
            )),

            const SizedBox(height: 28),

            // --- Hotline ---
            step(_GroupLabel('Liên hệ trực tiếp')),
            const SizedBox(height: 10),
            step(Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hotline DineFlow',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('1800 1234 · Miễn phí · 8:00 – 22:00',
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            )),

            const SizedBox(height: 28),

            // --- Gửi phản hồi ---
            step(_GroupLabel('Gửi phản hồi')),
            const SizedBox(height: 10),
            step(_submitted ? _buildSuccessState() : _buildFeedbackForm()),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loại phản hồi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['Góp ý', 'Báo lỗi', 'Khen ngợi'].map((type) {
              final selected = _feedbackType == type;
              return GestureDetector(
                onTap: () => setState(() => _feedbackType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: selected ? AppColors.ink : AppColors.border),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primaryOnInk : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Nội dung',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackController,
            maxLines: 4,
            maxLength: 500,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Chia sẻ trải nghiệm của bạn với chúng tôi...',
              hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
              counterStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 14),
          PressScale(
            onTap: _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  'Gửi phản hồi',
                  style: TextStyle(
                    color: AppColors.primaryOnInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Cảm ơn phản hồi của bạn!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Chúng tôi sẽ xem xét và phản hồi\ntrong thời gian sớm nhất.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          PressScale(
            onTap: () => setState(() {
              _submitted = false;
              _feedbackController.clear();
              _feedbackType = 'Góp ý';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Gửi thêm phản hồi',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FAQ accordion ─────────────────────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  final bool isFirst;
  final bool isLast;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.isFirst,
    required this.isLast,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: widget.isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: widget.isLast && !_expanded ? const Radius.circular(20) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child:
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 22),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              widget.answer,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.55),
            ),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (!widget.isLast) Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
      ],
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
