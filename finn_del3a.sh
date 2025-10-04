#!/bin/bash
# finn_del3a_v128.sh (Del 3A: Prosjektmappe, utils.py, app.py, scraper.py, ocr.py, config.json)

LOGFILE="/tmp/finn_setup.log"
echo "Starting finn_del3a_v128.sh at $(date)" >> "$LOGFILE"

# Valider skriptets syntaks før kjøring
if ! bash -n "$0" >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Syntaksfeil i skriptet. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    echo "Linjer nær feilen:" >> "$LOGFILE"
    tail -n 20 "$0" >> "$LOGFILE"
    exit 1
fi
echo "✅ Skriptsyntaks validert." | tee -a "$LOGFILE"

echo "🚀 Fortsetter oppsett for FINN scraper - Del 3A: Prosjektmappe, utils.py, app.py, scraper.py, ocr.py, config.json..." | tee -a "$LOGFILE"

# Sett miljøvariabler for konfig (løs kobling)
export DB_NAME="finn"
export DB_USER="www-data"
export DB_PASSWORD="finn_2025"
export DB_HOST="localhost"
export DB_PORT="5434"
export LOG_DIR="/var/www/finn"

# Sjekk Python-avhengigheter
echo "🔍 Sjekker Python-avhengigheter..." | tee -a "$LOGFILE"
for pkg in requests bs4 psycopg2 pandas jinja2 pytesseract lxml; do
    if ! pip3 show "$pkg" >> "$LOGFILE" 2>&1; then
        echo "Feil: Python-pakken $pkg er ikke installert. Installerer..." | tee -a "$LOGFILE"
        if ! sudo pip3 install --break-system-packages "$pkg" >> "$LOGFILE" 2>&1; then
            echo "❌ Feil: Kunne ikke installere $pkg. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
            exit 1
        fi
    fi
done
echo "✅ Alle Python-avhengigheter er installert." | tee -a "$LOGFILE"

# 1. Opprett prosjektmappe
echo "📁 Oppretter /var/www/finn..." | tee -a "$LOGFILE"
if ! mkdir -p /var/www/finn >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke opprette /var/www/finn." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke endre eier til www-data for /var/www/finn." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 755 /var/www/finn >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for /var/www/finn." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Prosjektmappe opprettet." | tee -a "$LOGFILE"

# 2. Opprett debug-mappe
echo "📁 Oppretter debug-mappe /var/www/finn/debug..." | tee -a "$LOGFILE"
if ! mkdir -p /var/www/finn/debug >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke opprette debug-mappe." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/debug >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for debug-mappe." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 755 /var/www/finn/debug >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for debug-mappe." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Debug-mappe opprettet." | tee -a "$LOGFILE"

# 3. Lag config.json
echo "📋 Genererer config.json for URL-konfigurasjon..." | tee -a "$LOGFILE"
TEMP_CONFIG_JSON="/tmp/config.json.tmp"
cat > "$TEMP_CONFIG_JSON" << 'EOF'
{
    "urls": [
        "https://www.finn.no/recommerce/forsale/search?q=255+40+20",
        "https://www.finn.no/recommerce/forsale/search?q=275+40+20"
    ]
}
EOF

if ! sudo mv "$TEMP_CONFIG_JSON" /var/www/finn/config.json >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke flytte config.json." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/config.json >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for config.json." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/config.json >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for config.json." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ config.json generert." | tee -a "$LOGFILE"

# 4. Lag utils.py v1.2
echo "🧰 Genererer utils.py v1.2 for felles funksjoner..." | tee -a "$LOGFILE"
TEMP_UTILS_PY="/tmp/utils.py.tmp"
cat > "$TEMP_UTILS_PY" << 'EOF'
# utils.py v1.2 - Felles funksjoner for logging, DB og konfig

import os
import psycopg2
from datetime import datetime
from zoneinfo import ZoneInfo

# Last konfig fra miljøvariabler (fall back til default)
DB_NAME = os.getenv('DB_NAME', 'finn')
DB_USER = os.getenv('DB_USER', 'www-data')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'finn_2025')
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '5434')
LOG_DIR = os.getenv('LOG_DIR', '/var/www/finn')

def log(msg, log_file='scraper.log'):
    now = datetime.now(ZoneInfo("Europe/Oslo")).strftime("%Y-%m-%d %H:%M:%S")
    full_path = os.path.join(LOG_DIR, log_file)
    try:
        with open(full_path, "a", encoding='utf-8') as f:
            f.write(f"[{now}] {msg}\n")
    except Exception as e:
        print(f"Feil ved logging til {log_file}: {e}")
    print(msg)

def get_db_connection():
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT
        )
        log("Vellykket tilkobling til database", log_file='utils.log')
        return conn
    except Exception as e:
        log(f"Feil ved tilkobling til database: {e}", log_file='utils.log')
        return None
EOF

if ! sudo mv "$TEMP_UTILS_PY" /var/www/finn/utils.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke flytte utils.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/utils.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for utils.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/utils.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for utils.py." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ utils.py v1.2 generert." | tee -a "$LOGFILE"

# 5. Test databaseforbindelse
echo "🔍 Tester databaseforbindelse for www-data..." | tee -a "$LOGFILE"
if PGPASSWORD=finn_2025 psql -h localhost -p 5434 -U www-data -d finn -w -c "SELECT 1;" >> "$LOGFILE" 2>&1; then
    echo "✅ Databaseforbindelse fungerer for www-data på port 5434." | tee -a "$LOGFILE"
else
    echo "❌ Feil: Databaseforbindelse mislyktes for www-data på port 5434. Sjekk PostgreSQL-logger..." | tee -a "$LOGFILE"
    PG_VERSION=$(ls /etc/postgresql/ | grep -E '^[0-9]+$' | sort -nr | head -n 1)
    cat /var/log/postgresql/postgresql-${PG_VERSION}-main.log | tail -n 50 >> "$LOGFILE" 2>&1
    exit 1
fi

# 6. Lag app.py v91
echo "🧠 Genererer app.py v91 for Flask-webserver..." | tee -a "$LOGFILE"
TEMP_APP_PY="/tmp/app.py.tmp"
cat > "$TEMP_APP_PY" << 'EOF'
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
EOF

if ! sudo mv "$TEMP_APP_PY" /var/www/finn/app.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke flytte app.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/app.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for app.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/app.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for app.py." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ app.py v91 generert." | tee -a "$LOGFILE"

# 7. Lag scraper.py v1.4
echo "🧠 Genererer scraper.py v1.4 for scraping..." | tee -a "$LOGFILE"
TEMP_SCRAPER_PY="/tmp/scraper.py.tmp"
cat > "$TEMP_SCRAPER_PY" << 'EOF'
# scraper.py v1.4
import requests
import time
import json
import re
import random
from bs4 import BeautifulSoup
from utils import log, get_db_connection

SCRAPER_VERSION = "2025-10-01-v1.4"

def update_scraper_status(status):
    try:
        with open("/var/www/finn/scraper_status.txt", "w", encoding='utf-8') as f:
            f.write(status)
        log(f"Scraper status oppdatert til: {status}", log_file='scraper.log')
    except Exception as e:
        log(f"Feil ved oppdatering av scraper status: {e}", log_file='scraper.log')

def load_urls():
    config_file = "/var/www/finn/config.json"
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
            urls = config.get('urls', [])
            if not urls:
                log("Ingen URL-er funnet i config.json", log_file='scraper.log')
                return []
            log(f"Lastet {len(urls)} URL-er fra config.json", log_file='scraper.log')
            return urls
    except FileNotFoundError:
        log(f"Konfigurasjonsfil {config_file} ikke funnet", log_file='scraper.log')
        return []
    except json.JSONDecodeError as e:
        log(f"Feil ved parsing av config.json: {e}", log_file='scraper.log')
        return []
    except Exception as e:
        log(f"Uventet feil ved lasting av config.json: {e}", log_file='scraper.log')
        return []

def save_or_update_to_db(finn_code, title, price):
    conn = get_db_connection()
    if not conn:
        log("Kan ikke lagre i database: Ingen tilkobling", log_file='scraper.log')
        return
    
    try:
        cur = conn.cursor()
        cur.execute("SELECT category FROM torget WHERE finn_code = %s;", (finn_code,))
        existing = cur.fetchone()
        
        if existing:
            cur.execute("""
                UPDATE torget
                SET title = %s,
                    price = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE finn_code = %s;
            """, (title, price, finn_code))
            log(f"Oppdatert Finn-kode {finn_code} i databasen, beholdt kategori '{existing[0]}'", log_file='scraper.log')
        else:
            cur.execute("""
                INSERT INTO torget (finn_code, title, price, category, created_at, updated_at, ocr_processed)
                VALUES (%s, %s, %s, 'Ubehandlet', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, FALSE);
            """, (finn_code, title, price))
            log(f"Lagret ny Finn-kode {finn_code} i databasen med kategori 'Ubehandlet'", log_file='scraper.log')
        
        conn.commit()
    except Exception as e:
        log(f"Feil ved lagring/oppdatering av Finn-kode {finn_code}: {e}", log_file='scraper.log')
    finally:
        cur.close()
        conn.close()

def scrape_ad(ad_url, finn_code):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        log(f"Henter annonse: {ad_url}", log_file='scraper.log')
        response = requests.get(ad_url, headers=headers, timeout=10)
        response.raise_for_status()
        log(f"Scraping annonse: {ad_url} - Statuskode: {response.status_code} - Scraper versjon: {SCRAPER_VERSION}", log_file='scraper.log')
        
        soup = BeautifulSoup(response.text, 'html.parser')
        title_elem = soup.find('title')
        title = title_elem.text.strip().replace(" | FINN-torget", "") if title_elem else "N/A"
        
        price_elem = soup.find('span', class_='u-strong')
        price = price_elem.text.strip() if price_elem else "N/A"
        
        return title, price
    except Exception as e:
        log(f"Feil ved scraping av annonse {ad_url}: {e}", log_file='scraper.log')
        return None, None

def scrape_search_page(url, page_number):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        log(f"Henter søkeside: {url}", log_file='scraper.log')
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        log(f"Scraping søkeside: {url} - Statuskode: {response.status_code}", log_file='scraper.log')
        
        soup = BeautifulSoup(response.text, 'html.parser')
        links = soup.find_all('a', href=re.compile(r'https://www.finn.no/recommerce/forsale/item/\d+'), id=re.compile(r'\d+'))
        log(f"Antall lenker funnet på søkeside {url}: {len(links)}", log_file='scraper.log')
        
        if not links:
            if "Ingen resultater" in response.text:
                log(f"Ingen resultater funnet på side {page_number}. Avslutter paginering.", log_file='scraper.log')
                return None, page_number
            log(f"Ingen lenker funnet på søkeside {url}.", log_file='scraper.log')
            return None, page_number
        
        for link in links:
            href = link.get('href')
            finn_code = link.get('id')
            if href and finn_code:
                ad_url = href
                log(f"Behandler annonse: Finn-kode {finn_code}, URL: {ad_url}", log_file='scraper.log')
                title, price = scrape_ad(ad_url, finn_code)
                if title and price:
                    save_or_update_to_db(finn_code, title, price)
                time.sleep(random.uniform(2, 5))  # Tilfeldig forsinkelse
            else:
                log(f"Ugyldig lenke eller finnkode på {url}: href={href}, id={finn_code}", log_file='scraper.log')
        
        next_page = page_number + 1
        if page_number == 1:
            next_url = f"{url}&page={next_page}"
        else:
            next_url = url.replace(f"page={page_number}", f"page={next_page}")
        log(f"Neste side URL: {next_url}", log_file='scraper.log')
        return next_url, next_page
    except Exception as e:
        log(f"Feil ved scraping av søkeside {url}: {e}", log_file='scraper.log')
        return None, page_number

def main_scrape_loop():
    while True:
        update_scraper_status("Running")
        try:
            urls = load_urls()
            if not urls:
                log("Ingen URL-er å skrape, hopper over denne syklusen", log_file='scraper.log')
                update_scraper_status("Idle")
                time.sleep(60)
                continue
            
            for base_url in urls:
                page = 1
                current_url = base_url if page == 1 else f"{base_url}&page={page}"
                while current_url:
                    current_url, page = scrape_search_page(current_url, page)
                    if not current_url:
                        log(f"Avslutter paginering for {base_url}", log_file='scraper.log')
                        break
                    time.sleep(random.uniform(2, 5))
            
            log("Scraper i hvilemodus, venter 10 minutter", log_file='scraper.log')
            update_scraper_status("Idle")
            time.sleep(600)  # 10 minutter hvile
        except Exception as e:
            log(f"Kritisk feil i hovedløkke: {e}", log_file='scraper.log')
            update_scraper_status("Error")
            time.sleep(60)  # Kort pause ved krasj

if __name__ == '__main__':
    main_scrape_loop()
EOF

if ! sudo mv "$TEMP_SCRAPER_PY" /var/www/finn/scraper.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke flytte scraper.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/scraper.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for scraper.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/scraper.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for scraper.py." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ scraper.py v1.4 generert." | tee -a "$LOGFILE"

# 8. Lag ocr.py v1.1
echo "🧠 Genererer ocr.py v1.1 for OCR-behandling..." | tee -a "$LOGFILE"
TEMP_OCR_PY="/tmp/ocr.py.tmp"
cat > "$TEMP_OCR_PY" << 'EOF'
# ocr.py v1.1
import pytesseract
import time
import os
from PIL import Image
from utils import log, get_db_connection

def process_ocr(finn_code):
    log(f"Starter OCR for Finn-kode {finn_code}", log_file='ocr.log')
    
    image_path = f"/var/www/finn/debug/{finn_code}.jpg"
    if not os.path.exists(image_path):
        log(f"Bilde ikke funnet for Finn-kode {finn_code}: {image_path}", log_file='ocr.log')
        return
    
    try:
        ocr_text = pytesseract.image_to_string(Image.open(image_path), lang='nor')
        
        conn = get_db_connection()
        if not conn:
            log("Ingen databasetilkobling, avslutter OCR", log_file='ocr.log')
            return
        
        cur = conn.cursor()
        cur.execute("UPDATE torget SET ocr_text = %s, ocr_processed = TRUE WHERE finn_code = %s;",
                    (ocr_text, finn_code))
        conn.commit()
        cur.close()
        conn.close()
        log(f"OCR fullført for Finn-kode {finn_code}", log_file='ocr.log')
    except Exception as e:
        log(f"Feil under OCR for Finn-kode {finn_code}: {e}", log_file='ocr.log')

if __name__ == '__main__':
    while True:
        with open('/var/www/finn/ocr_status.txt', 'w', encoding='utf-8') as f:
            f.write("Running")
        conn = get_db_connection()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("SELECT finn_code FROM torget WHERE ocr_processed = FALSE LIMIT 1;")
                row = cur.fetchone()
                if row:
                    finn_code = row[0]
                    process_ocr(finn_code)
                else:
                    log("Ingen ubehandlede Finn-koder for OCR", log_file='ocr.log')
                cur.close()
                conn.close()
            except Exception as e:
                log(f"Feil ved henting av Finn-koder for OCR: {e}", log_file='ocr.log')
        with open('/var/www/finn/ocr_status.txt', 'w', encoding='utf-8') as f:
            f.write("Idle")
        time.sleep(60)  # Vent 60 sekunder før neste syklus
EOF

if ! sudo mv "$TEMP_OCR_PY" /var/www/finn/ocr.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke flytte ocr.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/ocr.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for ocr.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/ocr.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for ocr.py." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ ocr.py v1.1 generert." | tee -a "$LOGFILE"

echo "✅ Del 3A fullført: Prosjektmappe, utils.py, app.py, scraper.py, ocr.py, config.json satt opp." | tee -a "$LOGFILE"
echo "👉 Kjør deretter finn_del3b_v126.sh for å fullføre oppsettet." | tee -a "$LOGFILE"