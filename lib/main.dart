import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

void main() {
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
      home: AlbumScreen(),
    );
  }
}

class AlbumScreen extends StatefulWidget {
  @override
  _AlbumScreenState createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<String> albums = [];
  Map<String, List<File>> albumImages = {};
  final ImagePicker _picker = ImagePicker();
  TextEditingController albumController = TextEditingController();

  void createAlbum() {
    if (albumController.text.isNotEmpty) {
      setState(() {
        albums.add(albumController.text);
        albumImages[albumController.text] = [];
        albumController.clear();
      });
    }
  }

  void deleteAlbum(String albumName) {
    setState(() {
      albums.remove(albumName);
      albumImages.remove(albumName);
    });
  }

  void openAlbum(String albumName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen(
          albumName: albumName,
          images: albumImages[albumName]!,
          onImagesUpdated: (updatedImages) {
            setState(() {
              albumImages[albumName] = updatedImages;
            });
          },
          onAlbumRenamed: (newName) {
            setState(() {
              List<File> images = albumImages[albumName]!;
              albums[albums.indexOf(albumName)] = newName;
              albumImages.remove(albumName);
              albumImages[newName] = images;
            });
          },
        ),
      ),
    );
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => openAlbum(albums[index]),
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
                        child: albumImages[albums[index]]!.isNotEmpty
                            ? OptimizedImageWidget(file: albumImages[albums[index]]![0])
                            : Container(
                          color: Color(0xFFFFCCBC),
                          child: Icon(
                            Icons.photo_album,
                            size: 64,
                            color: Color(0xFFFFAB91),
                          ),
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
                              albums[index],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${albumImages[albums[index]]!.length} photos",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: "deleteBtn",
            backgroundColor: Color(0xFFFF5252),
            onPressed: () {
              if (albums.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("No albums to delete")),
                );
                return;
              }

              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text("Delete Album"),
                    content: Container(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: Icon(Icons.photo_album),
                            title: Text(albums[index]),
                            subtitle: Text("${albumImages[albums[index]]!.length} photos"),
                            onTap: () {
                              deleteAlbum(albums[index]);
                              Navigator.pop(context);
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
}

// Optimized image widget to handle large images
class OptimizedImageWidget extends StatelessWidget {
  final File file;
  final BoxFit fit;

  OptimizedImageWidget({
    required this.file,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(
      file,
      fit: fit,
      cacheWidth: 300, // Limit image cache size for better performance
      cacheHeight: 300,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[200],
          child: Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: frame != null
              ? child
              : Container(
            color: Colors.grey[100],
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final List<File> images;
  final Function(List<File>) onImagesUpdated;
  final Function(String) onAlbumRenamed;

  AlbumDetailScreen({
    required this.albumName,
    required this.images,
    required this.onImagesUpdated,
    required this.onAlbumRenamed,
  });

  @override
  _AlbumDetailScreenState createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  bool isEditMode = false;
  String currentAlbumName = "";
  List<int> selectedImages = [];
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
        setState(() {
          widget.images.add(File(pickedFile.path));
          widget.onImagesUpdated(widget.images);
        });
      }
    } catch (e) {
      // Handle errors when picking images
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding image: ${e.toString()}")),
      );
    }
  }

  void viewImage(int index) {
    if (isEditMode) {
      toggleImageSelection(index);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(images: widget.images, index: index),
        ),
      );
    }
  }

  void toggleImageSelection(int index) {
    setState(() {
      if (selectedImages.contains(index)) {
        selectedImages.remove(index);
      } else {
        selectedImages.add(index);
      }
    });
  }

  void deleteSelectedImages() {
    setState(() {
      selectedImages.sort((a, b) => b.compareTo(a)); // Sort in descending order
      for (var index in selectedImages) {
        widget.images.removeAt(index);
      }
      widget.onImagesUpdated(widget.images);
      selectedImages.clear();
    });
  }

  void toggleEditMode() {
    setState(() {
      isEditMode = !isEditMode;
      if (!isEditMode) {
        selectedImages.clear();
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
              onPressed: () {
                if (albumNameController.text.isNotEmpty) {
                  setState(() {
                    currentAlbumName = albumNameController.text;
                    widget.onAlbumRenamed(currentAlbumName);
                  });
                  Navigator.pop(context);
                }
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
                } else if (value == 'deleteSelected' && selectedImages.isNotEmpty) {
                  deleteSelectedImages();
                } else if (value == 'selectAll') {
                  setState(() {
                    selectedImages = List.generate(widget.images.length, (index) => index);
                  });
                } else if (value == 'deselectAll') {
                  setState(() {
                    selectedImages.clear();
                  });
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: Text('Rename Album'),
                ),
                const PopupMenuItem<String>(
                  value: 'deleteSelected',
                  child: Text('Delete Selected'),
                ),
                const PopupMenuItem<String>(
                  value: 'selectAll',
                  child: Text('Select All'),
                ),
                const PopupMenuItem<String>(
                  value: 'deselectAll',
                  child: Text('Deselect All'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (isEditMode && selectedImages.isNotEmpty)
            Container(
              color: Color(0xFFFFECB3),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${selectedImages.length} selected",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.delete, color: Color(0xFFFF5252)),
                    label: Text("Delete", style: TextStyle(color: Color(0xFFFF5252))),
                    onPressed: deleteSelectedImages,
                  ),
                ],
              ),
            ),
          Expanded(
            child: widget.images.isEmpty
                ? Center(
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
            )
                : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => viewImage(index),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: OptimizedImageWidget(file: widget.images[index]),
                      ),
                      if (isEditMode)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: selectedImages.contains(index)
                                  ? Color(0xFFFF5252)
                                  : Colors.white.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: selectedImages.contains(index)
                                  ? Icon(Icons.check, size: 16, color: Colors.white)
                                  : Icon(Icons.circle_outlined, size: 16, color: Colors.grey),
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
      ),
      floatingActionButton: isEditMode
          ? null
          : FloatingActionButton(
        backgroundColor: Color(0xFFFFAB40),
        onPressed: pickImage,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class ImageViewerScreen extends StatefulWidget {
  final List<File> images;
  final int index;

  ImageViewerScreen({required this.images, required this.index});

  @override
  _ImageViewerScreenState createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late int currentIndex;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.index;
    pageController = PageController(initialPage: widget.index);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
          title: Text(
            "Photo ${currentIndex + 1} of ${widget.images.length}",
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: PhotoViewGallery.builder(
          itemCount: widget.images.length,
          scrollPhysics: BouncingScrollPhysics(),
          builder: (context, i) {
            return PhotoViewGalleryPageOptions(
              imageProvider: FileImage(widget.images[i]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white, size: 48),
                        SizedBox(height: 16),
                        Text(
                          "Failed to load image",
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          pageController: pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (index) {
            setState(() {
              currentIndex = index;
            });
          },
          loadingBuilder: (context, event) {
            return Container(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                  value: event == null || event.expectedTotalBytes == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}