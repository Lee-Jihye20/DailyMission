import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final bool isDarkMode;

  const EditProfileScreen({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nicknameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = context.read<User>();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nicknameController.text = user.nickname;
      _userNameController.text = prefs.getString('userName') ?? '';
      _selectedImagePath = user.iconPath;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImagePath = image.path;
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = context.read<User>();
    final prefs = await SharedPreferences.getInstance();
    
    user.nickname = _nicknameController.text;
    await prefs.setString('userName', _userNameController.text);
    
    if (_selectedImagePath != null) {
      user.iconPath = _selectedImagePath;
    }
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: widget.isDarkMode 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: widget.isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        middle: const Text('プロフィール編集'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('キャンセル'),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('保存'),
          onPressed: _saveProfile,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode 
                          ? CupertinoColors.systemGrey 
                          : CupertinoColors.systemGrey5,
                      shape: BoxShape.circle,
                      image: _selectedImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(_selectedImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedImagePath == null
                        ? Stack(
                            children: [
                              Center(
                                child: Icon(
                                  CupertinoIcons.person_fill,
                                  size: 60,
                                  color: widget.isDarkMode 
                                      ? CupertinoColors.white 
                                      : CupertinoColors.black,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF2A6D),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.camera_fill,
                                    color: CupertinoColors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'ニックネーム',
                style: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode 
                      ? CupertinoColors.systemGrey 
                      : CupertinoColors.systemGrey2,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _nicknameController,
                placeholder: 'ニックネームを入力',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkMode 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                style: TextStyle(
                  color: widget.isDarkMode 
                      ? CupertinoColors.white 
                      : CupertinoColors.black,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'ユーザー名',
                style: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode 
                      ? CupertinoColors.systemGrey 
                      : CupertinoColors.systemGrey2,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _userNameController,
                placeholder: 'ユーザー名を入力',
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkMode 
                      ? CupertinoColors.darkBackgroundGray 
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                style: TextStyle(
                  color: widget.isDarkMode 
                      ? CupertinoColors.white 
                      : CupertinoColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 