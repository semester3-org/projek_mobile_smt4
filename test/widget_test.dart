import 'package:flutter_test/flutter_test.dart';

import 'package:projek_mobile/main.dart';

void main() {
  testWidgets('Aplikasi memuat beranda setelah splash', (WidgetTester tester) async {
    await tester.pumpWidget(const KosFinderApp());
    await tester.pump();
    // Splash menunda navigasi ~2.2 detik
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('KosFinder'), findsWidgets);
    expect(find.text('Beranda'), findsOneWidget);
  });
}
