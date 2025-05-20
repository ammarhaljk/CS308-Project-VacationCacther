import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'main.dart';
import 'friends_screen.dart';
import 'shared_albums/screen.dart';

class MenuScreen extends StatelessWidget {
  final String userId;
  final AuthService _authService = AuthService();

  MenuScreen({required this.userId});

  void _signOut(BuildContext context) async {
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: Text(
        "VacationCatcher",
        style: GoogleFonts.pacifico(fontSize: 24, color: Colors.white),
    ),
    backgroundColor: Color(0xFFFF5252),
    actions: [
    IconButton(
    icon: Icon(Icons.logout, color: Colors.white),
    onPressed: () {
    showDialog(
    context: context,
    builder: (context) => AlertDialog(
    title: Text("Sign Out"),
    content: Text("Are you sure you want to sign out?"),
    actions: [
    TextButton(
    onPressed: () {
    Navigator.pop(context);
    },
    child: Text("Cancel"),
    ),
    TextButton(
    onPressed: () {
    Navigator.pop(context);
    _signOut(context);
    },
    child: Text("Sign Out"),
    ),
    ],
    ),
    );
    },
    ),
    ],
    ),
    body: SafeArea(
    child: SingleChildScrollView(
    child: Container(
    padding: EdgeInsets.all(24),
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
    // App Logo
    Column(
    children: [
    Icon(
    Icons.photo_camera,
    size: 80,
    color: Color(0xFFFF5252),
    ),
    SizedBox(height: 16),
    Text(
    'VacationCatcher',
    style: GoogleFonts.pacifico(fontSize: 32, color: Color(0xFFFF5252)),
    ),
    SizedBox(height: 16),
    Text(
    'Capture and share your memorable moments',
    textAlign: TextAlign.center,
    style: TextStyle(
    color: Colors.grey[600],
    fontSize: 16,
    ),
    ),
    ],
    ),

    SizedBox(height: 60),

    // Your Albums Button
    _buildMenuButton(
    context,
    'Your Albums',
    Icons.photo_album,
    () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => AlbumScreen(userId: userId),
    ),
    );
    },
    ),

    SizedBox(height: 20),

    // Shared Albums Button
    _buildMenuButton(
    context,
    'Shared Albums',
    Icons.people,
    () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => SharedAlbumsScreen(userId: userId),
    ),
    );
    },
    ),

    SizedBox(height: 20),

    // Friends Button - Updated to navigate to FriendsScreen
    _buildMenuButton(
    context,
    'Friends',
    Icons.person_add,
    () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => FriendsScreen(userId: userId),
    ),
    );
    },
    ),

    SizedBox(height: 20),

    // Account Button
    _buildMenuButton(
    context,
    'Account',
    Icons.settings,
    () {
    // Placeholder for navigation to Account screen
    // This will be implemented later
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
    content: Text("Account settings coming soon!"),
    duration: Duration(seconds: 2),
    ),
    );
    },
    ),
    ],
    ),
    ),
    ),
    ));
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFFFF5252),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(icon, size: 36),
            SizedBox(width: 24),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios),
          ],
        ),
      ),
    );
  }
}