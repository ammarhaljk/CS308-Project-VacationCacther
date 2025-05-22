import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this import
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Add this import
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart' as path_provider; // Add this import

class SharedAlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final String albumName;
  final String userId;
  final bool isOwner;

  const SharedAlbumDetailScreen({
    Key? key,
    required this.albumId,
    required this.albumName,
    required this.userId,
    required this.isOwner,
  }) : super(key: key);

  @override
  _SharedAlbumDetailScreenState createState() => _SharedAlbumDetailScreenState();
}

class _SharedAlbumDetailScreenState extends State<SharedAlbumDetailScreen> {
  bool _isLoading = false;
  bool _isUploadingImage = false;

  // Pagination controls
  static const int _pageSize = 30;
  List<DocumentSnapshot> _images = [];
  bool _hasMoreImages = true;
  DocumentSnapshot? _lastImageDoc;
  bool _isLoadingMoreImages = false;
  final ScrollController _scrollController = ScrollController();

  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _albumData;
  List<Map<String, dynamic>> _participants = [];
  String _albumCreatorId = '';

  @override
  void initState() {
    super.initState();
    _loadAlbumData();
    _loadInitialImages();

    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMoreImages && _hasMoreImages) {
        _loadMoreImages();
      }
    }
  }

  Future<void> _loadInitialImages() async {
    if (_isLoadingMoreImages) return;

    setState(() {
      _isLoadingMoreImages = true;
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('sharedAlbums')
          .doc(widget.albumId)
          .collection('images')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      var snapshot = await query.get();

      setState(() {
        _images = snapshot.docs;
        _isLoadingMoreImages = false;
        _hasMoreImages = snapshot.docs.length >= _pageSize;

        if (snapshot.docs.isNotEmpty) {
          _lastImageDoc = snapshot.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMoreImages = false;
      });
      print('Error loading images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading images: $e')),
      );
    }
  }

  Future<void> _loadMoreImages() async {
    if (_isLoadingMoreImages || !_hasMoreImages || _lastImageDoc == null) return;

    setState(() {
      _isLoadingMoreImages = true;
    });

    try {
      var query = FirebaseFirestore.instance
          .collection('sharedAlbums')
          .doc(widget.albumId)
          .collection('images')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastImageDoc!)
          .limit(_pageSize);

      var snapshot = await query.get();

      setState(() {
        _images.addAll(snapshot.docs);
        _isLoadingMoreImages = false;
        _hasMoreImages = snapshot.docs.length >= _pageSize;

        if (snapshot.docs.isNotEmpty) {
          _lastImageDoc = snapshot.docs.last;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMoreImages = false;
      });
      print('Error loading more images: $e');
    }
  }

  Future<void> _loadAlbumData() async {
    try {
      final albumDoc = await FirebaseFirestore.instance
          .collection('sharedAlbums')
          .doc(widget.albumId)
          .get();

      if (albumDoc.exists) {
        final data = albumDoc.data() as Map<String, dynamic>;
        setState(() {
          _albumData = data;
          _albumCreatorId = data['creatorId'] ?? '';
        });

        // Load participant details in a batch to avoid multiple network requests
        if (_albumData != null && _albumData!['participants'] != null) {
          List<dynamic> participantIds = _albumData!['participants'];
          List<Future<DocumentSnapshot>> futures = [];

          // Create futures for all participant documents
          for (String userId in participantIds) {
            futures.add(FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get());
          }

          // Wait for all futures to complete
          final results = await Future.wait(futures);

          List<Map<String, dynamic>> participants = [];
          for (int i = 0; i < results.length; i++) {
            final userDoc = results[i];
            final userId = participantIds[i];

            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              participants.add({
                'id': userId,
                'name': userData['username'] ?? 'Unknown User',
                'photoUrl': userData['photoUrl'] ?? '',
                'email': userData['email'] ?? '',
                'isCreator': userId == _albumCreatorId,
              });
            }
          }

          setState(() {
            _participants = participants;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading album data: $e')),
      );
    }
  }

  Future<File?> _compressImage(File file) async {
    final dir = await path_provider.getTemporaryDirectory();

    // Create a unique target path by adding a prefix or timestamp to avoid path conflicts
    String targetPath = "${dir.absolute.path}/compressed_${path.basename(file.path)}";

    // Ensure the paths are different
    if (file.absolute.path == targetPath) {
      // If somehow paths are still the same, modify the target path further
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      targetPath = "${dir.absolute.path}/compressed_${timestamp}_${path.basename(file.path)}";
    }

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 1024, // Set a reasonable max width
      minHeight: 1024, // Set a reasonable max height
    );

    return result != null ? File(result.path) : null;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Reduce image quality at source
      );

      if (pickedFile == null) {
        return;
      }

      setState(() {
        _isUploadingImage = true;
      });

      File imageFile = File(pickedFile.path);

      // Compress the image before uploading
      File? compressedFile = await _compressImage(imageFile);
      if (compressedFile != null) {
        imageFile = compressedFile;
      }

      String fileName = '${Uuid().v4()}${path.extension(pickedFile.path)}';

      // Create upload metadata (helps with caching)
      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // Force JPEG for consistency
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
      );

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('sharedAlbums')
          .child(widget.albumId)
          .child(fileName);

      // Upload file with metadata
      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        // You could update a progress indicator here
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('sharedAlbums')
          .doc(widget.albumId)
          .collection('images')
          .add({
        'url': downloadUrl,
        'fileName': fileName,
        'uploadedBy': widget.userId,
        'createdAt': FieldValue.serverTimestamp(),
        'thumbnail': downloadUrl, // Use same URL for now, but in production you'd have a separate thumbnail
        'size': imageFile.lengthSync(), // Store file size
      });

      // Update album cover if this is the first image
      if (_albumData != null && (_albumData!['coverImageUrl'] == null || _albumData!['coverImageUrl'] == '')) {
        await FirebaseFirestore.instance
            .collection('sharedAlbums')
            .doc(widget.albumId)
            .update({
          'coverImageUrl': downloadUrl,
        });
      }

      setState(() {
        _isUploadingImage = false;
      });

      // Refresh image list instead of updating just one item
      _loadInitialImages();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image uploaded successfully')),
      );

    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  Future<void> _showParticipantsDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Album Participants'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _participants.length,
            itemBuilder: (context, index) {
              final participant = _participants[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: participant['photoUrl'].isNotEmpty
                      ? CachedNetworkImageProvider(participant['photoUrl'])
                      : null,
                  child: participant['photoUrl'].isEmpty ? Icon(Icons.person) : null,
                ),
                title: Text(participant['name']),
                subtitle: Text(participant['email']),
                trailing: participant['isCreator']
                    ? Chip(
                  label: Text('Creator'),
                  backgroundColor: Color(0xFFFF5252),
                  labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_isLoadingMoreImages && _images.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No photos in this album yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isUploadingImage ? null : _pickAndUploadImage,
              icon: Icon(Icons.add_a_photo),
              label: Text('Add Photos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF5252),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _images.length + (_hasMoreImages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _images.length) {
          return Center(child: CircularProgressIndicator());
        }

        final image = _images[index];
        final imageData = image.data() as Map<String, dynamic>;
        final String imageUrl = imageData['url'] ?? '';
        final String uploaderId = imageData['uploadedBy'] ?? '';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenImageView(
                  imageUrl: imageUrl,
                  imageId: image.id,
                  albumId: widget.albumId,
                  uploaderId: uploaderId,
                  currentUserId: widget.userId,
                  isAlbumOwner: widget.isOwner,
                ),
              ),
            );
          },
          child: Hero(
            tag: image.id,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.broken_image, color: Colors.grey[600]),
                ),
                memCacheWidth: 300, // Limit memory cache size
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.albumName,
          style: GoogleFonts.pacifico(fontSize: 24, color: Colors.white),
        ),
        backgroundColor: Color(0xFFFF5252),
        actions: [
          IconButton(
            icon: Icon(Icons.people, color: Colors.white),
            onPressed: _showParticipantsDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildImageGrid(),

          // Show upload progress overlay
          if (_isUploadingImage)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Uploading image...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploadingImage ? null : _pickAndUploadImage,
        backgroundColor: _isUploadingImage ? Colors.grey : Color(0xFFFF5252),
        child: _isUploadingImage
            ? CircularProgressIndicator(color: Colors.white)
            : Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
}

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String imageId;
  final String albumId;
  final String uploaderId;
  final String currentUserId;
  final bool isAlbumOwner;

  const FullScreenImageView({
    Key? key,
    required this.imageUrl,
    required this.imageId,
    required this.albumId,
    required this.uploaderId,
    required this.currentUserId,
    required this.isAlbumOwner,
  }) : super(key: key);

  Future<void> _deleteImage(BuildContext context) async {
    // Only allow delete if user is album owner or the uploader
    if (isAlbumOwner || uploaderId == currentUserId) {
      // Show confirmation dialog
      bool confirmDelete = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Image'),
          content: Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ) ?? false;

      if (confirmDelete) {
        try {
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(child: CircularProgressIndicator()),
          );

          // Get the document to retrieve the file path
          final docSnapshot = await FirebaseFirestore.instance
              .collection('sharedAlbums')
              .doc(albumId)
              .collection('images')
              .doc(imageId)
              .get();

          final data = docSnapshot.data();
          String? fileName = data?['fileName'];

          // Delete from Firestore
          await FirebaseFirestore.instance
              .collection('sharedAlbums')
              .doc(albumId)
              .collection('images')
              .doc(imageId)
              .delete();

          // Also delete the file from Storage if we have the filename
          if (fileName != null) {
            try {
              await FirebaseStorage.instance
                  .ref()
                  .child('sharedAlbums')
                  .child(albumId)
                  .child(fileName)
                  .delete();
            } catch (storageError) {
              print("Error deleting from storage: $storageError");
              // Continue even if storage delete fails
            }
          }

          // Dismiss loading indicator
          Navigator.pop(context);

          // Navigate back to album
          Navigator.pop(context, true); // Pass 'true' to indicate deletion occurred

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image deleted successfully')),
          );
        } catch (e) {
          // Dismiss loading indicator if visible
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting image: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You don\'t have permission to delete this image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _deleteImage(context),
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: imageId,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 3,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}