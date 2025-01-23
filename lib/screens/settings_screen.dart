import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onDarkModeChanged;
  
  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  bool _isNotificationEnabled = true;
  bool _hasNotificationPermission = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPermission = await NotificationService().checkNotificationPermission();
    
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? widget.isDarkMode;
      _isNotificationEnabled = prefs.getBool('isNotificationEnabled') ?? true;
      _hasNotificationPermission = hasPermission;
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

  Future<void> _toggleNotification(bool value) async {
    if (value && !_hasNotificationPermission) {
      // 通知を有効にしようとしているが、権限がない場合
      final granted = await NotificationService().requestNotificationPermission();
      if (!granted) {
        // 権限が得られなかった場合、設定画面を表示するか確認
        // ignore: use_build_context_synchronously
        await showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('通知の許可が必要です'),
            content: const Text('タスクの通知を受け取るには、設定から通知を許可してください。'),
            actions: [
              CupertinoDialogAction(
                child: const Text('キャンセル'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('設定を開く'),
                onPressed: () {
                  Navigator.pop(context);
                  NotificationService().openNotificationSettings();
                },
              ),
            ],
          ),
        );
        return;
      }
      setState(() {
        _hasNotificationPermission = granted;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationEnabled', value);
    setState(() {
      _isNotificationEnabled = value;
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
            const SizedBox(height: 20),
            CupertinoListSection(
              backgroundColor: _isDarkMode 
                  ? CupertinoColors.darkBackgroundGray 
                  : CupertinoColors.systemBackground,
              header: const Text('通知'),
              children: [
                CupertinoListTile(
                  backgroundColor: _isDarkMode 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.systemBackground,
                  title: const Text('タスク通知'),
                  subtitle: Text(_hasNotificationPermission 
                      ? '期限前の通知を受け取る'
                      : '通知の許可が必要です'),
                  trailing: CupertinoSwitch(
                    value: _isNotificationEnabled && _hasNotificationPermission,
                    onChanged: _toggleNotification,
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