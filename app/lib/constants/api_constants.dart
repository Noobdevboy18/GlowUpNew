class ApiConstants {
  // Base URL
  static const String baseUrl = 'http://192.168.2.104:5000';

  // API Endpoints
  static const String analyzeFaceEndpoint = '$baseUrl/analyze-face';
  static const String applyMakeupEndpoint = '$baseUrl/apply-makeup';
  static const String makeupSuggestionEndpoint = '$baseUrl/makeup-suggestion';

  static const String imgbbApiKey = 'e64a49ca517de7491f78d8edf586515a';
  static const String imgbbApiUrl = 'https://api.imgbb.com/1/upload';

  static const int imageQuality = 50;
  static const Duration timeoutDuration = Duration(seconds: 30);

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
} 