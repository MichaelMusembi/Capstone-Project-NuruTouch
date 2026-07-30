import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/local/app_state.dart';
import '../../../theme/colors.dart';
import '../student_enrollment_profile_screen.dart';
import 'student_progress_screen.dart';
import 'lesson_reference_screen.dart';
import '../../../services/narration_service.dart';
import '../student_facial_login_screen.dart';
import '../../../main.dart' as import_main;
import '../../splash/initial_router_screen.dart';
import '../../../theme/text_styles.dart';
import 'widgets/dot_cell.dart';
import '../../../core/adaptive_learning/curriculum_database.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    NarrationService.instance.stop();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    final data = await DatabaseHelper.instance.getAllStudents();
    
    List<Map<String, dynamic>> enrichedData = [];
    final lang = AppState().languageNotifier.value;
    
    for (var student in data) {
      final mutableStudent = Map<String, dynamic>.from(student);
      final lastMasteredId = await DatabaseHelper.instance.getLastMasteredLessonId(student['id']);
      
      List<int> progressDots = [1,2,3,4,5,6]; // Fallback to full cell
      if (lastMasteredId != null) {
         final lesson = CurriculumDatabase.instance.getLessonById(lastMasteredId, lang);
         if (lesson != null && lesson.dots != null && lesson.dots!.isNotEmpty) {
           progressDots = lesson.dots!;
         }
      }
      mutableStudent['progressDots'] = progressDots;
      enrichedData.add(mutableStudent);
    }

    setState(() {
      _students = enrichedData;
      _isLoading = false;
    });
  }

  void _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSupervisorLoggedIn', false);
    AppState().isSupervisorMode = false;
    import_main.globalNavigatorKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const InitialRouterScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _logout();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text("Supervisor Dashboard", style: NuruTextStyles.body(weight: FontWeight.w500)),
        backgroundColor: Colors.white,
        foregroundColor: NuruColors.ink,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: NuruColors.slate.withValues(alpha: 0.5), height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.book),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LessonReferenceScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.door_back_door),
            onPressed: _logout,
          ),
        ],
      ),
      backgroundColor: NuruColors.background,
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty 
                ? const Center(child: Text("No students enrolled yet."))
                : ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final List<int> progressDots = student['progressDots'] as List<int>? ?? [1,2,3,4,5,6]; 
                      
                      return Container(
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context, 
                              PageRouteBuilder(
                                transitionDuration: const Duration(milliseconds: 250),
                                pageBuilder: (context, animation, secondaryAnimation) => StudentProgressScreen(studentId: student['id'], studentName: student['name']),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return SlideTransition(
                                    position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                                    child: child,
                                  );
                                },
                              )
                            );
                          },
                          onLongPress: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.login, color: NuruColors.indigo),
                                        title: Text("Log in as ${student['name']}", style: NuruTextStyles.body()),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context, 
                                            MaterialPageRoute(
                                              builder: (_) => StudentFacialLoginScreen(targetStudentId: student['id'])
                                            )
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete_forever, color: NuruColors.coral),
                                        title: Text("Reset All Progress", style: NuruTextStyles.body(color: NuruColors.coral)),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final db = await DatabaseHelper.instance.database;
                                          await db.delete('lessons_progress', where: 'student_id = ?', whereArgs: [student['id']]);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Progress reset for ${student['name']}")));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(student['name'], style: NuruTextStyles.body(fontSize: 16, weight: FontWeight.w500)),
                                ),
                                DotCell(targetDots: progressDots, dotSize: 4.0, spacing: 2.0, baseColor: NuruColors.indigo),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
      ),
      floatingActionButton: _students.isEmpty 
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentEnrollmentProfileScreen())).then((_) => _fetchStudents());
              },
              backgroundColor: NuruColors.indigo,
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: Text("Enroll your first student", style: NuruTextStyles.body(color: Colors.white)),
            )
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentEnrollmentProfileScreen())).then((_) => _fetchStudents());
              },
              backgroundColor: NuruColors.indigo,
              shape: const CircleBorder(),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
    ),
    );
  }
}
