import 'package:flutter/material.dart';
import 'data/models.dart';
import 'data/progress_store.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MockData.load();
  await ProgressStore.instance.load();
  runApp(const EsgJargonApp());
}

class EsgJargonApp extends StatelessWidget {
  const EsgJargonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SustainWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
