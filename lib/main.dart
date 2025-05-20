import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'auth_screens.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:io';
import 'storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'menu_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug);
  runApp(VacationCatcher());

}

class VacationCatcher extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFFFF7043),
        scaffoldBackgroundColor: Color(0xFFF8F9FA), // Lighter, cleaner white shade
      ),
      home: AuthStateWrapper(),
    );
  }
}

class AuthStateWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return AuthWrapper();
          }
          // Return MenuScreen instead of AlbumScreen
          return MenuScreen(userId: user.uid);
        }

        // While waiting for connection to establish
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                SizedBox(height: 32),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AlbumScreen extends StatefulWidget {
  final String userId;

  AlbumScreen({required this.userId});

  @override
  _AlbumScreenState createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  // Add StorageService instance
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  TextEditingController albumController = TextEditingController();
  String userName = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadAlbums();
  }

  void _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('username') ?? 'User';
    });
  }

  // Load albums from Firestore
  void _loadAlbums() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Reset loading state when done
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading albums: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void createAlbum() async {
    if (albumController.text.isNotEmpty) {
      try {
        // Create album in Firebase
        await _storageService.createAlbum(albumController.text);

        // Reset the text field
        albumController.clear();

        // Refresh the album list
        _loadAlbums();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Album created successfully")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating album: ${e.toString()}")),
        );
      }
    }
  }

  void deleteAlbum(String albumName) async {
    try {
      await _storageService.deleteAlbum(albumName);

      // Refresh the album list
      _loadAlbums();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Album deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting album: ${e.toString()}")),
      );
    }
  }

  void openAlbum(String albumName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen(
          albumName: albumName,
          storageService: _storageService,
          onAlbumRenamed: (newName) {
            // Refresh the album list after rename
            _loadAlbums();
          },
        ),
      ),
    );
  }

  void _signOut() async {
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
            icon: Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              _showUserProfileDialog();
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: _storageService.getAlbums(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error loading albums: ${snapshot.error}"),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
              ),
            );
          }

          final albums = snapshot.data?.docs ?? [];

          if (albums.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_album, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No albums yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Tap + to create a new album",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                final albumName = album.id;

                return GestureDetector(
                  onTap: () => openAlbum(albumName),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            // Album thumbnail display
                            child: AlbumThumbnail(
                              albumName: albumName,
                              storageService: _storageService,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  albumName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: _storageService.getAlbumImages(albumName),
                                builder: (context, snapshot) {
                                  int count = snapshot.data?.docs.length ?? 0;
                                  return Text(
                                    "$count photos",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: "deleteBtn",
            backgroundColor: Color(0xFFFF5252),
            onPressed: () {
              // Show delete album dialog
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text("Delete Album"),
                    content: Container(
                      width: double.maxFinite,
                      height: 300,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _storageService.getAlbums(),
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
                              final albumName = albums[index].id;
                              return ListTile(
                                leading: Icon(Icons.photo_album),
                                title: Text(albumName),
                                onTap: () {
                                  Navigator.pop(context);
                                  deleteAlbum(albumName);
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
                          Navigator.pop(context);
                        },
                        child: Text("Cancel"),
                      ),
                    ],
                  );
                },
              );
            },
            child: Icon(Icons.delete, color: Colors.white),
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            heroTag: "addBtn",
            backgroundColor: Color(0xFFFF5252),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text("Create Album"),
                    content: TextField(
                      controller: albumController,
                      decoration: InputDecoration(hintText: "Enter Album Name"),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          createAlbum();
                          Navigator.pop(context);
                        },
                        child: Text("Create"),
                      ),
                    ],
                  );
                },
              );
            },
            child: Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showUserProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<QuerySnapshot>(
        stream: _storageService.getAlbums(),
        builder: (context, albumsSnapshot) {
          int albumCount = albumsSnapshot.data?.docs.length ?? 0;
          int photoCount = 0;

          // Count photos across all albums
          if (albumsSnapshot.hasData) {
            for (var album in albumsSnapshot.data!.docs) {
              String albumName = album.id;
              // We'll use a FutureBuilder inside StreamBuilder to get photo counts
              return FutureBuilder<QuerySnapshot>(
                future: _storageService.getAlbumImages(albumName).first,
                builder: (context, photosSnapshot) {
                  if (photosSnapshot.hasData) {
                    photoCount += photosSnapshot.data!.docs.length;
                  }

                  // Now build the actual dialog
                  return AlertDialog(
                    title: Text("Profile"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Color(0xFFFF7043),
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: TextStyle(fontSize: 30, color: Colors.white),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          userName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _authService.currentUser?.email ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Albums: $albumCount"),
                            Text("Photos: $photoCount"),
                          ],
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text("Close"),
                      ),
                    ],
                  );
                },
              );
            }
          }

          // Default if no data yet
          return AlertDialog(
            title: Text("Profile"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFFF7043),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: TextStyle(fontSize: 30, color: Colors.white),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  userName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  _authService.currentUser?.email ?? '',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Albums: 0"),
                    Text("Photos: 0"),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("Close"),
              ),
            ],
          );
        },
      ),
    );
  }
}

// New widget for album thumbnails
class AlbumThumbnail extends StatelessWidget {
  final String albumName;
  final StorageService storageService;

  AlbumThumbnail({required this.albumName, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: storageService.getAlbumImages(albumName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Color(0xFFFFCCBC),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
              ),
            ),
          );
        }

        final images = snapshot.data?.docs ?? [];

        if (images.isEmpty) {
          return Container(
            color: Color(0xFFFFCCBC),
            child: Icon(
              Icons.photo_album,
              size: 64,
              color: Color(0xFFFFAB91),
            ),
          );
        }

        // Get first image URL to use as thumbnail
        final firstImage = images.first.data() as Map<String, dynamic>;
        final imageUrl = firstImage['url'] as String;

        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Color(0xFFFFCCBC),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFAB91)),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Color(0xFFFFCCBC),
            child: Icon(
              Icons.broken_image,
              size: 64,
              color: Color(0xFFFFAB91),
            ),
          ),
        );
      },
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final StorageService storageService;
  final Function(String) onAlbumRenamed;

  AlbumDetailScreen({
    required this.albumName,
    required this.storageService,
    required this.onAlbumRenamed,
  });

  @override
  _AlbumDetailScreenState createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  bool isEditMode = false;
  String currentAlbumName = "";
  List<String> selectedImageIds = [];
  TextEditingController albumNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentAlbumName = widget.albumName;
    albumNameController.text = currentAlbumName;
  }

  Future<void> pickImage() async {
    try {
      // Improved image picking with quality/size configuration
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Slightly compress images for better performance
        maxWidth: 1200, // Limit maximum dimensions to improve performance
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        try {
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text("Uploading image..."),
                    ],
                  ),
                ),
              );
            },
          );

          // Upload image to Firebase
          await widget.storageService.uploadImage(
            File(pickedFile.path),
            currentAlbumName,
          );

          // Close loading dialog
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Image uploaded successfully")),
          );
        } catch (e) {
          // Close loading dialog
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error uploading image: ${e.toString()}")),
          );
        }
      }
    } catch (e) {
      // Handle errors when picking images
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting image: ${e.toString()}")),
      );
    }
  }

  void viewImage(List<Map<String, dynamic>> images, int index) {
    if (isEditMode) {
      toggleImageSelection(images[index]['id']);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FirebaseImageViewerScreen(
            images: images,
            initialIndex: index,
          ),
        ),
      );
    }
  }

  void toggleImageSelection(String imageId) {
    setState(() {
      if (selectedImageIds.contains(imageId)) {
        selectedImageIds.remove(imageId);
      } else {
        selectedImageIds.add(imageId);
      }
    });
  }

  void deleteSelectedImages(List<Map<String, dynamic>> allImages) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Deleting images..."),
                ],
              ),
            ),
          );
        },
      );

      // Delete all selected images
      for (String imageId in selectedImageIds) {
        // Find the image data with this ID
        final imageData = allImages.firstWhere((img) => img['id'] == imageId);

        // Delete the image
        await widget.storageService.deleteImage(
          currentAlbumName,
          imageId,
          imageData['storagePath'],
        );
      }

      // Clear selection after deletion
      setState(() {
        selectedImageIds.clear();
      });

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Images deleted successfully")),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting images: ${e.toString()}")),
      );
    }
  }

  void toggleEditMode() {
    setState(() {
      isEditMode = !isEditMode;
      if (!isEditMode) {
        selectedImageIds.clear();
      }
    });
  }

  void editAlbumName() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Rename Album"),
          content: TextField(
            controller: albumNameController,
            decoration: InputDecoration(hintText: "Enter New Album Name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                if (albumNameController.text.isNotEmpty &&
                    albumNameController.text != currentAlbumName) {
                  try {
                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Dialog(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 20),
                                Text("Renaming album..."),
                              ],
                            ),
                          ),
                        );
                      },
                    );

                    // Rename the album in Firebase
                    await widget.storageService.renameAlbum(
                      currentAlbumName,
                      albumNameController.text,
                    );

                    // Close the loading dialog
                    Navigator.pop(context);

                    // Update state
                    setState(() {
                      currentAlbumName = albumNameController.text;
                    });

                    // Notify parent
                    widget.onAlbumRenamed(currentAlbumName);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Album renamed successfully")),
                    );
                  } catch (e) {
                    // Close the loading dialog
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error renaming album: ${e.toString()}")),
                    );
                  }
                }
                Navigator.pop(context);
              },
              child: Text("Rename"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(currentAlbumName, style: GoogleFonts.pacifico(fontSize: 20, color: Colors.white)),
          backgroundColor: Color(0xFFFF5252),
          actions: [
            IconButton(
              icon: Icon(isEditMode ? Icons.check : Icons.edit, color: Colors.white),
              onPressed: toggleEditMode,
            ),
            if (isEditMode)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'rename') {
                    editAlbumName();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'rename',
                    child: Text('Rename Album'),
                  ),
                ],
              ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
        stream: widget.storageService.getAlbumImages(currentAlbumName),
    builder: (context, snapshot) {
    if (snapshot.hasError) {
    return Center(child: Text("Error: ${snapshot.error}"));
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
    return Center(child: CircularProgressIndicator());
    }

    final docs = snapshot.data?.docs ?? [];

    if (docs.isEmpty) {
    return Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(Icons.photo_library, size: 64, color: Colors.grey),
    SizedBox(height: 16),
    Text(
    "No photos yet",
    style: TextStyle(fontSize: 18, color: Colors.grey),
    ),
    SizedBox(height: 8),
    Text(
    "Tap + to add photos to this album",
    style: TextStyle(color: Colors.grey),
    ),
    ],
    ),
    );
    }

    // Convert QueryDocumentSnapshot to List of Maps with needed data
    List<Map<String, dynamic>> images = docs.map((doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return {
    'id': doc.id,
    'url': data['url'],
    'storagePath': data['storagePath'],
    'createdAt': data['createdAt'],
    'fileName': data['fileName']
    };
    }).toList();

    return Column(
    children: [
    if (isEditMode && selectedImageIds.isNotEmpty)
    Container(
    color: Color(0xFFFFECB3),
    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${selectedImageIds.length} selected",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          icon: Icon(Icons.delete, color: Colors.white),
          label: Text("Delete", style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Delete Images"),
                content: Text("Are you sure you want to delete ${selectedImageIds.length} image(s)?"),
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
                      deleteSelectedImages(images);
                    },
                    child: Text("Delete"),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
    ),
      Expanded(
        child: GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final imageData = images[index];
            final isSelected = selectedImageIds.contains(imageData['id']);

            return GestureDetector(
              onTap: () => viewImage(images, index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageData['url'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Color(0xFFFFCCBC),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Color(0xFFFFCCBC),
                        child: Icon(Icons.broken_image, color: Colors.white),
                      ),
                    ),
                  ),
                  // Selection overlay
                  if (isEditMode)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Color(0xFFFF5252) : Colors.white.withOpacity(0.7),
                        ),
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          isSelected ? Icons.check : Icons.circle_outlined,
                          size: 20,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
    );
    },
        ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFFF5252),
        onPressed: isEditMode ? null : pickImage,
        child: Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }
}

class FirebaseImageViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  FirebaseImageViewerScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  _FirebaseImageViewerScreenState createState() => _FirebaseImageViewerScreenState();
}

class _FirebaseImageViewerScreenState extends State<FirebaseImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _getImageDetails(Map<String, dynamic> imageData) {
    // Format the timestamp if available
    String dateInfo = '';
    if (imageData['createdAt'] != null) {
      final timestamp = imageData['createdAt'] as Timestamp;
      final date = timestamp.toDate();
      dateInfo = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Get the filename or default to 'Photo'
    String fileName = imageData['fileName'] ?? 'Photo';

    return '$fileName\n$dateInfo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Image viewer
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.images.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(widget.images[index]['url']),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  heroAttributes: PhotoViewHeroAttributes(tag: widget.images[index]['id']),
                );
              },
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                ),
              ),
              backgroundDecoration: BoxDecoration(color: Colors.black),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),

            // Controls overlay
            if (_showControls)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Column(
                    children: [
                      // Top bar
                      SafeArea(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                              Expanded(
                                child: Text(
                                  '${_currentIndex + 1} / ${widget.images.length}',
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.share, color: Colors.white),
                                onPressed: () {
                                  // Share feature can be implemented here
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Share feature not implemented yet")),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      Spacer(),

                      // Bottom info
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        child: Text(
                          _getImageDetails(widget.images[_currentIndex]),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SafeArea(
                        top: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.download, color: Colors.white),
                              onPressed: () {
                                // Download feature can be implemented here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Download feature not implemented yet")),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.white),
                              onPressed: () {
                                // Delete feature can be implemented here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Delete feature accessible from album view")),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}