import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/scan_provider.dart';
import 'result_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final scan = context.read<ScanProvider>();
    await scan.analyzeCurrentProduct();
    if (!mounted) return;
    if (scan.stage == ScanStage.result) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResultScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(scan.errorMessage ?? 'Analysis failed')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.greenPrimary, strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Analyzing ingredients…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            const Text('Checking suitability for all age groups',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
