import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'eula_screen.dart';
import 'role_selection_screen.dart';
import '../../theme/colors.dart';

class InitialRouterScreen extends StatefulWidget {
  const InitialRouterScreen({super.key});

  @override
  State<InitialRouterScreen> createState() => _InitialRouterScreenState();
}

class _InitialRouterScreenState extends State<InitialRouterScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final bool eulaAgreed = prefs.getBool('eula_agreed') ?? false;

    if (!mounted) return;

    if (!eulaAgreed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EulaScreen()),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show a simple loading screen while deciding
    return const Scaffold(
      backgroundColor: NuruColors.bone,
      body: Center(
        child: CircularProgressIndicator(color: NuruColors.indigo),
      ),
    );
  }
}
