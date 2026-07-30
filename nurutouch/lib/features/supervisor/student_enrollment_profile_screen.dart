import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/app_state.dart';
import '../splash/gateway_screen.dart';
import 'student_enrollment_camera_screen.dart';
class StudentEnrollmentProfileScreen extends StatefulWidget {
  final bool isFirstSetup;

  const StudentEnrollmentProfileScreen({super.key, this.isFirstSetup = false});

  @override
  State<StudentEnrollmentProfileScreen> createState() => _StudentEnrollmentProfileScreenState();
}

class _StudentEnrollmentProfileScreenState extends State<StudentEnrollmentProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  Future<void> _proceedToCamera() async {
    String name = _nameController.text.trim();
    String ageStr = _ageController.text.trim();
    if (name.isEmpty || ageStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both name and age.")),
      );
      return;
    }
    
    int? age = int.tryParse(ageStr);
    if (age == null || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid age.")),
      );
      return;
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentEnrollmentCameraScreen(
            studentName: name,
            studentAge: age,
            isFirstSetup: widget.isFirstSetup,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruColors.bone,
      appBar: AppBar(
        title: const Text("Enroll Student - Step 1", style: TextStyle(color: Colors.white)),
        backgroundColor: NuruColors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add, size: 64, color: NuruColors.indigo),
                const SizedBox(height: 16),
                const Text(
                  "Student Profile",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NuruColors.indigo),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter the student's details before proceeding to facial verification.",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Student Name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: "Student Age",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _proceedToCamera,
                    style: ElevatedButton.styleFrom(backgroundColor: NuruColors.indigo),
                    child: const Text("Proceed to Facial Verification", style: TextStyle(color: NuruColors.bone)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
