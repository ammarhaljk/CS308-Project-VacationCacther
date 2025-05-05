import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = Uuid();

  // Get the current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Upload an image to Firebase Storage and save metadata in Firestore
  Future<String> uploadImage(File imageFile, String albumName) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      print('Preparing upload...');
      String fileName = '${_uuid.v4()}${path.extension(imageFile.path)}';
      String storagePath = 'users/$currentUserId/albums/$albumName/$fileName';

      print('Uploading file to $storagePath');
      UploadTask uploadTask = _storage.ref(storagePath).putFile(imageFile);

      TaskSnapshot snapshot = await uploadTask;
      print('Upload completed. Getting download URL...');

      String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');

      print('Saving metadata to Firestore...');
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(albumName)
          .collection('images')
          .add({
        'url': downloadUrl,
        'storagePath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'fileName': fileName
      });

      print('Image metadata saved.');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }


  // Create a new album in Firestore
  Future<void> createAlbum(String albumName) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(albumName)
          .set({
        'name': albumName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating album: $e');
      throw e;
    }
  }

  // Get all albums for the current user
  Stream<QuerySnapshot> getAlbums() {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('albums')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get images for a specific album
  Stream<QuerySnapshot> getAlbumImages(String albumName) {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('albums')
        .doc(albumName)
        .collection('images')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Delete an image from Storage and Firestore
  Future<void> deleteImage(String albumName, String imageId, String storagePath) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(albumName)
          .collection('images')
          .doc(imageId)
          .delete();

      // Delete from Storage
      await _storage.ref(storagePath).delete();
    } catch (e) {
      print('Error deleting image: $e');
      throw e;
    }
  }

  // Delete an album (including all images)
  Future<void> deleteAlbum(String albumName) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get all images in the album
      QuerySnapshot imagesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(albumName)
          .collection('images')
          .get();

      // Delete each image from Storage and Firestore
      for (var doc in imagesSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String storagePath = data['storagePath'];

        // Delete from Storage
        await _storage.ref(storagePath).delete();

        // Delete from Firestore
        await doc.reference.delete();
      }

      // Delete the album document
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(albumName)
          .delete();
    } catch (e) {
      print('Error deleting album: $e');
      throw e;
    }
  }

  // Rename an album
  Future<void> renameAlbum(String oldName, String newName) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get the old album document
      DocumentSnapshot albumDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(oldName)
          .get();

      Map<String, dynamic> albumData = albumDoc.data() as Map<String, dynamic>;
      albumData['name'] = newName;

      // Create the new album document
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(newName)
          .set({
        ...albumData,
        'name': newName
      });

      // Get all images in the old album
      QuerySnapshot imagesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('albums')
          .doc(oldName)
          .collection('images')
          .get();

      // Move each image to the new album
      for (var doc in imagesSnapshot.docs) {
        Map<String, dynamic> imageData = doc.data() as Map<String, dynamic>;

        // Create a new storage path
        String oldPath = imageData['storagePath'];
        String fileName = imageData['fileName'];
        String newPath = 'users/$currentUserId/albums/$newName/$fileName';

        // Copy the file to the new location
        final oldRef = _storage.ref(oldPath);
        final newRef = _storage.ref(newPath);

        // Download the file data
        final Uint8List? data = await oldRef.getData();

        if (data != null) {
          // Upload to new location
          await newRef.putData(data);
          String newUrl = await newRef.getDownloadURL();

          // Add to new album in Firestore
          await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('albums')
              .doc(newName)
              .collection('images')
              .add({
            ...imageData,
            'url': newUrl,
            'storagePath': newPath,
          });

          // Delete from old location
          await oldRef.delete();
        }
      }

      // Delete the old album document and its images collection
      await deleteAlbum(oldName);
    } catch (e) {
      print('Error renaming album: $e');
      throw e;
    }
  }
}