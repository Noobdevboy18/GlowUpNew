# GlowUp - Ứng dụng Tư vấn & Thử Makeup AI

GlowUp là một ứng dụng di động thông minh giúp người dùng thử nghiệm và nhận tư vấn về trang điểm dựa trên công nghệ AI. Ứng dụng phân tích khuôn mặt người dùng và đề xuất phong cách trang điểm phù hợp cho từng dịp khác nhau.

## 🌟 Tính năng chính

### 1. Phân tích khuôn mặt
- Phân tích và xác định hình dạng khuôn mặt (oval, tròn, vuông, trái tim, etc.)
- Đề xuất phong cách trang điểm phù hợp với từng hình dạng khuôn mặt
- Lưu kết quả phân tích để tham khảo sau

### 2. Gợi ý trang điểm theo ngữ cảnh
- Tư vấn makeup cho nhiều dịp khác nhau:
  - Đám cưới (Wedding)
  - Tiệc tùng (Party)
  - Thường ngày (Casual)
  - Sự kiện (Event)
  - Công việc (Meeting)

### 3. Thử makeup ảo
- Áp dụng các style makeup khác nhau lên ảnh của người dùng
- Xem trước kết quả makeup theo thời gian thực
- Lưu và chia sẻ kết quả

### 4. Lịch sử và theo dõi
- Lưu lại các lần thử makeup và phân tích trước đây
- Xem lại các gợi ý và kết quả đã thực hiện
- Theo dõi sự tiến bộ qua thời gian

## 🛠 Công nghệ sử dụng

### Mobile App (Flutter)
- **Framework**: Flutter
- **State Management**: Provider
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Storage**: Firebase Storage
- **Image Processing**: 
  - image_picker
  - permission_handler
  - http

### Backend (Python Flask)
- **Framework**: Flask
- **AI/ML**: 
  - TensorFlow
  - OpenCV
  - dlib
  - NumPy
- **Image Hosting**: ImgBB API
- **File Processing**: Werkzeug
- **Image Processing**: imageio

## 📱 Cài đặt ứng dụng

### Yêu cầu hệ thống
- Flutter SDK
- Android Studio/VS Code
- Python 3.16.2
- Firebase project

### Cài đặt Mobile App

1. Clone repository:
   ```bash
   git clone <repository-url>
   cd app
   ```
2. Cài đặt dependencies:
   ```bash
   flutter pub get
   ```
3. Cấu hình Firebase:
   - Tạo project trên Firebase Console
   - Thêm ứng dụng Android/iOS
   - Tải và thêm file cấu hình:
     - `google-services.json` cho Android
     - `GoogleService-Info.plist` cho iOS
4. Chạy ứng dụng:
   ```bash
   flutter run
   ```

### Cài đặt Backend

1. Di chuyển vào thư mục backend:
   ```bash
   cd glowup
   ```
2. Tạo môi trường ảo:
   ```bash
   python -m venv venv
   source venv/bin/activate # Linux/Mac
   venv\Scripts\activate # Windows
   ```
3. Cài đặt dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Cấu hình biến môi trường:
   - Tạo file `.env` từ `.env.example`
   - Cập nhật các biến môi trường cần thiết:
     - `IMGBB_API_KEY`
     - `FLASK_ENV`
     - `FLASK_APP`
5. Chạy server:
   ```bash
   python main.py
   ```

## 📁 Cấu trúc project

```plaintext
glowup/
├── app/ # Flutter application
│   ├── lib/
│   │   ├── constants/ # API endpoints & constants
│   │   ├── models/ # Data models
│   │   ├── screens/
│   │   │   ├── home/ # Home screen
│   │   │   └── tabs/ # Main tabs
│   │   └── services/ # Authentication & API services
│   ├── android/ # Android configuration
│   ├── ios/ # iOS configuration
│   └── pubspec.yaml # Flutter dependencies
│
└── glowup/ # Python backend
    ├── imgs/ # Sample & reference images
    │   └── face_shapes/ # Face shape references
    ├── main.py # Flask application
    └── requirements.txt # Python dependencies
```

## 🔒 API Endpoints

### 1. Phân tích khuôn mặt
**POST** `/analyze-face`
- Phân tích và trả về thông tin về hình dạng khuôn mặt
- Đề xuất phong cách trang điểm phù hợp

### 2. Gợi ý trang điểm
**GET** `/makeup-suggestion`
- Trả về gợi ý trang điểm theo ngữ cảnh
- Bao gồm các bước thực hiện và hình ảnh minh họa

### 3. Áp dụng makeup
**POST** `/apply-makeup`
- Áp dụng style makeup lên ảnh người dùng
- Trả về URL ảnh đã được xử lý

## 🔐 Bảo mật
- Xác thực người dùng qua Firebase Auth
- Kiểm tra và giới hạn kích thước file upload
- Xóa files tạm sau khi xử lý
- Mã hóa dữ liệu nhạy cảm

## 📝 License
Dự án được phân phối dưới giấy phép MIT.

