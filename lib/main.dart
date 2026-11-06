import 'package:flutter/material.dart';

import 'core/database/database_service.dart';
import 'screens/data_import/excel_import_screen.dart';
import 'screens/fee_explorer/fee_explorer_screen.dart';
import 'screens/import_history_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initialize();
  runApp(const FeeDeskApp());
}

class FeeDeskApp extends StatelessWidget {
  const FeeDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FeeDesk',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3157D5),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color navy = Color(0xFF17233D);
  static const Color blue = Color(0xFF3157D5);

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 75,
        titleSpacing: 24,
        title: Row(
          children: [
            Image.asset(
              'assets/branding/app_icon.png',
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.account_balance_rounded,
                color: blue,
                size: 35,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'FeeDesk',
              style: TextStyle(
                color: navy,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 25),
                const Text(
                  'Welcome to FeeDesk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: navy,
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Manage and explore university fee structures.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF788397), fontSize: 14),
                ),
                const SizedBox(height: 42),

                _HomeActionCard(
                  title: 'Upload File',
                  subtitle: 'Import a fee workbook from your device',
                  icon: Icons.upload_file_rounded,
                  color: blue,
                  onTap: () => _openScreen(context, const ExcelImportScreen()),
                ),

                const SizedBox(height: 18),

                _HomeActionCard(
                  title: 'Fee Explorer',
                  subtitle: 'Search and explore fee records',
                  icon: Icons.search_rounded,
                  color: const Color(0xFF159A82),
                  onTap: () => _openScreen(context, const FeeExplorerScreen()),
                ),

                const SizedBox(height: 18),

                _HomeActionCard(
                  title: 'History',
                  subtitle: 'View your previous file imports',
                  icon: Icons.history_rounded,
                  color: const Color(0xFFDB9131),
                  onTap: () =>
                      _openScreen(context, const ImportHistoryScreen()),
                ),

                const SizedBox(height: 35),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8ECF2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.offline_bolt_rounded,
                        color: Color(0xFF16A085),
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'Offline Mode · Data stored locally',
                        style: TextStyle(
                          color: Color(0xFF657187),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

class _HomeActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF17233D),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF788397),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF929BAA),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
