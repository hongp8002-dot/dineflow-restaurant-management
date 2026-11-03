import 'package:flutter_test/flutter_test.dart';

import 'package:dineflow/app/app.dart';

void main() {
  testWidgets('DineFlow app renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DineFlowApp());

    expect(find.text('DineFlow'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
