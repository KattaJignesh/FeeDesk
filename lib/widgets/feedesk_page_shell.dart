import 'package:flutter/material.dart';

import '../screens/data_import/excel_import_screen.dart';
import '../screens/fee_explorer/fee_explorer_screen.dart';
import '../screens/import_history_screen.dart';

class FeeDeskPageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final String selectedPage;

  const FeeDeskPageShell({
    super.key,
    required this.title,
    required this.child,
    required this.selectedPage,
  });

  static const Color navy = Color(0xFF17233D);
  static const Color blue = Color(0xFF3157D5);
  static const Color background = Color(0xFFF5F7FB);

  void _navigate(BuildContext context, String page) {
    Navigator.pop(context);

    if (page == selectedPage) return;

    Widget destination;

    switch (page) {
      case 'Upload File':
        destination = const ExcelImportScreen();
        break;
      case 'Fee Explorer':
        destination = const FeeExplorerScreen();
        break;
      case 'History':
        destination = const ImportHistoryScreen();
        break;
      default:
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
    }

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: navy,
          elevation: 0,
          surfaceTintColor: Colors.white,
          titleTextStyle: TextStyle(
            color: navy,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE5EAF2)),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: navy,
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'FeeDesk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                _menuItem(context, 'Home', Icons.home_rounded),
                _menuItem(context, 'Upload File', Icons.upload_file_rounded),
                _menuItem(context, 'Fee Explorer', Icons.search_rounded),
                _menuItem(context, 'History', Icons.history_rounded),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Offline · Data stored locally',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(child: child),
      ),
    );
  }

  Widget _menuItem(BuildContext context, String page, IconData icon) {
    final selected = selectedPage == page;

    return ListTile(
      selected: selected,
      selectedTileColor: blue,
      leading: Icon(icon, color: Colors.white),
      title: Text(page, style: const TextStyle(color: Colors.white)),
      onTap: () => _navigate(context, page),
    );
  }
}
