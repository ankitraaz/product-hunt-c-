import 'package:flutter/material.dart';
import 'package:product_hunt/model/user_model.dart';
import 'package:product_hunt/widgets/profile_dialog.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class ProductHuntProfilePage extends StatefulWidget {
  @override
  _ProductHuntProfilePageState createState() => _ProductHuntProfilePageState();
}

class _ProductHuntProfilePageState extends State<ProductHuntProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  Future<void> _loadUserProfile() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    await firestoreService.getCurrentUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Consumer<FirestoreService>(
          builder: (context, firestoreService, child) {
            if (firestoreService.isLoading) {
              return Center(child: CircularProgressIndicator());
            }

            // Check if user is logged in
            if (FirebaseAuth.instance.currentUser == null) {
              return _buildLoginPrompt();
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 1024;

                return Row(
                  children: [
                    if (isDesktop) _buildSidebar(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildMainContent(
                          context,
                          isDesktop,
                          firestoreService.currentUser,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Please login to view your profile',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showLoginDialog(),
            child: Text('Login'),
          ),
        ],
      ),
    );
  }

  void _showLoginDialog() {
    showDialog(context: context, builder: (context) => _LoginDialog());
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 32),
          _buildSidebarItem(Icons.person_outline, 'User profile', true),
          _buildSidebarItem(Icons.keyboard_arrow_up, 'Upvotes', false),
          _buildSidebarItem(Icons.forum_outlined, 'Forums', false),
          _buildSidebarItem(Icons.layers_outlined, 'Stacks', false),
          _buildSidebarItem(Icons.rate_review_outlined, 'Reviews', false),
          _buildSidebarItem(Icons.timeline, 'Activity', false),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isSelected) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.orange : Colors.grey[600],
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? Colors.orange : Colors.grey,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: isSelected ? Colors.orange.withOpacity(0.1) : null,
        selected: isSelected,
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    bool isDesktop,
    UserModel? user,
  ) {
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading profile...'),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: 900),
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 40 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 48),

          // Profile header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile avatar - Fixed property name
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: user.profilePicture.isNotEmpty
                    ? CachedNetworkImageProvider(user.profilePicture)
                    : null,
                child: user.profilePicture.isEmpty
                    ? Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),

              SizedBox(width: 24),

              // Profile info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.username.isNotEmpty
                                    ? user.username
                                    : 'User Name',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 12),
                              // Fixed followers/following count
                              Wrap(
                                spacing: 24,
                                children: [
                                  Text(
                                    'Followers : ${user.followers.length}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Following : ${user.following.length}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 16),

                        // Edit profile button
                        InkWell(
                          onTap: () => _showEditProfileDialog(user),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Edit profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 48),

          // Tab navigation
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                _buildTab('About', true),
                _buildTab('Collections', false),
                _buildTab('Launched Products', false),
              ],
            ),
          ),

          SizedBox(height: 40),

          // Bio section
          Text(
            'Bio',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),

          SizedBox(height: 24),

          // Bio content or add bio button
          if (user.bio.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                user.bio,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.6),
              ),
            )
          else
            Center(
              child: InkWell(
                onTap: () => _showAddBioDialog(user),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.grey, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Add bio',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SizedBox(height: 80),

          // Visit section
          Text(
            'Visit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),

          SizedBox(height: 20),

          // Social links
          Row(
            children: [
              _buildSocialIcon(Icons.camera_alt),
              SizedBox(width: 16),
              _buildSocialIcon(Icons.close),
              SizedBox(width: 16),
              _buildSocialIcon(Icons.language),
            ],
          ),

          SizedBox(height: 40),

          // Get in touch button
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Contact feature coming soon!')),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Get in touch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isSelected) {
    return Padding(
      padding: EdgeInsets.only(right: 32),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.orange : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.orange : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey!),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(
        icon,
        size: 20,
        color: Colors.grey, // Fixed color
      ),
    );
  }

  void _showEditProfileDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
  }

  void _showAddBioDialog(UserModel user) {
    TextEditingController bioController = TextEditingController(text: user.bio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Bio'),
        content: TextField(
          controller: bioController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Tell us about yourself...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (bioController.text.trim().isNotEmpty) {
                bool success = await Provider.of<FirestoreService>(
                  context,
                  listen: false,
                ).updateUserField('bio', bioController.text.trim());

                Navigator.pop(context);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bio updated successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update bio')),
                  );
                }
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Simple Login Dialog (as fallback)
class _LoginDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Login Required'),
      content: Text(
        'Please go back and use the main login screen to access your profile.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
      ],
    );
  }
}
