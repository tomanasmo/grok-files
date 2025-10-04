# app.py v91
from flask import Flask, send_file, request, jsonify
import os
from datetime import datetime
from zoneinfo import ZoneInfo

from utils import log, get_db_connection

app = Flask(__name__)

def log_error(msg):
    log(msg, log_file='flask.log')

@app.route('/')
def index():
    html_path = '/var/www/finn/index.html'
    log_error(f"Mottok forespørsel for /, sjekker {html_path}")
    if os.path.exists(html_path):
        log_error("Serverer index.html")
        return send_file(html_path)
    else:
        log_error("index.html ikke funnet")
        return jsonify({'error': 'index.html ikke funnet'}), 404

@app.route('/api/update_category/<finn_code>', methods=['POST'])
def update_category(finn_code):
    log_error(f"Mottok POST-forespørsel for /api/update_category/{finn_code}")
    data = request.get_json(silent=True)
    if not data or 'category' not in data:
        log_error(f"Ugyldig forespørsel for Finn-kode {finn_code}: Mangler category-verdi")
        return jsonify({'error': 'Ugyldig forespørsel, mangler category-verdi'}), 400
    
    category = data['category']
    if category not in ['Void', 'Varmepumpe', 'Ubehandlet']:
        log_error(f"Ugyldig kategori for Finn-kode {finn_code}: {category}")
        return jsonify({'error': f'Ugyldig kategori: {category}'}), 400
    
    log_error(f"Forsøker å oppdatere kategori for Finn-kode {finn_code} til {category}")
    
    conn = get_db_connection()
    if not conn:
        log_error(f"Kan ikke oppdatere kategori for Finn-kode {finn_code}: Ingen databasetilkobling")
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        cur = conn.cursor()
        cur.execute("SELECT 1 FROM torget WHERE finn_code = %s;", (finn_code,))
        if cur.rowcount == 0:
            log_error(f"Ingen annonse funnet med Finn-kode {finn_code}")
            cur.close()
            conn.close()
            return jsonify({'error': f'Ingen annonse funnet med Finn-kode {finn_code}'}), 404
        cur.execute("UPDATE torget SET category = %s WHERE finn_code = %s;", (category, finn_code))
        conn.commit()
        log_error(f"Kategori oppdatert for Finn-kode {finn_code} til {category}")
        cur.close()
        conn.close()
        return jsonify({'success': True})
    except Exception as e:
        log_error(f"Feil ved oppdatering av kategori for Finn-kode {finn_code}: {e}")
        return jsonify({'error': f'Feil ved oppdatering av kategori: {str(e)}'}), 500

@app.route('/api/get_heat_pumps', methods=['GET'])
def get_heat_pumps():
    log_error("Mottok GET-forespørsel for /api/get_heat_pumps")
    conn = get_db_connection()
    if not conn:
        log_error("Kan ikke hente data fra torget: Ingen databasetilkobling")
        return jsonify({'error': 'Database connection failed'}), 500
    
    try:
        cur = conn.cursor()
        cur.execute("SELECT finn_code, title, price, created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Oslo' AS created_at, category, KategoriTest FROM torget ORDER BY created_at DESC;")
        items = [
            {
                'finn_code': row[0] if row[0] is not None else '',
                'title': row[1] if row[1] is not None else '',
                'price': row[2] if row[2] is not None else '',
                'created_at': row[3].strftime("%Y-%m-%d %H:%M:%S") if row[3] is not None else '',
                'category': row[4] if row[4] is not None else 'Ubehandlet',
                'KategoriTest': row[5] if row[5] is not None else ''
            } for row in cur.fetchall()
        ]
        cur.close()
        conn.close()
        log_error(f"Hentet {len(items)} rader fra torget")
        return jsonify({'items': items, 'updated_at': datetime.now(ZoneInfo("Europe/Oslo")).strftime("%Y-%m-%d %H:%M:%S")})
    except Exception as e:
        log_error(f"Feil ved henting av data fra torget: {e}")
        return jsonify({'error': f'Feil ved henting av data: {str(e)}'}), 500

@app.route('/api/scraper_status', methods=['GET'])
def get_scraper_status():
    log_error("Mottok GET-forespørsel for /api/scraper_status")
    status_file = "/var/www/finn/scraper_status.txt"
    try:
        if os.path.exists(status_file):
            with open(status_file, 'r') as f:
                status = f.read().strip()
            log_error(f"Scraper status hentet: {status}")
            return jsonify({'status': status})
        else:
            log_error("Scraper statusfil ikke funnet, antar Idle")
            return jsonify({'status': 'Idle'})
    except Exception as e:
        log_error(f"Feil ved henting av scraper status: {e}")
        return jsonify({'error': f'Feil ved henting av scraper status: {str(e)}'}), 500

@app.route('/api/ocr_status', methods=['GET'])
def get_ocr_status():
    log_error("Mottok GET-forespørsel for /api/ocr_status")
    status_file = "/var/www/finn/ocr_status.txt"
    try:
        if os.path.exists(status_file):
            with open(status_file, 'r') as f:
                status = f.read().strip()
            log_error(f"OCR status hentet fra {status_file}: {status}")
            return jsonify({'status': status})
        else:
            log_error("OCR statusfil ikke funnet, antar Idle")
            return jsonify({'status': 'Idle'})
    except Exception as e:
        log_error(f"Feil ved henting av OCR status: {e}")
        return jsonify({'error': f'Feil ved henting av OCR status: {str(e)}'}), 500

@app.route('/api/category_status', methods=['GET'])
def get_category_status():
    log_error("Mottok GET-forespørsel for /api/category_status")
    status_file = "/var/www/finn/category_status.txt"
    try:
        if os.path.exists(status_file):
            with open(status_file, 'r') as f:
                status = f.read().strip()
            log_error(f"Category status hentet: {status}")
            return jsonify({'status': status})
        else:
            log_error("Category statusfil ikke funnet, antar Idle")
            return jsonify({'status': 'Idle'})
    except Exception as e:
        log_error(f"Feil ved henting av category status: {e}")
        return jsonify({'error': f'Feil ved henting av category status: {str(e)}'}), 500

if __name__ == '__main__':
    log_error("Starter Flask-server på port 5001")
    try:
        app.run(host='0.0.0.0', port=5001)
    except Exception as e:
        log_error(f"Feil ved oppstart av Flask-server: {e}")
        raise
