import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class FriendsScreen extends StatefulWidget {
  final String userId;

  FriendsScreen({required this.userId});

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  void _sendFriendRequest(String friendId, String friendName, String friendEmail) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Get current user data
      final currentUser = _authService.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>;
      final currentUserName = userData['username'] ?? currentUser.email!.split('@')[0];

      // Create a friend request
      await FirebaseFirestore.instance.collection('friendRequests').add({
        'senderId': currentUser.uid,
        'senderName': currentUserName,
        'senderEmail': currentUser.email,
        'receiverId': friendId,
        'receiverName': friendName,
        'receiverEmail': friendEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Friend request sent to $friendName")),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending friend request: ${e.toString()}")),
      );
    }
  }

  void _acceptFriendRequest(String requestId, String friendId, String friendName, String friendEmail) async {
    final currentUser = _authService.currentUser;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Update request status
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .update({'status': 'accepted'});

      // Add to current user's friend list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friends')
          .doc(friendId)
          .set({
        'userId': friendId,
        'username': friendName,
        'email': friendEmail,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Get current user's name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final currentUserName = userData['username'] ?? currentUser.email!.split('@')[0];

      // Add current user to friend's list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(currentUser.uid)
          .set({
        'userId': currentUser.uid,
        'username': currentUserName,
        'email': currentUser.email,
        'addedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are now friends with $friendName")),
      );
    } catch (e) {
      Navigator.pop(context); // ensure dialog is closed even if error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error accepting friend request: ${e.toString()}")),
      );
    }
  }


  void _rejectFriendRequest(String requestId, String friendName) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Update request status
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .update({'status': 'rejected'});

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Friend request from $friendName rejected")),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error rejecting friend request: ${e.toString()}")),
      );
    }
  }

  void _removeFriend(String friendId, String friendName) async {
    final currentUser = _authService.currentUser;

    // Show confirmation dialog first
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove Friend"),
        content: Text("Are you sure you want to remove $friendName from your friends?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Remove"),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Remove friend from current user's friend list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('friends')
          .doc(friendId)
          .delete();

      // Remove current user from friend's friend list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(currentUser.uid)
          .delete();

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$friendName has been removed from your friends")),
      );
    } catch (e) {
      Navigator.pop(context); // Ensure the loading dialog is closed

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error removing friend: ${e.toString()}")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFF5252),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search for friends...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          autofocus: true,
        )
            : Text(
          "Friends",
          style: GoogleFonts.pacifico(fontSize: 24, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            color: Colors.white,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: "My Friends"),
            Tab(text: "Requests"),
            Tab(text: "Find Friends"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Friends Tab - Shows all friends of the current user
          _buildMyFriendsTab(),

          // Requests Tab - Shows pending friend requests
          _buildRequestsTab(),

          // Find Friends Tab - Shows users who are not already friends
          _buildFindFriendsTab(),
        ],
      ),
    );
  }

  Widget _buildMyFriendsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final friends = snapshot.data?.docs ?? [];

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "You don't have any friends yet",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  "Go to Find Friends tab to add some friends",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Filter friends if search is active
        final filteredFriends = _searchQuery.isEmpty
            ? friends
            : friends.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['username'] as String).toLowerCase();
          final email = (data['email'] as String).toLowerCase();
          final query = _searchQuery.toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();

        if (filteredFriends.isEmpty) {
          return Center(child: Text("No friends match your search"));
        }

        return ListView.builder(
          padding: EdgeInsets.all(8),
          itemCount: filteredFriends.length,
          itemBuilder: (context, index) {
            final friendData = filteredFriends[index].data() as Map<String, dynamic>;
            final friendId = filteredFriends[index].id;
            final friendName = friendData['username'] as String;
            final friendEmail = friendData['email'] as String;

            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFFF7043),
                  child: Text(
                    friendName[0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(friendName),
                subtitle: Text(friendEmail),
                trailing: IconButton(
                  icon: Icon(Icons.person_remove, color: Colors.grey),
                  onPressed: () => _removeFriend(friendId, friendName),
                ),
                onTap: () {
                  // Can navigate to friend's profile or show albums shared with them
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Viewing shared content coming soon")),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendRequests')
          .where('receiverId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No pending friend requests",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(8),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final requestId = requests[index].id;
            final senderName = requestData['senderName'] as String;
            final senderEmail = requestData['senderEmail'] as String;
            final senderId = requestData['senderId'] as String;

            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFFF7043),
                  child: Text(
                    senderName[0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(senderName),
                subtitle: Text(senderEmail),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () => _acceptFriendRequest(requestId, senderId, senderName, senderEmail),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectFriendRequest(requestId, senderName),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFindFriendsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final allUsers = snapshot.data?.docs ?? [];

        // Get all users except current user
        final otherUsers = allUsers.where((doc) => doc.id != widget.userId).toList();

        if (otherUsers.isEmpty) {
          return Center(child: Text("No other users found"));
        }

        // Stream for getting existing friends to filter them out
        return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('friends')
                .snapshots(),
            builder: (context, friendsSnapshot) {
              // Stream for getting pending requests to avoid duplicates
              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('friendRequests')
                      .where('senderId', isEqualTo: widget.userId)
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, requestsSnapshot) {
                    if (!friendsSnapshot.hasData || !requestsSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final existingFriendIds = friendsSnapshot.data!.docs.map((doc) => doc.id).toSet();

                    final pendingRequestIds = requestsSnapshot.data!.docs
                        .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['receiverId'] as String;
                    })
                        .toSet();

                    // Filter out users who are already friends or have pending requests
                    final availableUsers = otherUsers.where((userDoc) {
                      final userId = userDoc.id;
                      return !existingFriendIds.contains(userId) && !pendingRequestIds.contains(userId);
                    }).toList();

                    // Apply search filter
                    final filteredUsers = _searchQuery.isEmpty
                        ? []
                        : availableUsers.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['username'] != null
                          ? (data['username'] as String).toLowerCase()
                          : '';
                      final email = data['email'] != null
                          ? (data['email'] as String).toLowerCase()
                          : '';
                      final query = _searchQuery.toLowerCase();
                      return name.contains(query) || email.contains(query);
                    }).toList();


                    if (filteredUsers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? "No available users found"
                                  : "No users match your search",
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final userDoc = filteredUsers[index];
                        final userData = userDoc.data() as Map<String, dynamic>;
                        final userId = userDoc.id;
                        final userEmail = userData['email'] as String? ?? 'No email';
                        final userName = userData['username'] as String? ?? userEmail.split('@')[0];

                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(0xFFFF7043),
                              child: Text(
                                userName[0].toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(userName),
                            subtitle: Text(userEmail),
                            trailing: IconButton(
                              icon: Icon(Icons.person_add, color: Color(0xFFFF5252)),
                              onPressed: () => _sendFriendRequest(userId, userName, userEmail),
                            ),
                          ),
                        );
                      },
                    );
                  }
              );
            }
        );
      },
    );
  }
}