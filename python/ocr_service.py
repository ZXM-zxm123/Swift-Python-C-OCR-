import base64
import json
import os
import sys
import tempfile
import time
import sqlite3
from datetime import datetime
from pathlib import Path

import cv2
import numpy as np
from flask import Flask, request, jsonify

try:
    import image_processor
    IMAGE_PROCESSOR_AVAILABLE = True
except ImportError:
    IMAGE_PROCESSOR_AVAILABLE = False
    print("Warning: image_processor C++ library not available, using OpenCV fallback")

app = Flask(__name__)

DB_PATH = os.path.join(os.path.dirname(__file__), "ocr_history.db")

def init_database():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT,
            base64_image TEXT,
            recognized_text TEXT,
            confidence REAL,
            created_at TEXT
        )
    ''')
    conn.commit()
    conn.close()

init_database()

def preprocess_image_opencv(image_data, threshold=128, kernel_size=3):
    nparr = np.frombuffer(image_data, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img is None:
        return None

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    kernel = np.ones((kernel_size, kernel_size), np.float32) / (kernel_size * kernel_size)
    denoised = cv2.filter2D(gray, -1, kernel)

    _, binary = cv2.threshold(denoised, threshold, 255, cv2.THRESH_BINARY)

    return binary

def preprocess_image_cpp(image_data, threshold=128, kernel_size=3):
    if not IMAGE_PROCESSOR_AVAILABLE:
        return None

    img_data = image_processor.ImageData()
    img_data.width = 0
    img_data.height = 0
    img_data.channels = 3
    img_data.data = list(image_data)

    preprocessed = image_processor.preprocess(img_data, threshold, kernel_size)

    result = bytes(preprocessed.data)
    return result

def perform_ocr(image_data):
    import pytesseract

    preprocessed = preprocess_image_cpp(image_data) if IMAGE_PROCESSOR_AVAILABLE else preprocess_image_opencv(image_data)

    if preprocessed is None:
        preprocessed = image_data

    nparr = np.frombuffer(preprocessed, np.uint8)
    if len(preprocessed) > 0 and nparr.size > 0:
        try:
            img = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
            if img is not None:
                text = pytesseract.image_to_string(img, lang='chi_sim+eng')
                confidence = 85.0
            else:
                nparr_color = np.frombuffer(image_data, np.uint8)
                img_color = cv2.imdecode(nparr_color, cv2.IMREAD_COLOR)
                if img_color is not None:
                    text = pytesseract.image_to_string(img_color, lang='chi_sim+eng')
                    confidence = 75.0
                else:
                    text = ""
                    confidence = 0.0
        except Exception as e:
            text = f"OCR Error: {str(e)}"
            confidence = 0.0
    else:
        text = "Failed to preprocess image"
        confidence = 0.0

    return text.strip(), confidence

def save_to_history(image_path, base64_image, text, confidence):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        INSERT INTO history (image_path, base64_image, recognized_text, confidence, created_at)
        VALUES (?, ?, ?, ?, ?)
    ''', (image_path, base64_image, text, confidence, datetime.now().isoformat()))
    conn.commit()
    record_id = cursor.lastrowid
    conn.close()
    return record_id

@app.route('/ocr', methods=['POST'])
def ocr_image():
    try:
        data = request.get_json()

        if not data:
            return jsonify({"error": "No data provided"}), 400

        image_path = data.get('image_path')
        base64_image = data.get('base64')
        threshold = data.get('threshold', 128)
        kernel_size = data.get('kernel_size', 3)

        if image_path and os.path.exists(image_path):
            with open(image_path, 'rb') as f:
                image_data = f.read()
            save_path = image_path
        elif base64_image:
            image_data = base64.b64decode(base64_image)
            save_path = None
        else:
            return jsonify({"error": "No image_path or base64 provided"}), 400

        text, confidence = perform_ocr(image_data)

        record_id = save_to_history(save_path, base64_image, text, confidence)

        return jsonify({
            "success": True,
            "text": text,
            "confidence": confidence,
            "record_id": record_id
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/history', methods=['GET'])
def get_history():
    try:
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)

        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, image_path, recognized_text, confidence, created_at
            FROM history
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        ''', (limit, offset))
        rows = cursor.fetchall()
        conn.close()

        records = [dict(row) for row in rows]

        return jsonify({
            "success": True,
            "records": records,
            "limit": limit,
            "offset": offset
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/history/<int:record_id>', methods=['DELETE'])
def delete_history(record_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('DELETE FROM history WHERE id = ?', (record_id,))
        deleted = cursor.rowcount > 0
        conn.commit()
        conn.close()

        if deleted:
            return jsonify({"success": True, "message": "Record deleted"})
        else:
            return jsonify({"error": "Record not found"}), 404

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/export', methods=['GET'])
def export_history():
    try:
        record_ids = request.args.get('ids', '')
        if record_ids:
            id_list = [int(x) for x in record_ids.split(',')]
        else:
            id_list = None

        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        if id_list:
            placeholders = ','.join('?' * len(id_list))
            cursor.execute(f'''
                SELECT recognized_text, created_at
                FROM history
                WHERE id IN ({placeholders})
                ORDER BY created_at DESC
            ''', id_list)
        else:
            cursor.execute('''
                SELECT recognized_text, created_at
                FROM history
                ORDER BY created_at DESC
            ''')

        rows = cursor.fetchall()
        conn.close()

        content = []
        for i, row in enumerate(rows):
            content.append(f"[{row['created_at']}]")
            content.append(row['recognized_text'])
            content.append("")

        return jsonify({
            "success": True,
            "content": "\n".join(content),
            "filename": f"ocr_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "ok",
        "image_processor_available": IMAGE_PROCESSOR_AVAILABLE
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
