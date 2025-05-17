import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateSharedAlbumScreen extends StatefulWidget {
  final String userId;

  const CreateSharedAlbumScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _CreateSharedAlbumScreenState createState() => _CreateSharedAlbumScreenState();
}

class _CreateSharedAlbumScreenState extends State<CreateSharedAlbumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _friends = [];
  Set<String> _selectedFriendIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Query the user's friends subcollection
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .get();

      List<Map<String, dynamic>> friendsList = [];

      // For each friend relationship, get the actual user data
      for (var doc in friendsSnapshot.docs) {
        final friendId = doc.id;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          friendsList.add({
            'id': friendId,
            'name': userData['displayName'] ?? 'Unknown User',
            'photoUrl': userData['photoUrl'] ?? '',
            'email': userData['email'] ?? '',
          });
        }
      }

      setState(() {
        _friends = friendsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading friends: $e')),
      );
    }
  }

  Future<void> _createSharedAlbum() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one friend to share with')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create the shared album document
      final albumRef = await FirebaseFirestore.instance.collection('sharedAlbums').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'creatorId': widget.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [widget.userId, ..._selectedFriendIds.toList()],
        'participantCount': _selectedFriendIds.length + 1, // Include creator
        'coverImageUrl': '', // Will be updated when first image is added
      });

      // Navigate back to shared albums screen
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared album created successfully')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating shared album: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Create Shared Album",
          style: GoogleFonts.pacifico(fontSize: 24, color: Colors.white),
        ),
        backgroundColor: Color(0xFFFF5252),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Album Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Album Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.photo_album),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an album name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Album Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),

              // Friends Selection Section
              Text(
                'Share with Friends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),

              if (_friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'You have no friends to share with yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final friendId = friend['id'];
                    final isSelected = _selectedFriendIds.contains(friendId);

                    return CheckboxListTile(
                      title: Text(friend['name']),
                      subtitle: Text(friend['email']),
                      secondary: CircleAvatar(
                        backgroundImage: friend['photoUrl'].isNotEmpty
                            ? NetworkImage(friend['photoUrl'])
                            : null,
                        child: friend['photoUrl'].isEmpty
                            ? Icon(Icons.person)
                            : null,
                      ),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedFriendIds.add(friendId);
                          } else {
                            _selectedFriendIds.remove(friendId);
                          }
                        });
                      },
                    );
                  },
                ),

              SizedBox(height: 24),

              // Create Button
              ElevatedButton(
                onPressed: _isLoading ? null : _createSharedAlbum,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF5252),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Create Shared Album',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}