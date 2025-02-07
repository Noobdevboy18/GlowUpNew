import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/makeup_history.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import '../../constants/api_constants.dart';

class Personalization extends StatefulWidget {
  @override
  _PersonalizationState createState() => _PersonalizationState();
}

class _PersonalizationState extends State<Personalization> {
  File? _image;
  Map<String, dynamic>? _analysis;
  Map<String, dynamic>? _makeupResult;
  bool isLoading = false;

  Future<bool> _requestPermissions() async {
    if (!kIsWeb) {
      // Request all possible permissions related to images
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.photos,
        Permission.storage,
        Permission.mediaLibrary,
        Permission.videos,
        Permission.audio,
      ].request();

      // Log permissions status for debugging
      statuses.forEach((permission, status) {
        print('Permission $permission: $status');
      });

      // For Android 10 and above
      if (await Permission.manageExternalStorage.status.isDenied) {
        await Permission.manageExternalStorage.request();
      }

      // Check if essential permissions are granted
      bool hasEssentialPermissions = await Permission.camera.status.isGranted &&
          (await Permission.photos.status.isGranted || await Permission.storage.status.isGranted);

      if (!hasEssentialPermissions) {
        print('Essential permissions not granted');
        // You might want to open app settings if permissions are permanently denied
        if (await Permission.camera.isPermanentlyDenied ||
            await Permission.photos.isPermanentlyDenied ||
            await Permission.storage.isPermanentlyDenied) {
          // Open app settings
          await openAppSettings();
        }
      }

      return hasEssentialPermissions;
    }
    return true;
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vui lòng cấp quyền truy cập ảnh và máy ảnh để sử dụng tính năng này'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _analysis = null;
        });
        _analyzeFace();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh: $e')),
      );
    }
  }

  Future<void> _analyzeFace() async {
    if (_image == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Phân tích khuôn mặt
      var analyzeRequest = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.analyzeFaceEndpoint),
      );

      analyzeRequest.files.add(
        await http.MultipartFile.fromPath(
          'image',
          _image!.path,
        ),
      );

      var analyzeResponse = await analyzeRequest.send();
      var analyzeData = await analyzeResponse.stream.bytesToString();
      var analyzeResult = json.decode(analyzeData);

      if (analyzeResponse.statusCode == 200) {
        setState(() {
          _analysis = analyzeResult;
        });

        // 2. Áp dụng makeup
        var makeupRequest = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConstants.applyMakeupEndpoint),
        );


        makeupRequest.files.add(
          await http.MultipartFile.fromPath(
            'image',
            _image!.path,
          ),
        );

        var makeupResponse = await makeupRequest.send();
        var makeupData = await makeupResponse.stream.bytesToString();
        var makeupResult = json.decode(makeupData);
        print(makeupResult);

        if (makeupResponse.statusCode == 200) {
          setState(() {
            _makeupResult = makeupResult;
          });

          // Lưu cả hai kết quả vào lịch sử
          await _saveResults();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi phân tích: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveResults() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Lưu kết quả phân tích khuôn mặt
      if (_analysis != null) {
        final faceAnalysis = MakeupHistory(
          id: '${DateTime.now().millisecondsSinceEpoch}_analysis',
          imageUrl: _analysis!['image_url'],
          context: 'face_analysis',
          timestamp: DateTime.now(),
          suggestion: _analysis!,
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('makeup_history')
            .doc(faceAnalysis.id)
            .set(faceAnalysis.toMap());
      }

      // Lưu kết quả makeup
      if (_makeupResult != null) {
        final makeupHistory = MakeupHistory(
          id: '${DateTime.now().millisecondsSinceEpoch}_makeup',
          imageUrl: _makeupResult!['data']['url'],
          context: 'applied_makeup',
          timestamp: DateTime.now(),
          suggestion: {'description': 'Ảnh đã được áp dụng makeup'},
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('makeup_history')
            .doc(makeupHistory.id)
            .set(makeupHistory.toMap());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu kết quả phân tích')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu: $e')),
      );
    }
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ảnh toàn màn hình
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.error),
                  );
                },
              ),
            ),
            // Nút đóng
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phân tích khuôn mặt',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    if (_image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _image!,
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                      ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _getImage(ImageSource.gallery),
                          icon: Icon(Icons.photo_library),
                          label: Text('Thư viện'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_analysis != null) ...[
                SizedBox(height: 30),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kết quả phân tích',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 15),
                        Text(
                          _analysis!['analysis']['description'],
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Gợi ý trang điểm:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        ...(_analysis!['analysis']['makeup_tips'] as List)
                            .map((tip) => Padding(
                                  padding: EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle,
                                          color: Theme.of(context).primaryColor),
                                      SizedBox(width: 10),
                                      Expanded(child: Text(tip)),
                                    ],
                                  ),
                                ))
                            .toList(),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _saveResults,
                          icon: Icon(Icons.save),
                          label: Text('Lưu phân tích này'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_makeupResult != null) ...[
                SizedBox(height: 30),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showFullImage(_makeupResult!['data']['url']),
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                          child: Image.network(
                            _makeupResult!['data']['url'],
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 300,
                                color: Colors.grey[300],
                                child: Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kết quả áp dụng makeup',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.fullscreen),
                              onPressed: () => _showFullImage(_makeupResult!['data']['url']),
                              tooltip: 'Xem toàn màn hình',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 