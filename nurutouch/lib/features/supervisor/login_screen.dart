import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/app_state.dart';
import '../../theme/colors.dart';
import 'dashboard/student_list_screen.dart';
import '../splash/role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onCancel;
  final bool isInitialLaunch;
  final bool requiresSignup;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onCancel,
    this.isInitialLaunch = false,
    this.requiresSignup = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = "";
  late bool _isLoginMode;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isLoginMode = !widget.requiresSignup;
  }

  void _submit() async {
    setState(() {
      _isLoading = true;
      _errorMsg = "";
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMsg = "Please fill in all fields.";
        _isLoading = false;
      });
      return;
    }

    if (!_isLoginMode) {
      // Create Account
      try {
        await DatabaseHelper.instance.insertSupervisor(email, password);
        _handleSuccess();
      } catch (e) {
        setState(() {
          _errorMsg = "Email already exists or error occurred.";
          _isLoading = false;
        });
      }
    } else {
      // Login
      bool isValid = await DatabaseHelper.instance.authenticateSupervisor(email, password);
      if (isValid) {
        _handleSuccess();
      } else {
        setState(() {
          _errorMsg = "Invalid email or password.";
          _isLoading = false;
        });
      }
    }
  }

  void _handleSuccess() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSupervisorLoggedIn', true);
    AppState().isSupervisorMode = true;
    
    if (widget.isInitialLaunch) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StudentListScreen()),
        );
      }
    } else {
      widget.onLoginSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 64, color: NuruColors.indigo),
              const SizedBox(height: 16),
              Text(_isLoginMode ? "Supervisor Login" : "Create Account", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NuruColors.indigo)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              if (_errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_errorMsg, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                    _errorMsg = "";
                  });
                },
                child: Text(_isLoginMode ? "Need an account? Sign Up" : "Already have an account? Login"),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!widget.isInitialLaunch)
                          TextButton(
                            onPressed: widget.onCancel,
                            child: const Text("Cancel"),
                          ),
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(backgroundColor: NuruColors.indigo),
                          child: Text(_isLoginMode ? "Login" : "Sign Up", style: const TextStyle(color: NuruColors.bone)),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );

    if (widget.isInitialLaunch) {
      return Scaffold(
        backgroundColor: NuruColors.bone,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              );
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: NuruColors.indigo,
        ),
        body: content,
      );
    }

    return content;
  }
}
