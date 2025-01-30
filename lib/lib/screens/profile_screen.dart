import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import 'edit_profile_screen.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onDarkModeChanged;

  const ProfileScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = '';
  final _userNameController = TextEditingController();
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadStatistics();
  }

  @override
  void dispose() {
    _userNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? '';
      _userNameController.text = _userName;
    });
  }

  Future<void> _loadStatistics() async {
    final streak = await DatabaseHelper.instance.getCurrentStreak();
    setState(() {
      _currentStreak = streak;
    });
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode 
            ? CupertinoColors.darkBackgroundGray 
            : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDarkMode 
              ? CupertinoColors.systemGrey6.withOpacity(0.1)
              : CupertinoColors.systemGrey5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: const Color(0xFFFF2A6D),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode 
                  ? CupertinoColors.white 
                  : CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: widget.isDarkMode 
                  ? CupertinoColors.systemGrey 
                  : CupertinoColors.systemGrey2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Userの状態を監視
    final user = context.watch<User>();

    return CupertinoPageScaffold(
      backgroundColor: widget.isDarkMode 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: widget.isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        middle: const Text('プロフィール'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('編集'),
          onPressed: () async {
            await Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => EditProfileScreen(
                  isDarkMode: widget.isDarkMode,
                ),
              ),
            );
            _loadUserProfile();
          },
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: widget.isDarkMode 
                            ? CupertinoColors.systemGrey 
                            : CupertinoColors.systemGrey5,
                        shape: BoxShape.circle,
                        image: user.iconPath != null
                            ? DecorationImage(
                                image: FileImage(File(user.iconPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user.iconPath == null
                          ? Icon(
                              CupertinoIcons.person_fill,
                              size: 60,
                              color: widget.isDarkMode 
                                  ? CupertinoColors.white 
                                  : CupertinoColors.black,
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.nickname,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode 
                            ? CupertinoColors.white 
                            : CupertinoColors.black,
                      ),
                    ),
                    Text(
                      '@$_userName',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDarkMode 
                            ? CupertinoColors.systemGrey 
                            : CupertinoColors.systemGrey2,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              Text(
                '統計',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.isDarkMode 
                      ? CupertinoColors.white 
                      : CupertinoColors.black,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: '連続達成日数',
                      value: '$_currentStreak日',
                      icon: CupertinoIcons.flame_fill,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: '完了タスク数',
                      value: '${user.totalCompletedTasks}個',
                      icon: CupertinoIcons.check_mark_circled_solid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    'ダークモード',
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDarkMode 
                          ? CupertinoColors.white 
                          : CupertinoColors.black,
                    ),
                  ),
                  const Spacer(),
                  CupertinoSwitch(
                    value: widget.isDarkMode,
                    onChanged: (bool value) async {
                      widget.onDarkModeChanged(value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isDarkMode', value);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}