import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../log/logger.dart';
import '../models/album/album.dart';
import '../models/media/media.dart';
import 'base/cloud_provider_service.dart';
import 'local_media_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>(
  (ref) => FirebaseService(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    FirebaseAuth.instance,
    ref.read(localMediaServiceProvider),
    ref.read(loggerProvider),
  ),
);

class FirebaseService extends CloudProviderService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final LocalMediaService _localMediaService;
  final Logger _logger;

  FirebaseService(
    this._firestore,
    this._storage,
    this._auth,
    this._localMediaService,
    this._logger,
  );

  String? get _userId => _auth.currentUser?.uid;

  // HELPERS -------------------------------------------------------------------

  CollectionReference get _mediaCollection => _firestore.collection('media');
  CollectionReference get _albumsCollection => _firestore.collection('albums');

  // Split list into chunks (useful for Firestore where "in" queries are limited to 10 items)
  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }

  // MEDIA ---------------------------------------------------------------------

  /// Check if user is authenticated
  bool get isAuthenticated => _userId != null;

  /// Get the current user ID
  String? get userId => _userId;

  /// Check if the media exists in Firebase
  Future<bool> isMediaExist({required String id}) async {
    if (!isAuthenticated) return false;

    final docSnapshot = await _mediaCollection.doc(id).get();
    return docSnapshot.exists;
  }

  /// Get a single media by ID
  Future<AppMedia?> getMedia({required String id}) async {
    if (!isAuthenticated) return null;

    try {
      final docSnapshot = await _mediaCollection.doc(id).get();
      if (!docSnapshot.exists) return null;

      final data = docSnapshot.data() as Map<String, dynamic>;
      _logger.d('Media data: $data');
      if (data['userId'] != _userId) return null; // Security check

      return _convertToAppMedia(data, docSnapshot.id);
    } catch (e, st) {
      debugPrint('Error getting media from Firebase: $e');
      debugPrint('Error getting media from Firebase stack trace: $st');
      return null;
    }
  }

  /// Get all media with pagination
  Future<List<AppMedia>> getMedias({
    int? pageSize,
    String? pageToken,
    String? searchQuery,
  }) async {
    if (!isAuthenticated) return [];

    try {
      // Start with a query filtered to user's media
      Query query = _mediaCollection.where('userId', isEqualTo: _userId);

      // Add search query filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('name', isGreaterThanOrEqualTo: searchQuery)
            .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      }

      // Add ordering by creation date (newest first)
      query = query.orderBy('createdTime', descending: true);

      // Add pagination
      if (pageSize != null) {
        query = query.limit(pageSize);
      }

      // Add start after token if provided
      if (pageToken != null) {
        // Convert token to a DocumentSnapshot
        final docSnapshot = await _mediaCollection.doc(pageToken).get();
        if (docSnapshot.exists) {
          query = query.startAfterDocument(docSnapshot);
        }
      }

      // Execute query
      final querySnapshot = await query.get();

      // Convert documents to AppMedia objects
      return querySnapshot.docs
          .map(
            (doc) =>
                _convertToAppMedia(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e, st) {
      debugPrint('Error getting media from Firebase: $e');
      debugPrint('Error getting media from Firebase stack trace: $st');
      return [];
    }
  }

  /// Stream media with real-time updates
  Stream<List<AppMedia>> getMediaStream({
    int? limit,
    DocumentSnapshot? startAfter,
  }) {
    if (!isAuthenticated) {
      return Stream.value([]);
    }

    Query query = _mediaCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdTime', descending: true);

    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return _convertToAppMedia(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Delete a media by ID
  @override
  Future<void> deleteMedia({
    required String id,
    CancelToken? cancelToken,
  }) async {
    if (!isAuthenticated) return;

    try {
      // Get media to check ownership and get path
      final docSnapshot = await _mediaCollection.doc(id).get();
      if (!docSnapshot.exists) return;

      final data = docSnapshot.data() as Map<String, dynamic>;
      if (data['userId'] != _userId) return; // Security check

      // Delete from Storage if it exists
      if (data['storagePath'] != null) {
        try {
          await _storage.ref(data['storagePath']).delete();
        } catch (e) {
          print('Warning: Could not delete from storage: $e');
          // Continue with Firestore deletion even if Storage deletion fails
        }
      }

      // Delete thumbnail if it exists
      if (data['thumbnailPath'] != null) {
        try {
          await _storage.ref(data['thumbnailPath']).delete();
        } catch (e) {
          print('Warning: Could not delete thumbnail: $e');
        }
      }

      // Delete the document from Firestore
      await _mediaCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting media from Firebase: $e');
    }
  }

  /// Upload a media file to Firebase
  @override
  Future<AppMedia> uploadMedia({
    required String folderId,
    required String path,
    String? mimeType,
    String? localRefId,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final now = DateTime.now();
      final file = File(path);
      final fileName = path.split('/').last;
      final mediaId = const Uuid().v4();

      // Use folderId if provided, otherwise create a default folder path
      final folderPath =
          folderId.isNotEmpty ? folderId : 'users/$_userId/media';
      final storagePath = '$folderPath/$mediaId/$fileName';

      // Upload to Firebase Storage
      final uploadTask = _storage.ref(storagePath).putFile(file);

      // Handle upload progress if callback provided
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred;
          final total = snapshot.totalBytes;
          onProgress(progress, total);
        });
      }

      // Cancel token handling
      if (cancelToken != null) {
        cancelToken.whenCancel.then((_) {
          uploadTask.cancel();
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Generate thumbnail for images and videos (simplified for now)
      String? thumbnailUrl;
      String? thumbnailPath;

      // Determine media type
      final type = AppMediaType.getType(mimeType: mimeType, location: path);

      final appMedia = AppMedia(
        id: mediaId,
        path: downloadUrl,
        name: fileName,
        type: type,
        size: file.lengthSync().toString(),
        createdTime: now,
        modifiedTime: now,
        mimeType: mimeType,
        sources: [
          AppMediaSource.firebase,
        ],
        thumbnailLink: downloadUrl,
      );

      final mediaData = appMedia.toJson();
      mediaData['userId'] = _userId;
      mediaData['createdTime'] = Timestamp.fromDate(now);
      mediaData['modifiedTime'] = Timestamp.fromDate(now);

      // Add to Firestore
      await _mediaCollection.doc(mediaId).set(mediaData);

      return appMedia;
    } catch (e) {
      print('Error uploading media to Firebase: $e');
      rethrow; // Rethrow to match the contract expected by CloudProviderService
    }
  }

  /// Search for media by name
  Future<List<AppMedia>> searchMedia(String query) async {
    if (!isAuthenticated || query.isEmpty) return [];

    try {
      // Create a query to search for media with names containing the search term
      final querySnapshot = await _mediaCollection
          .where('userId', isEqualTo: _userId)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return querySnapshot.docs
          .map(
            (doc) =>
                _convertToAppMedia(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print('Error searching media: $e');
      return [];
    }
  }

  // ALBUM ---------------------------------------------------------------------

  /// Stream of all albums for the current user
  Stream<List<Album>> getAlbumStream() {
    if (!isAuthenticated) return Stream.value([]);

    return _albumsCollection
        .where('userId', isEqualTo: _userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    _convertToAlbum(doc.data() as Map<String, dynamic>, doc.id),
              )
              .toList(),
        );
  }

  /// Get all albums
  Future<List<Album>> getAlbums() async {
    if (!isAuthenticated) return [];

    try {
      final querySnapshot = await _albumsCollection
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) =>
                _convertToAlbum(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print('Error getting albums from Firebase: $e');
      return [];
    }
  }

  /// Get a specific album by ID
  Future<Album?> getAlbum(String id) async {
    if (!isAuthenticated) return null;

    try {
      final docSnapshot = await _albumsCollection.doc(id).get();
      if (!docSnapshot.exists) return null;

      final data = docSnapshot.data() as Map<String, dynamic>;
      if (data['userId'] != _userId) return null; // Security check

      return _convertToAlbum(data, docSnapshot.id);
    } catch (e) {
      print('Error getting album from Firebase: $e');
      return null;
    }
  }

  /// Get all media for a specific album
  Future<List<AppMedia>> getAlbumMedia(String albumId) async {
    if (!isAuthenticated) return [];

    try {
      // Get the album first to get the media IDs
      final album = await getAlbum(albumId);
      if (album == null || album.medias.isEmpty) return [];

      // Get the media items
      final mediaList = <AppMedia>[];

      // Firestore has a limit of 10 items per whereIn query
      final chunks = _chunkList(album.medias, 10);

      for (final chunk in chunks) {
        final querySnapshot = await _mediaCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .where('userId', isEqualTo: _userId) // Security check
            .get();

        mediaList.addAll(
          querySnapshot.docs.map(
            (doc) =>
                _convertToAppMedia(doc.data() as Map<String, dynamic>, doc.id),
          ),
        );
      }

      return mediaList;
    } catch (e) {
      print('Error getting album media from Firebase: $e');
      return [];
    }
  }

  /// Helper method to ensure media exists in Firebase
  /// If media doesn't exist, it will upload it using the uploadMedia method
  Future<List<String>> _ensureMediaExists(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return [];

    // Check which media IDs already exist
    final chunks = _chunkList(mediaIds, 10);
    final existingMediaIds = <String>[];
    final now = DateTime.now();

    for (final chunk in chunks) {
      final querySnapshot = await _mediaCollection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      existingMediaIds.addAll(querySnapshot.docs.map((doc) => doc.id));
    }

    // Find media IDs that don't exist yet
    final newMediaIds =
        mediaIds.where((id) => !existingMediaIds.contains(id)).toList();

    final List<String> uploadedMediaIds = [];

    // Create new media documents or upload media for IDs that don't exist
    for (final newId in newMediaIds) {
      // Get local media data
      final localMedia = await _localMediaService.getMedia(id: newId);

      AppMedia? uploadedMedia;

      if (localMedia != null) {
        try {
          // Use the existing uploadMedia method to handle the upload
          uploadedMedia = await uploadMedia(
            folderId: 'users/$_userId/media',
            path: localMedia.path,
            mimeType: localMedia.mimeType,
            localRefId:
                newId, // Use the media ID as the localRefId for reference
          );
        } catch (e, st) {
          _logger.e('Error uploading media to Firebase Storage: $e\n$st');

          // Create a basic document even if upload fails
          // await _mediaCollection.doc(newId).set({
          //   'id': newId,
          //   'userId': _userId,
          //   'createdAt': now,
          //   'updatedAt': now,
          //   'status': 'upload_failed',
          // });
          rethrow;
        } finally {
          uploadedMediaIds.add(uploadedMedia?.id ?? newId);
        }
      } else {
        // If no local media is found, create basic placeholder
        await _mediaCollection.doc(newId).set({
          'id': newId,
          'userId': _userId,
          'createdAt': now,
          'updatedAt': now,
        });
        uploadedMediaIds.add(newId);
      }
    }
    return [...existingMediaIds, ...uploadedMediaIds];
  }

  /// Create a new album
  Future<Album?> createAlbum({
    required String name,
    required List<String> mediaIds,
  }) async {
    if (!isAuthenticated) return null;

    try {
      // Ensure all media exists or upload if needed
      final uploadedMediaIds = await _ensureMediaExists(mediaIds);

      // Generate unique ID for the album
      final id = const Uuid().v4();

      // Find a cover image URL if available
      String? coverUrl;
      if (uploadedMediaIds.isNotEmpty) {
        final firstMediaDoc =
            await _mediaCollection.doc(uploadedMediaIds.first).get();
        if (firstMediaDoc.exists) {
          final data = firstMediaDoc.data() as Map<String, dynamic>;
          coverUrl = data['thumbnailUrl'] ?? data['path'];
        }
      }

      // Create album document
      final now = DateTime.now();
      final albumData = {
        'id': id,
        'name': name,
        'userId': _userId,
        'mediaIds': uploadedMediaIds,
        'coverUrl': coverUrl,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'mediaCount': uploadedMediaIds.length,
      };

      // Add to Firestore
      await _albumsCollection.doc(id).set(albumData);

      return Album(
        id: id,
        name: name,
        medias: uploadedMediaIds,
        source: AppMediaSource.firebase,
        created_at: now,
      );
    } catch (e) {
      print('Error creating album in Firebase: $e');
      rethrow;
    }
  }

  /// Update an album
  Future<Album?> updateAlbum({
    required String id,
    String? name,
    List<String>? mediaIds,
  }) async {
    if (!isAuthenticated) return null;

    try {
      // Verify album exists and belongs to user
      final albumDoc = await _albumsCollection.doc(id).get();
      if (!albumDoc.exists) return null;

      final albumData = albumDoc.data() as Map<String, dynamic>;
      if (albumData['userId'] != _userId) return null;

      final now = DateTime.now();

      // Prepare update data
      final Map<String, dynamic> updateData = {
        'updatedAt': Timestamp.fromDate(now),
      };

      if (name != null) {
        updateData['name'] = name;
      }

      if (mediaIds != null) {
        // Ensure all media exists or upload if needed
        final uploadedMediaIds = await _ensureMediaExists(mediaIds);

        updateData['mediaIds'] = uploadedMediaIds;
        updateData['mediaCount'] = uploadedMediaIds.length;

        // Update cover URL if media list changed
        if (mediaIds.isNotEmpty) {
          final firstMediaDoc =
              await _mediaCollection.doc(mediaIds.first).get();
          if (firstMediaDoc.exists) {
            final data = firstMediaDoc.data() as Map<String, dynamic>;
            updateData['coverUrl'] = data['thumbnailUrl'] ?? data['path'];
          }
        } else {
          updateData['coverUrl'] = null;
        }
      }

      // Update the document
      await _albumsCollection.doc(id).update(updateData);

      // Get the updated album
      final updatedDoc = await _albumsCollection.doc(id).get();
      return _convertToAlbum(updatedDoc.data() as Map<String, dynamic>, id);
    } catch (e) {
      print('Error updating album in Firebase: $e');
      rethrow;
    }
  }

  /// Delete an album
  Future<bool> deleteAlbum(String id) async {
    if (!isAuthenticated) return false;

    try {
      // Verify album exists and belongs to user
      final albumDoc = await _albumsCollection.doc(id).get();
      if (!albumDoc.exists) return false;

      final albumData = albumDoc.data() as Map<String, dynamic>;
      if (albumData['userId'] != _userId) return false;

      // Delete the album
      await _albumsCollection.doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting album from Firebase: $e');
      rethrow;
    }
  }

  /// Add media to an album
  Future<Album?> addMediaToAlbum({
    required String albumId,
    required List<String> mediaIds,
  }) async {
    if (!isAuthenticated) return null;

    try {
      // Verify album exists and belongs to user
      final albumDoc = await _albumsCollection.doc(albumId).get();
      if (!albumDoc.exists) return null;

      final albumData = albumDoc.data() as Map<String, dynamic>;
      if (albumData['userId'] != _userId) return null;

      // Get existing media IDs
      final existingMediaIds = List<String>.from(albumData['mediaIds'] ?? []);

      // Add new media IDs (avoid duplicates)
      final updatedMediaIds = [...existingMediaIds];
      for (final mediaId in mediaIds) {
        if (!updatedMediaIds.contains(mediaId)) {
          updatedMediaIds.add(mediaId);
        }
      }

      // Ensure all media exists or upload if needed
      await _ensureMediaExists(mediaIds);

      // Update the album
      return updateAlbum(
        id: albumId,
        mediaIds: updatedMediaIds,
      );
    } catch (e) {
      print('Error adding media to album in Firebase: $e');
      rethrow;
    }
  }

  /// Remove media from an album
  Future<Album?> removeMediaFromAlbum({
    required String albumId,
    required List<String> mediaIds,
  }) async {
    if (!isAuthenticated) return null;

    try {
      // Verify album exists and belongs to user
      final albumDoc = await _albumsCollection.doc(albumId).get();
      if (!albumDoc.exists) return null;

      final albumData = albumDoc.data() as Map<String, dynamic>;
      if (albumData['userId'] != _userId) return null;

      // Get existing media IDs
      final existingMediaIds = List<String>.from(albumData['mediaIds'] ?? []);

      // Remove specified media IDs
      final updatedMediaIds =
          existingMediaIds.where((id) => !mediaIds.contains(id)).toList();

      // Update the album
      return updateAlbum(
        id: albumId,
        mediaIds: updatedMediaIds,
      );
    } catch (e) {
      print('Error removing media from album in Firebase: $e');
      rethrow;
    }
  }

  // CONVERSION HELPERS --------------------------------------------------------

  /// Convert Firestore data to AppMedia model
  AppMedia _convertToAppMedia(Map<String, dynamic> data, String docId) {
    _logger.d('Media data: $data');
    // Determine media type
    final mimeType = data['mimeType'] as String?;
    final path = data['path'] as String;
    final typeString = data['type'] as String?;

    final type = typeString != null
        ? AppMediaType.values.firstWhere(
            (t) => t.value == typeString,
            orElse: () =>
                AppMediaType.getType(mimeType: mimeType, location: path),
          )
        : AppMediaType.getType(mimeType: mimeType, location: path);

    // Determine orientation
    AppMediaOrientation? orientation;
    if (data['displayHeight'] != null && data['displayWidth'] != null) {
      final height = (data['displayHeight'] as num).toDouble();
      final width = (data['displayWidth'] as num).toDouble();
      orientation = height > width
          ? AppMediaOrientation.portrait
          : AppMediaOrientation.landscape;
    }

    // Convert timestamps
    DateTime? createdTime;
    if (data['createdTime'] != null) {
      createdTime = (data['createdTime'] as Timestamp).toDate();
    }

    DateTime? modifiedTime;
    if (data['modifiedTime'] != null) {
      modifiedTime = (data['modifiedTime'] as Timestamp).toDate();
    }

    // Convert video duration
    Duration? videoDuration;
    if (type.isVideo && data['durationMillis'] != null) {
      videoDuration = Duration(
        milliseconds: (data['durationMillis'] as num).toInt(),
      );
    }

    return AppMedia(
      id: docId,
      path: path,
      name: data['name'] as String?,
      thumbnailLink: data['thumbnailLink'] as String?,
      displayHeight: data['displayHeight'] != null
          ? (data['displayHeight'] as num).toDouble()
          : null,
      displayWidth: data['displayWidth'] != null
          ? (data['displayWidth'] as num).toDouble()
          : null,
      type: type,
      mimeType: mimeType,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
      orientation: orientation,
      size: data['size'] as String?,
      videoDuration: videoDuration,
      latitude: data['latitude'] != null
          ? (data['latitude'] as num).toDouble()
          : null,
      longitude: data['longitude'] != null
          ? (data['longitude'] as num).toDouble()
          : null,
      sources: [
        AppMediaSource.firebase,
      ],
    );
  }

  /// Convert Firestore data to Album model
  Album _convertToAlbum(Map<String, dynamic> data, String docId) {
    return Album(
      id: docId,
      name: data['name'] as String,
      medias: List<String>.from(data['mediaIds'] ?? []),
      source: AppMediaSource.firebase,
      created_at: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  @override
  Future<String?> createFolder(String folderName) async {
    if (!isAuthenticated) return null;

    try {
      // Create a folder reference in Firebase Storage
      final folderPath = 'users/$_userId/$folderName';

      // Create a document in Firestore to track the folder
      await _firestore.collection('folders').add({
        'userId': _userId,
        'name': folderName,
        'path': folderPath,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      return folderPath;
    } catch (e) {
      print('Error creating folder in Firebase: $e');
      return null;
    }
  }

  @override
  Future<void> downloadMedia({
    required String id,
    required String saveLocation,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (!isAuthenticated) return;

    try {
      // Get the media document from Firestore
      final mediaDoc = await _mediaCollection.doc(id).get();
      if (!mediaDoc.exists) {
        throw Exception('Media not found with ID: $id');
      }

      final data = mediaDoc.data() as Map<String, dynamic>;
      if (data['userId'] != _userId) {
        throw Exception('You do not have permission to download this media');
      }

      // Get download URL
      final downloadUrl = data['path'] as String;
      if (downloadUrl.isEmpty) {
        throw Exception('Media has no download URL');
      }

      // Create the file to save to
      final file = File(saveLocation);

      // Download the file
      final downloadTask = _storage.refFromURL(downloadUrl).writeToFile(file);

      // Handle progress updates
      if (onProgress != null) {
        downloadTask.snapshotEvents.listen((taskSnapshot) {
          final progress = taskSnapshot.bytesTransferred;
          final total = taskSnapshot.totalBytes;
          onProgress(progress, total);
        });
      }

      // Handle cancellation
      if (cancelToken != null) {
        cancelToken.whenCancel.then((_) {
          downloadTask.cancel();
        });
      }

      // Wait for download completion
      await downloadTask;
    } catch (e) {
      print('Error downloading media from Firebase: $e');
      rethrow;
    }
  }

  @override
  Future<List<AppMedia>> getAllMedias({required String folder}) async {
    if (!isAuthenticated) return [];

    try {
      // Query all media in the specified folder
      final querySnapshot = await _mediaCollection
          .where('userId', isEqualTo: _userId)
          .where('storagePath', isGreaterThanOrEqualTo: folder)
          .where(
            'storagePath',
            isLessThan: '$folder\uf8ff',
          ) // This helps query by prefix
          .get();

      // Convert to AppMedia objects
      return querySnapshot.docs
          .map(
            (doc) =>
                _convertToAppMedia(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print('Error getting all media from Firebase: $e');
      return [];
    }
  }

  @override
  Future<GetPaginatedMediasResponse> getPaginatedMedias({
    required String folder,
    String? nextPageToken,
    int pageSize = 30,
  }) async {
    if (!isAuthenticated) {
      return GetPaginatedMediasResponse(medias: [], nextPageToken: null);
    }

    try {
      // Create base query for the folder
      Query query = _mediaCollection
          .where('userId', isEqualTo: _userId)
          .where('storagePath', isGreaterThanOrEqualTo: folder)
          .where('storagePath', isLessThan: '$folder\uf8ff')
          .orderBy('storagePath')
          .orderBy('createdTime', descending: true)
          .limit(pageSize);

      // If we have a pagination token, start after that document
      if (nextPageToken != null) {
        final lastDoc = await _mediaCollection.doc(nextPageToken).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      // Execute the query
      final querySnapshot = await query.get();
      final docs = querySnapshot.docs;

      // Convert to AppMedia objects
      final mediaList = docs
          .map(
            (doc) =>
                _convertToAppMedia(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      // Determine if there are more results and the next page token
      String? newNextPageToken;
      if (docs.length == pageSize) {
        // If we got a full page, there might be more
        newNextPageToken = docs.last.id;
      }

      return GetPaginatedMediasResponse(
        medias: mediaList,
        nextPageToken: newNextPageToken,
      );
    } catch (e) {
      print('Error getting paginated media from Firebase: $e');
      return GetPaginatedMediasResponse(medias: [], nextPageToken: null);
    }
  }
}
