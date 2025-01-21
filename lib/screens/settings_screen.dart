import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onDarkModeChanged;
  
  const SettingsScreen({
    super.key,
    required this.onDarkModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    widget.onDarkModeChanged(value);
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _isDarkMode 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        middle: const Text('設定'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),
            CupertinoListSection(
              backgroundColor: _isDarkMode 
                  ? CupertinoColors.darkBackgroundGray 
                  : CupertinoColors.systemBackground,
              header: const Text('アピアランス'),
              children: [
                CupertinoListTile(
                  backgroundColor: _isDarkMode 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.systemBackground,
                  title: const Text('ダークモード'),
                  trailing: CupertinoSwitch(
                    value: _isDarkMode,
                    onChanged: (bool value) {
                      _toggleDarkMode(value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 