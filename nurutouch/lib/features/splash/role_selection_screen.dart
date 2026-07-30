import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/app_state.dart';
import '../supervisor/login_screen.dart';
import '../supervisor/dashboard/student_list_screen.dart';
import '../supervisor/student_facial_login_screen.dart';
import '../../theme/colors.dart';
import '../../theme/text_styles.dart';
import '../../services/tts_service.dart';
import '../learner/orientation_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ttsService.speak("Welcome to NuruTouch. Please select your profile.", language: "en-US");
  }

  void _continueAsTeacher() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLogged = prefs.getBool('isSupervisorLoggedIn') ?? false;

    if (!mounted) return;

    if (isLogged) {
      AppState().isSupervisorMode = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentListScreen()),
      );
    } else {
      final supervisors = await DatabaseHelper.instance.getAllSupervisors();
      if (!mounted) return;
      if (supervisors.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen(isInitialLaunch: true, requiresSignup: true)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen(isInitialLaunch: true, requiresSignup: false)),
        );
      }
    }
  }

  void _continueAsStudent() async {
    // Check for students
    final students = await DatabaseHelper.instance.getAllStudents();
    if (!mounted) return;
    
    if (students.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const StudentFacialLoginScreen()),
      );
    } else {
      _ttsService.speak("No students found. Please ask your teacher to set up an account.", language: "en-US");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No students enrolled.", style: NuruTextStyles.body(color: Colors.white)),
          backgroundColor: NuruColors.ink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.school, size: 80, color: NuruColors.indigo),
                const SizedBox(height: 24),
                Text(
                  "Who is using NuruTouch?",
                  textAlign: TextAlign.center,
                  style: NuruTextStyles.display(fontSize: 28, color: NuruColors.ink),
                ),
                const SizedBox(height: 48),
                
                // Student Button
                ElevatedButton(
                  onPressed: _continueAsStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NuruColors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.face, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Text("Continue as Student", style: NuruTextStyles.body(color: Colors.white, fontSize: 20, weight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Teacher Button
                OutlinedButton(
                  onPressed: _continueAsTeacher,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NuruColors.indigo,
                    side: const BorderSide(color: NuruColors.indigo, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 32),
                      const SizedBox(width: 16),
                      Text("Continue as Teacher", style: NuruTextStyles.body(color: NuruColors.indigo, fontSize: 20, weight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
