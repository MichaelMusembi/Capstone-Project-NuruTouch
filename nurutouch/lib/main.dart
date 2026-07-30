import 'package:flutter/material.dart';
import 'features/splash/initial_router_screen.dart';
import 'features/supervisor/global_pin_gate.dart';
import 'services/tts_service.dart';
import 'data/local/database_helper.dart';
import 'core/adaptive_learning/curriculum_database.dart';
import 'services/narration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  TtsService(); 
  
  await CurriculumDatabase.instance.loadCurriculum();
  await NarrationService.instance.init();
  
  runApp(const NuruTouchApp());
}

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class NuruTouchApp extends StatelessWidget {
  const NuruTouchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NuruTouch',
      debugShowCheckedModeBanner: false,
      navigatorKey: globalNavigatorKey,
      builder: (context, child) {
        return PinGateOverlay(child: child!);
      },
      home: const InitialRouterScreen(),
    );
  }
}
