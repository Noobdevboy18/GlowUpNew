import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/makeup_history.dart';
import '../../constants/api_constants.dart';

class MakeupSuggestions extends StatefulWidget {
  @override
  _MakeupSuggestionsState createState() => _MakeupSuggestionsState();
}

class _MakeupSuggestionsState extends State<MakeupSuggestions> {
  String selectedContext = 'casual';
  Map<String, dynamic>? suggestion;
  List<String>? sampleImages;
  bool isLoading = false;

  final contexts = {
    'casual': 'Trang điểm nhẹ nhàng hàng ngày',
    'party': 'Trang điểm dự tiệc',
    'wedding': 'Trang điểm cô dâu',
    'event': 'Trang điểm sự kiện',
    'meeting': 'Trang điểm công sở'
  };

  Future<void> getMakeupSuggestion() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConstants.makeupSuggestionEndpoint + '?context=$selectedContext'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          suggestion = data['suggestion'];
          sampleImages = List<String>.from(data['sample_images']);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy gợi ý: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveSuggestion() async {
    if (suggestion == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final history = MakeupHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imageUrl: sampleImages?.first ?? '',
        context: selectedContext,
        timestamp: DateTime.now(),
        suggestion: suggestion!,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('makeup_history')
          .doc(history.id)
          .set(history.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu gợi ý trang điểm')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu: $e')),
      );
    }
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
                'Gợi ý trang điểm',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[100],
                ),
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedContext,
                    isExpanded: true,
                    items: contexts.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedContext = value!;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : getMakeupSuggestion,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Center(
                    child: isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Nhận gợi ý'),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (suggestion != null) ...[
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
                          suggestion!['description'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 15),
                        ...List.generate(
                          suggestion!['steps'].length,
                          (index) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    suggestion!['steps'][index],
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (sampleImages != null && sampleImages!.isNotEmpty) ...[
                  SizedBox(height: 20),
                  Text(
                    'Hình ảnh tham khảo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: sampleImages!.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              sampleImages![index],
                              width: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: saveSuggestion,
                  icon: Icon(Icons.save),
                  label: Text('Lưu gợi ý này'),
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
            ],
          ),
        ),
      ),
    );
  }
} 