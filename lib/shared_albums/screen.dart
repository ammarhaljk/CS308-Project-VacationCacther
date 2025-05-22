import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shared_album_detail.dart';
import 'create_shared_album.dart';

class SharedAlbumsScreen extends StatefulWidget {
  final String userId;

  const SharedAlbumsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _SharedAlbumsScreenState createState() => _SharedAlbumsScreenState();
}

class _SharedAlbumsScreenState extends State<SharedAlbumsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  int _selectedTabIndex = 0;

  // Pagination controls
  static const int _pageSize = 10;
  List<DocumentSnapshot> _myAlbums = [];
  List<DocumentSnapshot> _sharedWithMeAlbums = [];
  bool _hasMoreMyAlbums = true;
  bool _hasMoreSharedAlbums = true;
  DocumentSnapshot? _lastMyAlbumDoc;
  DocumentSnapshot? _lastSharedDoc;
  bool _isLoadingMoreMyAlbums = false;
  bool _isLoadingMoreSharedAlbums = false;

  final ScrollController _myAlbumsScrollController = ScrollController();
  final ScrollController _sharedAlbumsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadSavedTabIndex();

    // Add scroll listeners for pagination
    _myAlbumsScrollController.addListener(_scrollListenerMyAlbums);
    _sharedAlbumsScrollController.addListener(_scrollListenerSharedAlbums);

    // Initial data load
    _loadMyAlbums();
    _loadSharedWithMeAlbums();
  }

  void _scrollListenerMyAlbums() {
    if (_myAlbumsScrollController.position.pixels >=
        _myAlbumsScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMoreMyAlbums && _hasMoreMyAlbums) {
        _loadMoreMyAlbums();
      }
    }
  }

  void _scrollListenerSharedAlbums() {
    if (_sharedAlbumsScrollController.position.pixels >=
        _sharedAlbumsScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMoreSharedAlbums && _hasMoreSharedAlbums) {
        _loadMoreSharedAlbums();
      }
    }
  }

  Future<void> _loadMyAlbums() async {
    if (_isLoadingMoreMyAlbums) return;

    setState(() {
      _isLoadingMoreMyAlbums = true;
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('sharedAlbums')
          .where('creatorId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      var snapshot = await query.get();

      setState(() {
        _myAlbums = snapshot.docs;
        _isLoadingMoreMyAlbums = false;
        _hasMoreMyAlbums = snapshot.docs.length >= _pageSize;

        if (snapshot.docs.isNotEmpty) {
          _lastMyAlbumDoc = snapshot.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMoreMyAlbums = false;
      });
      print('Error loading albums: $e');
    }
  }

  Future<void> _loadMoreMyAlbums() async {
    if (_isLoadingMoreMyAlbums || !_hasMoreMyAlbums || _lastMyAlbumDoc == null) return;

    setState(() {
      _isLoadingMoreMyAlbums = true;
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('sharedAlbums')
          .where('creatorId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastMyAlbumDoc!)
          .limit(_pageSize);

      var snapshot = await query.get();

      setState(() {
        _myAlbums.addAll(snapshot.docs);
        _isLoadingMoreMyAlbums = false;
        _hasMoreMyAlbums = snapshot.docs.length >= _pageSize;

        if (snapshot.docs.isNotEmpty) {
          _lastMyAlbumDoc = snapshot.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMoreMyAlbums = false;
      });
      print('Error loading more albums: $e');
    }
  }

  Future<void> _loadSharedWithMeAlbums() async {
    if (_isLoadingMoreSharedAlbums) return;

    setState(() {
      _isLoadingMoreSharedAlbums = true;
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('sharedAlbums')
          .where('participants', arrayContains: widget.userId)
          .where('creatorId', isNotEqualTo: widget.userId)
          .orderBy('creatorId')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      var snapshot = await query.get();

      setState(() {
        _sharedWithMeAlbums = snapshot.docs;
        _isLoadingMoreSharedAlbums = false;
        _hasMoreSharedAlbums = snapshot.docs.length >= _pageSize;

        if (snapshot.docs.isNotEmpty) {
          _lastSharedDoc = snapshot.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMoreSharedAlbums = false;
      });
      print('Error loading shared albums: $e');
    }
  }

  Future<void> _loadMoreSharedAlbums() async {
    if (_isLoadingMoreSharedAlbums || !_hasMoreSharedAlbums || _lastSharedDoc == null) return;

    setState(() {
      _isLoadingMoreSharedAlbums = true;
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('sharedAlbums')
          .where('participants', arrayContains: widget.userId)
          .where('creatorId', isNotEqualTo: widget.userId)
          .orderBy('creatorId')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastSharedDoc!)
          .limit(_pageSize);

      var snapshot = await query.get();

      setState(() {
        _sharedWithMeAlbums.addAll(snapshot.docs);
        _isLoadingMoreSharedAlbums = false;
        _hasMoreSharedAlbums = snapshot.docs.length >= _pageSize;

        if (snapshot.docs.isNotEmpty) {
          _lastSharedDoc = snapshot.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMoreSharedAlbums = false;
      });
      print('Error loading more shared albums: $e');
    }
  }

  Future<void> _loadSavedTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('sharedAlbumsTabIndex') ?? 0;
    setState(() {
      _selectedTabIndex = savedIndex;
      _tabController.index = savedIndex;
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });

      // Save tab index for next time
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('sharedAlbumsTabIndex', _tabController.index);
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _myAlbumsScrollController.dispose();
    _sharedAlbumsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'Shared Albums',
          style: GoogleFonts.pacifico(fontSize: 24, color: Colors.white),
        ),
        backgroundColor: Color(0xFFFF5252),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Created by Me'),
            Tab(text: 'Shared with Me'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // "Created by Me" tab with buttons
          Stack(
            children: [
              _buildMyAlbumsList(),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: _buildActionButtons(),
              ),
            ],
          ),

          // "Shared with Me" tab (no buttons)
          _buildSharedWithMeList(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Delete Album Button
        FloatingActionButton(
          heroTag: "deleteBtn",
          backgroundColor: Color(0xFFFF5252),
          onPressed: () {
            _showDeleteAlbumDialog();
          },
          child: Icon(Icons.delete, color: Colors.white),
        ),
        SizedBox(width: 16),
        // Create Album Button
        FloatingActionButton(
          heroTag: "createBtn",
          backgroundColor: Color(0xFFFF5252),
          onPressed: () => _navigateToCreateSharedAlbum(context),
          child: Icon(Icons.add, color: Colors.white),
        ),

      ],
    );
  }

  void _showDeleteAlbumDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Delete Album"),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sharedAlbums')
                  .where('creatorId', isEqualTo: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading albums"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final albums = snapshot.data?.docs ?? [];

                if (albums.isEmpty) {
                  return Center(child: Text("No albums to delete"));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: albums.length,
                  itemBuilder: (context, index) {
                    final albumData = albums[index].data() as Map<String, dynamic>;
                    final albumName = albumData['name'] ?? 'Unnamed Album';
                    final albumId = albums[index].id;

                    return ListTile(
                      leading: Icon(Icons.photo_album),
                      title: Text(albumName),
                      onTap: () {
                        Navigator.of(context).pop();
                        _deleteAlbum(albumId, albumName);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAlbum(String albumId, String albumName) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$albumName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmDelete) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all photos in the album - using 'images' collection as per security rules
      final photosSnapshot = await FirebaseFirestore.instance
          .collection('sharedAlbums')
          .doc(albumId)
          .collection('images')
          .get();

      // Create a batch to delete all photos and the album
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Add photo deletes to batch
      for (var photoDoc in photosSnapshot.docs) {
        batch.delete(photoDoc.reference);
      }

      // Add album delete to batch
      batch.delete(FirebaseFirestore.instance.collection('sharedAlbums').doc(albumId));

      // Commit the batch
      await batch.commit();

      // Refresh album list
      _loadMyAlbums();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Album deleted successfully')),
      );
    } catch (e) {
      print('Error deleting album: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete album')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMyAlbumsList() {
    if (_isLoadingMoreMyAlbums && _myAlbums.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    if (_myAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_album_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No albums created yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _myAlbumsScrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100), // Add padding at bottom for buttons
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _myAlbums.length + (_hasMoreMyAlbums ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _myAlbums.length) {
          return Center(child: CircularProgressIndicator());
        }

        final album = _myAlbums[index];
        final albumData = album.data() as Map<String, dynamic>;
        return _buildAlbumCard(album.id, albumData, true);
      },
    );
  }

  Widget _buildSharedWithMeList() {
    if (_isLoadingMoreSharedAlbums && _sharedWithMeAlbums.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    if (_sharedWithMeAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_album_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No albums shared with you',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _sharedAlbumsScrollController,
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _sharedWithMeAlbums.length + (_hasMoreSharedAlbums ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _sharedWithMeAlbums.length) {
          return Center(child: CircularProgressIndicator());
        }

        final album = _sharedWithMeAlbums[index];
        final albumData = album.data() as Map<String, dynamic>;
        return _buildAlbumCard(album.id, albumData, false);
      },
    );
  }

  Widget _buildAlbumCard(String albumId, Map<String, dynamic> albumData, bool isOwner) {
    final String albumName = albumData['name'] ?? 'Unnamed Album';
    final String coverImageUrl = albumData['coverImageUrl'] ?? '';
    final int participantCount = albumData['participants']?.length ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SharedAlbumDetailScreen(
              albumId: albumId,
              albumName: albumName,
              userId: widget.userId,
              isOwner: isOwner,
            ),
          ),
        );
      },
      child: Hero(
        tag: 'album_$albumId',  // Add hero animation
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: coverImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: coverImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.broken_image,
                        size: 48,
                        color: Colors.grey[600],
                      ),
                    ),
                    memCacheWidth: 300,
                  )
                      : Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.photo_library,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      albumName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          '$participantCount ${participantCount == 1 ? 'person' : 'people'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCreateSharedAlbum(BuildContext context) async {
    // Wait for the navigation to complete
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSharedAlbumScreen(userId: widget.userId),
      ),
    );

    // Refresh albums when returning from create screen
    _loadMyAlbums();
  }
}