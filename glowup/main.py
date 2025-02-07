from flask import Flask, request, jsonify
import tensorflow as tf
# Tắt chế độ thực thi eager
tf.compat.v1.disable_eager_execution()

import numpy as np
import os
import glob
from imageio.v2 import imread, imsave
import cv2
import uuid
from werkzeug.utils import secure_filename
import requests
import base64
import dlib
import json

app = Flask(__name__)

# Cấu hình
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
IMGBB_API_KEY = 'e64a49ca517de7491f78d8edf586515a'
IMGBB_API_URL = 'https://api.imgbb.com/1/upload'

# Contexts và mô tả
MAKEUP_CONTEXTS = {
    'wedding': {
        'description': 'Trang điểm cô dâu tự nhiên, nhẹ nhàng nhưng vẫn nổi bật',
        'steps': [
            'Bước 1: Làm sạch và dưỡng ẩm da',
            'Bước 2: Sử dụng kem lót và kem nền tông nude',
            'Bước 3: Tạo khối và highlight nhẹ nhàng',
            'Bước 4: Phấn mắt tông hồng đào hoặc cam đất',
            'Bước 5: Son môi tông hồng đất tự nhiên'
        ]
    },
    'party': {
        'description': 'Trang điểm quyến rũ, nổi bật cho buổi tiệc tối',
        'steps': [
            'Bước 1: Làm sạch và primer',
            'Bước 2: Kem nền full coverage',
            'Bước 3: Tạo khối sắc nét',
            'Bước 4: Mắt khói và highlight',
            'Bước 5: Son môi tông đậm'
        ]
    },
    'casual': {
        'description': 'Trang điểm nhẹ nhàng, tự nhiên cho dạo phố',
        'steps': [
            'Bước 1: Kem chống nắng và kem dưỡng',
            'Bước 2: BB cream hoặc kem nền mỏng nhẹ',
            'Bước 3: Má hồng nhẹ',
            'Bước 4: Mascara và kẻ mắt mỏng',
            'Bước 5: Son bóng hoặc son lì màu tự nhiên'
        ]
    },
    'event': {
        'description': 'Trang điểm chuyên nghiệp cho sự kiện quan trọng',
        'steps': [
            'Bước 1: Primer và color corrector',
            'Bước 2: Kem nền lâu trôi',
            'Bước 3: Tạo khối và highlight cân đối',
            'Bước 4: Mắt sắc nét với nhũ',
            'Bước 5: Son môi bền màu'
        ]
    },
    'meeting': {
        'description': 'Trang điểm công sở chuyên nghiệp',
        'steps': [
            'Bước 1: Kem chống nắng và kem lót',
            'Bước 2: Kem nền mỏng tự nhiên',
            'Bước 3: Phấn phủ kiềm dầu',
            'Bước 4: Mắt nhẹ nhàng tông nâu',
            'Bước 5: Son môi tông MLBB'
        ]
    }
}

FACE_SHAPES = {
    'heart': {
        'description': 'Khuôn mặt trái tim với trán rộng và cằm nhọn',
        'makeup_tips': [
            'Tạo khối hai bên thái dương để cân bằng trán rộng',
            'Đánh má hồng theo hướng ngang để tạo cảm giác rộng hơn ở phần cằm',
            'Kẻ mắt mỏng, nhẹ nhàng',
            'Tô son theo đường môi tự nhiên'
        ]
    },
    'oblong': {
        'description': 'Khuôn mặt dài với các cạnh song song',
        'makeup_tips': [
            'Tạo khối ngang để làm khuôn mặt ngắn lại',
            'Đánh má hồng theo hướng ngang',
            'Kẻ mắt cong, không kéo dài',
            'Tô son dày ở giữa môi'
        ]
    },
    'oval': {
        'description': 'Khuôn mặt oval cân đối',
        'makeup_tips': [
            'Có thể áp dụng hầu hết các kiểu trang điểm',
            'Tạo khối nhẹ nhàng theo đường cong tự nhiên',
            'Đánh má hồng theo hướng chéo lên',
            'Tô son theo ý thích'
        ]
    },
    'round': {
        'description': 'Khuôn mặt tròn với chiều rộng và chiều cao tương đương',
        'makeup_tips': [
            'Tạo khối sắc nét để khuôn mặt thon gọn hơn',
            'Đánh má hồng theo hướng chéo lên',
            'Kẻ mắt kéo dài về phía đuôi mắt',
            'Tô son theo hình trái tim'
        ]
    },
    'square': {
        'description': 'Khuôn mặt vuông với góc hàm rõ ràng',
        'makeup_tips': [
            'Tạo khối để làm mềm các góc cạnh',
            'Đánh má hồng theo hướng chéo lên',
            'Kẻ mắt cong mềm mại',
            'Tô son theo đường cong tự nhiên'
        ]
    }
}

if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def upload_to_imgbb(image_path):
    with open(image_path, "rb") as file:
        # Encode ảnh thành base64
        image_data = base64.b64encode(file.read()).decode('utf-8')
    
    # Chuẩn bị payload cho request
    payload = {
        'key': IMGBB_API_KEY,
        'image': image_data,
    }
    
    # Gửi request đến ImgBB API
    response = requests.post(IMGBB_API_URL, data=payload)
    
    if response.status_code == 200:
        return response.json()
    else:
        raise Exception("Failed to upload image to ImgBB")

def preprocess(img):
    img = img.astype(np.float32)
    return (img / 255.0 - 0.5) * 2

def deprocess(img):
    img = (img + 1) / 2
    return np.clip(img, 0, 1)

def apply_makeup(no_makeup_path):
    img_size = 256
    no_makeup = cv2.resize(imread(no_makeup_path), (img_size, img_size))
    X_img = np.expand_dims(preprocess(no_makeup), 0)
    makeups = glob.glob(os.path.join('imgs', 'makeup', '*.*'))
    result = np.ones((2 * img_size, (len(makeups) + 1) * img_size, 3))
    result[img_size: 2 * img_size, :img_size] = no_makeup / 255.0

    sess = tf.compat.v1.Session()
    saver = tf.compat.v1.train.import_meta_graph(os.path.join('model', 'model.meta'))
    saver.restore(sess, tf.train.latest_checkpoint('model'))

    graph = tf.compat.v1.get_default_graph()
    X = graph.get_tensor_by_name('X:0')
    Y = graph.get_tensor_by_name('Y:0')
    Xs = graph.get_tensor_by_name('generator/xs:0')

    for i in range(len(makeups)):
        makeup = cv2.resize(imread(makeups[i]), (img_size, img_size))
        Y_img = np.expand_dims(preprocess(makeup), 0)
        Xs_ = sess.run(Xs, feed_dict={X: X_img, Y: Y_img})
        Xs_ = deprocess(Xs_)
        result[:img_size, (i + 1) * img_size: (i + 2) * img_size] = makeup / 255.0
        result[img_size: 2 * img_size, (i + 1) * img_size: (i + 2) * img_size] = Xs_[0]

    result = (result * 255).astype(np.uint8)
    
    # Tạo tên file kết quả unique
    result_filename = f"result_{uuid.uuid4()}.jpg"
    result_path = os.path.join(app.config['UPLOAD_FOLDER'], result_filename)
    imsave(result_path, result)
    
    return result_path

# API gợi ý trang điểm theo ngữ cảnh
@app.route('/makeup-suggestion', methods=['GET'])
def makeup_suggestion():
    context = request.args.get('context', '').lower()
    
    if context not in MAKEUP_CONTEXTS:
        return jsonify({
            'error': 'Invalid context. Available contexts: ' + ', '.join(MAKEUP_CONTEXTS.keys())
        }), 400
    
    # Lấy danh sách ảnh mẫu cho ngữ cảnh
    makeup_samples = glob.glob(os.path.join('imgs', 'makeup', context, '*.*'))
    sample_urls = []
    
    # Upload và lấy URL của các ảnh mẫu
    for sample in makeup_samples[:3]:  # Giới hạn 3 ảnh mẫu
        try:
            response = upload_to_imgbb(sample)
            sample_urls.append(response['data']['url'])
        except Exception as e:
            print(f"Failed to upload sample image: {str(e)}")
    
    return jsonify({
        'success': True,
        'context': context,
        'suggestion': MAKEUP_CONTEXTS[context],
        'sample_images': sample_urls
    })

# API phân tích khuôn mặt
@app.route('/analyze-face', methods=['POST'])
def analyze_face():
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        try:
            # Đọc ảnh và phân tích tỷ lệ khuôn mặt
            image = cv2.imread(filepath)
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Giả lập phân tích khuôn mặt (trong thực tế nên dùng model ML)
            face_width = image.shape[1]
            face_height = image.shape[0]
            ratio = face_height / face_width
            
            # Xác định hình dạng khuôn mặt dựa trên tỷ lệ
            # (đây chỉ là logic đơn giản, trong thực tế nên dùng model ML)
            if ratio > 1.2:
                face_shape = 'oblong'
            elif ratio < 0.95:
                face_shape = 'square'
            elif 0.95 <= ratio <= 1.05:
                face_shape = 'round'
            else:
                face_shape = 'oval'
            
            # Upload ảnh đã phân tích
            imgbb_response = upload_to_imgbb(filepath)
            
            return jsonify({
                'success': True,
                'face_shape': face_shape,
                'analysis': FACE_SHAPES[face_shape],
                'image_url': imgbb_response['data']['url']
            })
            
        except Exception as e:
            return jsonify({'error': str(e)}), 500
        finally:
            if os.path.exists(filepath):
                os.remove(filepath)
    
    return jsonify({'error': 'Invalid file type'}), 400

@app.route('/apply-makeup', methods=['POST'])
def makeup_api():
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    filepath = None
    result_path = None
    
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        try:
            # Xử lý ảnh
            result_path = apply_makeup(filepath)
            
            # Upload ảnh lên ImgBB
            imgbb_response = upload_to_imgbb(result_path)
            
            # Trả về response với URL của ảnh
            response_data = {
                'success': True,
                'message': 'Image processed and uploaded successfully',
                'data': {
                    'url': imgbb_response['data']['url'],
                    'delete_url': imgbb_response['data']['delete_url'],
                    'thumbnail_url': imgbb_response['data']['thumb']['url']
                }
            }
            
            return jsonify(response_data), 200
            
        except Exception as e:
            return jsonify({'error': str(e)}), 500
        finally:
            # Xóa các file tạm sau khi xử lý
            if filepath and os.path.exists(filepath):
                os.remove(filepath)
            if result_path and os.path.exists(result_path):
                os.remove(result_path)
    
    return jsonify({'error': 'Invalid file type'}), 400

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)