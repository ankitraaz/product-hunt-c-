import 'package:flutter/material.dart';
import 'package:product_hunt/model/user_model.dart';
import 'package:provider/provider.dart';

import '../services/firestore_service.dart';

class EditProfileDialog extends StatefulWidget {
  final UserModel user;

  const EditProfileDialog({Key? key, required this.user}) : super(key: key);

  @override
  _EditProfileDialogState createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        Consumer<FirestoreService>(
          builder: (context, firestoreService, child) {
            return ElevatedButton(
              onPressed: firestoreService.isLoading ? null : _saveProfile,
              child: firestoreService.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Save'),
            );
          },
        ),
      ],
    );
  }

  void _saveProfile() async {
    final updatedUser = widget.user.copyWith(
      username: _usernameController.text.trim(),
      bio: _bioController.text.trim(),
    );

    bool success = await Provider.of<FirestoreService>(
      context,
      listen: false,
    ).updateUserProfile(updatedUser);

    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile updated successfully!')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile')));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
