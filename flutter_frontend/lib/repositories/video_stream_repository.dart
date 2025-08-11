import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase/firebase_service.dart';
import '../models/video_stream.dart';

abstract class VideoStreamRepository {
  Future<List<VideoStream>> getStreams();
  Future<VideoStream> addStream(VideoStream stream);
  Future<VideoStream> updateStream(VideoStream stream);
  Future<void> deleteStream(String streamId);
  Stream<List<VideoStream>> watchStreams();
}

class FirestoreVideoStreamRepository implements VideoStreamRepository {
  static const String _collection = 'video_streams';
  
  CollectionReference get _streamsCollection => 
      FirebaseService.instance.getUserCollection(_collection);

  @override
  Future<List<VideoStream>> getStreams() async {
    try {
      final snapshot = await _streamsCollection
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => VideoStream.fromMap({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList();
    } catch (e) {
      debugPrint('Error getting streams: $e');
      return [];
    }
  }

  @override
  Future<VideoStream> addStream(VideoStream stream) async {
    try {
      final docRef = await _streamsCollection.add(stream.toMap());
      return stream.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to add video stream: $e');
    }
  }

  @override
  Future<VideoStream> updateStream(VideoStream stream) async {
    try {
      await _streamsCollection.doc(stream.id).update(
        stream.copyWith(updatedAt: DateTime.now()).toMap(),
      );
      return stream.copyWith(updatedAt: DateTime.now());
    } catch (e) {
      throw Exception('Failed to update video stream: $e');
    }
  }

  @override
  Future<void> deleteStream(String streamId) async {
    try {
      await _streamsCollection.doc(streamId).delete();
    } catch (e) {
      throw Exception('Failed to delete video stream: $e');
    }
  }

  @override
  Stream<List<VideoStream>> watchStreams() {
    return _streamsCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => VideoStream.fromMap({
                    ...doc.data() as Map<String, dynamic>,
                    'id': doc.id,
                  }))
              .toList();
        });
  }
}

class MockVideoStreamRepository implements VideoStreamRepository {
  static final List<VideoStream> _streams = [
    VideoStream(
      id: '1',
      name: 'NASA Live',
      url: 'https://www.youtube.com/watch?v=21X5lGlDOfg',
      type: StreamTypes.youtube,
      category: 'Science',
      isLive: true,
      thumbnailUrl: 'https://img.youtube.com/vi/21X5lGlDOfg/maxresdefault.jpg',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    VideoStream(
      id: '2',
      name: 'Lofi Hip Hop Radio',
      url: 'https://www.youtube.com/watch?v=jfKfPfyJRdk',
      type: StreamTypes.youtube,
      category: 'Music',
      isLive: true,
      thumbnailUrl: 'https://img.youtube.com/vi/jfKfPfyJRdk/maxresdefault.jpg',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    VideoStream(
      id: '3',
      name: 'BBC News Live',
      url: 'https://www.youtube.com/watch?v=9Auq9mYxFEE',
      type: StreamTypes.youtube,
      category: 'News',
      isLive: true,
      thumbnailUrl: 'https://img.youtube.com/vi/9Auq9mYxFEE/maxresdefault.jpg',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    VideoStream(
      id: '4',
      name: 'Earth from Space',
      url: 'https://www.youtube.com/watch?v=DDU-rZs-Ic4',
      type: StreamTypes.youtube,
      category: 'Science',
      isLive: true,
      thumbnailUrl: 'https://img.youtube.com/vi/DDU-rZs-Ic4/maxresdefault.jpg',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  @override
  Future<List<VideoStream>> getStreams() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_streams);
  }

  @override
  Future<VideoStream> addStream(VideoStream stream) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newStream = stream.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _streams.add(newStream);
    return newStream;
  }

  @override
  Future<VideoStream> updateStream(VideoStream stream) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _streams.indexWhere((s) => s.id == stream.id);
    if (index != -1) {
      _streams[index] = stream.copyWith(updatedAt: DateTime.now());
      return _streams[index];
    }
    throw Exception('Stream not found');
  }

  @override
  Future<void> deleteStream(String streamId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _streams.removeWhere((s) => s.id == streamId);
  }

  @override
  Stream<List<VideoStream>> watchStreams() {
    return Stream.value(_streams);
  }
}