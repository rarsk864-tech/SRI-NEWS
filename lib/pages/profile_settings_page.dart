import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const _profileRed = Color(0xFFE60000);
const _profileBg = Color(0xFFF7F8FA);

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  bool _saving = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<File> _profileFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sri_news_profile_${_user!.uid}.jpg');
  }

  Future<void> _loadProfileImage() async {
    final user = _user;
    if (user == null) return;
    final file = await _profileFile();
    if (await file.exists() && mounted) {
      setState(() => _profileImage = file);
    }
  }

  Future<void> _pickProfileImage() async {
    final user = _user;
    if (user == null || _saving) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() => _saving = true);
    try {
      final target = await _profileFile();
      await File(picked.path).copy(target.path);
      if (!mounted) return;
      setState(() => _profileImage = target);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeProfileImage() async {
    final file = _profileImage;
    if (file != null && await file.exists()) {
      await file.delete();
    }
    if (!mounted) return;
    setState(() => _profileImage = null);
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.displayName?.trim().isNotEmpty == true
        ? _user!.displayName!.trim()
        : 'SRI News User';

    return Scaffold(
      backgroundColor: _profileBg,
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: _profileRed,
                  backgroundImage:
                      _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person, color: Colors.white, size: 58)
                      : null,
                ),
                Material(
                  color: _profileRed,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _saving ? null : _pickProfileImage,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text(_user?.email ?? '')),
          const SizedBox(height: 26),
          Card(
            color: Colors.white,
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Change profile picture'),
                  subtitle: const Text('Choose a picture from your gallery'),
                  trailing: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _saving ? null : _pickProfileImage,
                ),
                if (_profileImage != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: _profileRed),
                    title: const Text('Remove profile picture'),
                    onTap: _saving ? null : _removeProfileImage,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

