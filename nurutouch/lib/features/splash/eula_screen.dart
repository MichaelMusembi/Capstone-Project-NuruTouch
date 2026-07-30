import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/colors.dart';
import 'initial_router_screen.dart';

class EulaScreen extends StatelessWidget {
  const EulaScreen({super.key});

  Future<void> _agree(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eula_agreed', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InitialRouterScreen()),
    );
  }

  void _decline() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruColors.bone,
      appBar: AppBar(
        title: const Text('End User License Agreement', style: TextStyle(color: NuruColors.bone)),
        backgroundColor: NuruColors.indigo,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NuruTouch Privacy Policy & Ethics Declaration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: NuruColors.indigo,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      '1. Research & Experimental Nature',
                      'This application was developed as a Capstone project. It is experimental in nature and its primary use is currently for non-visual simulation testing. NuruTouch is not a medical device.',
                    ),
                    _buildSection(
                      '2. Facial Biometric Data Collection',
                      'NuruTouch collects facial biometric data during the student enrolment process to enable secure offline logins. To protect user privacy, the application DOES NOT store raw images of faces. Instead, it extracts and strictly stores a 128-dimensional embedding vector.',
                    ),
                    _buildSection(
                      '3. 100% Offline Processing',
                      'All data processing, including facial recognition and lesson progress tracking, occurs exclusively on-device. Absolutely no data is transmitted over a network or stored on a cloud server.',
                    ),
                    _buildSection(
                      '4. Supervisor Accountability',
                      'As a supervisor (teacher, parent, or guardian), you act as the data controller for the children enrolled on this device. You are strictly responsible for enforcing device-level security, such as maintaining a strong screen lock passcode, to protect the biometric embeddings stored in the local database.',
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'By tapping "Agree & Continue", you confirm that you have read and accepted these terms.',
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: NuruColors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: NuruColors.indigo),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _decline,
                      child: const Text('Decline & Exit', style: TextStyle(color: NuruColors.indigo, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NuruColors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _agree(context),
                      child: const Text('Agree & Continue', style: TextStyle(color: NuruColors.bone, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NuruColors.indigo,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
