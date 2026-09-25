import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/classifier/greeting_classifier.dart';
import 'services/face_detector_service.dart';
import 'services/gallery_service.dart';
import 'services/hash_store.dart';
import 'services/scan_pipeline.dart';
import 'state/cleaner_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await SqfliteDecisionStore.open();
  final scorer =
      await TfliteGreetingClassifier.load() ?? const NoModelScorer();
  final pipeline = ScanPipeline(
    store: store,
    faces: MlKitFaceChecker(),
    scorer: scorer,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => CleanerController(
        gallery: GalleryService(),
        store: store,
        pipeline: pipeline,
      )..requestPermission(),
      child: const GreetingCleanerApp(),
    ),
  );
}

class GreetingCleanerApp extends StatelessWidget {
  const GreetingCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'منظّف المعايدات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF128C7E),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF128C7E),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
