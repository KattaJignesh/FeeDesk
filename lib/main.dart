
import 'package:flutter/material.dart';

import 'core/database/database_service.dart';
import 'screens/data_import/excel_import_screen.dart';
import 'screens/import_history_screen.dart';
import 'screens/fee_explorer/fee_explorer_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/reports/reports_screen.dart';

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
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;

  late Future<Map<String, dynamic>> _dashboardFuture;

  static const Color _navy = Color(0xFF17233D);
  static const Color _blue = Color(0xFF3157D5);
  static const Color _background = Color(0xFFF5F7FB);

  final List<Map<String, dynamic>> menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard_rounded},
    {'title': 'Fee Explorer', 'icon': Icons.search_rounded},
    {'title': 'Data Import', 'icon': Icons.upload_file_rounded},
    {'title': 'Analytics', 'icon': Icons.bar_chart_rounded},
    {'title': 'Reports', 'icon': Icons.description_rounded},
    {'title': 'Import History', 'icon': Icons.history_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardStats();
  }

  Future<Map<String, dynamic>> _loadDashboardStats() async {
    final db = await DatabaseService.instance.database;

    final result = await db.rawQuery('''
      SELECT
        (
          SELECT COUNT(f.id)
          FROM fee_records f
          INNER JOIN dataset_imports d ON d.id = f.import_id
          WHERE d.status = 'active'
        ) AS record_count,

        (
          SELECT COUNT(DISTINCT e.category_id)
          FROM expenditure_items e
          INNER JOIN fee_records f ON f.id = e.fee_record_id
          INNER JOIN dataset_imports d ON d.id = f.import_id
          WHERE d.status = 'active'
        ) AS category_count,

        (
          SELECT file_name
          FROM dataset_imports
          WHERE status = 'active'
          ORDER BY imported_at DESC
          LIMIT 1
        ) AS last_file,

        (
          SELECT imported_at
          FROM dataset_imports
          WHERE status = 'active'
          ORDER BY imported_at DESC
          LIMIT 1
        ) AS last_import_date,

        (
          SELECT version_number
          FROM dataset_imports
          WHERE status = 'active'
          ORDER BY imported_at DESC
          LIMIT 1
        ) AS last_version
    ''');

    return result.first;
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadDashboardStats();
    });
  }

  Widget _getSelectedPage() {
    switch (selectedIndex) {
      case 1:
        return const FeeExplorerScreen();
      case 2:
        return const ExcelImportScreen();
      case 3:
        return const AnalyticsScreen();
      case 4:
        return const ReportsScreen();
      case 5:
        return const ImportHistoryScreen();
      default:
        return _buildDashboard();
    }
  }

  void _selectPage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Scaffold(
            backgroundColor: _background,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Text(
                menuItems[selectedIndex]['title'] as String,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              iconTheme: const IconThemeData(color: _navy),
              actions: [
                IconButton(
                  tooltip: 'Refresh dashboard',
                  onPressed: _refreshDashboard,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            drawer: _buildMobileDrawer(),
            body: _getSelectedPage(),
          );
        }

        return Scaffold(
          backgroundColor: _background,
          body: Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(child: _getSelectedPage()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // DESKTOP SIDEBAR
  // ------------------------------------------------------------

  Widget _buildSidebar() {
    return Container(
      width: 245,
      color: _navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          _buildBrand(),
          const SizedBox(height: 42),
          const Padding(
            padding: EdgeInsets.only(left: 22, bottom: 12),
            child: Text(
              'MAIN MENU',
              style: TextStyle(
                color: Color(0xFF8291AA),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...List.generate(menuItems.length, (index) {
            final item = menuItems[index];
            final selected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 3,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => _selectPage(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF9BAAC5),
                        size: 19,
                      ),
                      const SizedBox(width: 13),
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFBBC6D8),
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          _buildOfflineIndicator(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // MOBILE DRAWER
  // ------------------------------------------------------------

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: _navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildBrand(),
            const SizedBox(height: 35),
            const Padding(
              padding: EdgeInsets.only(left: 22, bottom: 12),
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  color: Color(0xFF8291AA),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            ...List.generate(menuItems.length, (index) {
              final item = menuItems[index];
              final selected = selectedIndex == index;

              return ListTile(
                selected: selected,
                selectedTileColor: _blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 22,
                ),
                leading: Icon(
                  item['icon'] as IconData,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF9BAAC5),
                ),
                title: Text(
                  item['title'] as String,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFFBBC6D8),
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  _selectPage(index);
                  Navigator.pop(context);
                },
              );
            }),
            const Spacer(),
            _buildOfflineIndicator(),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FeeDesk',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'FEE MANAGER',
                style: TextStyle(
                  color: Color(0xFF9BAAC5),
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF243451),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.offline_bolt_rounded,
            color: Color(0xFF54D6A0),
            size: 20,
          ),
          SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Offline Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Data stored locally',
                style: TextStyle(
                  color: Color(0xFF9BAAC5),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TOP BAR
  // ------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEAECEF)),
        ),
      ),
      child: Row(
        children: [
          Text(
            menuItems[selectedIndex]['title'] as String,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.computer_rounded,
            size: 18,
            color: Color(0xFF718096),
          ),
          const SizedBox(width: 8),
          const Text(
            'Local Device',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(width: 22),
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFE9EDFF),
            child: Icon(
              Icons.person_rounded,
              color: _blue,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DASHBOARD
  // ------------------------------------------------------------

  Widget _buildDashboard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  const Text('Could not load dashboard data'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _refreshDashboard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};

        final records =
            (data['record_count'] as num? ?? 0).toInt();

        final categories =
            (data['category_count'] as num? ?? 0).toInt();

        final lastFile = data['last_file']?.toString();

        final lastDate = _formatDate(data['last_import_date']);

        final version = data['last_version']?.toString();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to FeeDesk',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Manage, explore and analyse university fee structures.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF788397),
                ),
              ),
              const SizedBox(height: 28),

              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth > 850 ? 3 : 2;

                  final cardWidth =
                      (constraints.maxWidth -
                          (columns - 1) * 14) /
                          columns;

                  final cards = [
                    _statCard(
                      'Fee Records',
                      records.toString(),
                      'Records in active dataset',
                      Icons.receipt_long_rounded,
                      _blue,
                    ),
                    _statCard(
                      'Expenditure Categories',
                      categories.toString(),
                      'Categories currently in use',
                      Icons.category_rounded,
                      const Color(0xFF16A085),
                    ),
                    _statCard(
                      'Last Import',
                      lastDate,
                      lastFile ?? 'No active import',
                      Icons.calendar_month_rounded,
                      const Color(0xFFDB9131),
                    ),
                  ];

                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: cards.map((card) {
                      return SizedBox(
                        width: cardWidth,
                        child: card,
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 30),

              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 15),

              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth > 650 ? 2 : 1;

                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 17,
                    mainAxisSpacing: 17,
                    childAspectRatio:
                        columns == 2 ? 3.1 : 3.8,
                    children: [
                      _actionCard(
                        'Explore Fee Structures',
                        'Search and filter fee records',
                        Icons.search_rounded,
                        1,
                      ),
                      _actionCard(
                        'Import Excel Data',
                        'Import a master workbook',
                        Icons.upload_file_rounded,
                        2,
                      ),
                      _actionCard(
                        'View Analytics',
                        'Analyse fee distributions',
                        Icons.insights_rounded,
                        3,
                      ),
                      _actionCard(
                        'Generate Reports',
                        'Create PDF and Excel reports',
                        Icons.description_rounded,
                        4,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 30),

              _buildLastImportCard(
                lastFile,
                lastDate,
                version,
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFFE8ECF2),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _blue,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'About this workspace',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'FeeDesk stores its data locally on this '
                      'device. Import your fee workbook to explore fee '
                      'structures, compare expenditure and generate '
                      'reports. This application does not track actual '
                      'student payments or collections.',
                      style: TextStyle(
                        color: Color(0xFF788397),
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return 'Not yet';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return value.toString();
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Widget _buildLastImportCard(
    String? fileName,
    String date,
    String? version,
  ) {
    final hasImport = fileName != null && fileName.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Dataset',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: _blue,
                size: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasImport ? fileName : 'No dataset imported yet',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      hasImport
                          ? 'Imported: $date'
                          : 'Import an Excel workbook to get started.',
                      style: const TextStyle(
                        color: Color(0xFF788397),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasImport)
                Text(
                  version == null ? '' : 'v$version',
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF788397),
                  ),
                ),
              ),
              Icon(icon, color: color, size: 21),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF929BAA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    String title,
    String subtitle,
    IconData icon,
    int index,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _selectPage(index),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE8ECF2)),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _blue),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF929BAA),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF929BAA),
            ),
          ],
        ),
      ),
    );
  }
}
