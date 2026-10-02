import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/app.dart';

void main() {
  testWidgets('home screen shows the game title', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GpuEmpireApp()));
    await tester.pump();

    expect(find.text('GPU Empire'), findsOneWidget);
  });
}
