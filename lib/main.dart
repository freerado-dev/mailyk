import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initializeDateFormatting('sk');
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const KonverzoApp(),
    ),
  );
}

class KonverzoApp extends StatelessWidget {
  const KonverzoApp({super.key});

  static const Color accent = Color(0xFF007AFF);

  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: b)
          .copyWith(primary: accent),
      scaffoldBackgroundColor:
          dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBarTheme: AppBarTheme(
        backgroundColor:
            dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerColor: dark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6),
      visualDensity: VisualDensity.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Konverzo Mail',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
