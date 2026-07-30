import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/colors.dart';
import '../../data/local/database_helper.dart';
import '../../models/braille_record.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  List<BrailleRecord> _progressData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _fetchData();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _fetchData() async {
    final data = await DatabaseHelper.instance.getAllProgress();
    setState(() {
      _progressData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruColors.bone,
      appBar: AppBar(
        backgroundColor: NuruColors.indigo,
        title: const Text("NURUTOUCH: SUPERVISOR", style: TextStyle(color: NuruColors.bone, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: NuruColors.amber),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: NuruColors.amber))
        : _progressData.isEmpty 
          ? const Center(child: Text("No learner data yet.", style: TextStyle(fontSize: 18, color: NuruColors.indigo)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _progressData.length,
              itemBuilder: (context, index) {
                final row = _progressData[index];
                
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text("Lesson: ${row.lessonId}".toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: NuruColors.indigo)),
                    subtitle: Text(
                      "Reps: ${row.repetitions}  |  Interval: ${row.intervalMinutes}m  |  EF: ${row.easinessFactor.toStringAsFixed(2)}", 
                      style: TextStyle(color: Colors.grey[700])
                    ),
                    trailing: Icon(
                      row.repetitions > 2 ? Icons.check_circle : Icons.pending, 
                      color: row.repetitions > 2 ? NuruColors.green : NuruColors.amber,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
