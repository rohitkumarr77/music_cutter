import 'package:flutter_test/flutter_test.dart';
import 'package:music_cutter/main.dart';

void main() {
  testWidgets('Music Cutter loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MusicCutterApp());
    await tester.pump();
    expect(find.textContaining('Music Cutter'), findsWidgets);
  });
}
