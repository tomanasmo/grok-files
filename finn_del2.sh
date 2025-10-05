#!/bin/bash
# finn_del2.sh v128
# Del 2: Nginx, Flask, utils.py, scraper.py, ocr.py, index.html
# Oppdatert for å generere index.html v1.2 med tabell for finn_code, title, price, KategoriTest

LOGFILE="/tmp/finn_setup.log"
echo "Starting finn_del2.sh at $(date)" >> "$LOGFILE"

# Valider skriptets syntaks før kjøring
if ! bash -n "$0" >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Syntaksfeil i skriptet. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    echo "Linjer nær feilen:" >> "$LOGFILE"
    tail -n 20 "$0" >> "$LOGFILE"
    exit 1
fi
echo "✅ Skriptsyntaks validert." | tee -a "$LOGFILE"

echo "🚀 Fortsetter oppsett for FINN scraper - Del 2: Nginx, Flask, utils.py, scraper.py, ocr.py, index.html..." | tee -a "$LOGFILE"

# 1. Installer Nginx og Flask
echo "📦 Installer Nginx, Flask og BeautifulSoup..." | tee -a "$LOGFILE"
if ! sudo apt update >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke oppdatere pakker." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo apt install -y nginx python3-flask python3-bs4 >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke installere Nginx, Flask og BeautifulSoup." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Nginx, Flask og BeautifulSoup installert." | tee -a "$LOGFILE"

# 2. Konfigurer Nginx
echo "🌐 Konfigurerer Nginx..." | tee -a "$LOGFILE"
TEMP_NGINX_CONF="/tmp/finn.conf"
cat > "$TEMP_NGINX_CONF" << 'EOF'
server {
    listen 80;
    server_name finn.agn3s.com localhost;

    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass_header Content-Type;
    }

    location /static {
        alias /var/www/finn/static;
        expires 1y;
        add_header Cache-Control "public";
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_min_length 256;

    error_log /var/log/nginx/finn_error.log;
    access_log /var/log/nginx/finn_access.log;
}
EOF

# Kopier Nginx-konfigurasjon
if ! sudo cp "$TEMP_NGINX_CONF" /etc/nginx/sites-available/finn.conf >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke kopiere Nginx-konfigurasjon til /etc/nginx/sites-available/finn.conf." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo ln -sf /etc/nginx/sites-available/finn.conf /etc/nginx/sites-enabled/finn.conf >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke opprette symlink for Nginx-konfigurasjon." | tee -a "$LOGFILE"
    exit 1
fi

# Valider Nginx-konfigurasjon
if ! sudo nginx -t >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Ugyldig Nginx-konfigurasjon. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    exit 1
fi

# Reload Nginx
if ! sudo systemctl reload nginx >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke restarte Nginx. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Nginx konfigurert og restartet." | tee -a "$LOGFILE"

# 3. Lag utils.py
echo "🧠 Genererer utils.py v1.6 for logging og database..." | tee -a "$LOGFILE"
TEMP_UTILS_PY="/tmp/utils.py.tmp"
cat > "$TEMP_UTILS_PY" << 'EOF'
# utils.py v1.6
import logging
import psycopg2
from datetime import datetime

def log(msg, log_file='utils.log'):
    logging.basicConfig(filename=f'/var/www/finn/{log_file}', level=logging.INFO, format='[%(asctime)s] %(message)s')
    logging.info(msg)

def get_db_connection():
    try:
        conn = psycopg2.connect(
            dbname="finn",
            user="www-data",
            password="finn_2025",
            host="localhost",
            port="5434"
        )
        log("Vellykket tilkobling til database")
        return conn
    except Exception as e:
        log(f"Feil ved tilkobling til database: {e}")
        return None
EOF
if ! sudo mv "$TEMP_UTILS_PY" /var/www/finn/utils.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke opprette utils.py." | tee -a "$LOGFILE"
    exit 1
fi
sudo chown www-data:www-data /var/www/finn/utils.py >> "$LOGFILE" 2>&1
sudo chmod 644 /var/www/finn/utils.py >> "$LOGFILE" 2>&1
echo "✅ utils.py opprettet." | tee -a "$LOGFILE"

# 4. Lag scraper.py
echo "🧠 Genererer scraper.py v1.6 for FINN.no scraping..." | tee -a "$LOGFILE"
TEMP_SCRAPER_PY="/tmp/scraper.py.tmp"
cat > "$TEMP_SCRAPER_PY" << 'EOF'
# scraper.py v1.6
import requests
import re
from bs4 import BeautifulSoup
from utils import log, get_db_connection

def scrape_finn():
    url = "https://www.finn.no/recommerce/forsale/search?q=varmepumpe"
    log(f"Starter scraping av {url}", log_file='scraper.log')
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
    except requests.RequestException as e:
        log(f"Feil ved henting av {url}: {e}", log_file='scraper.log')
        return
    soup = BeautifulSoup(response.text, 'lxml')
    items = soup.find_all('article')
    conn = get_db_connection()
    if not conn:
        log("Ingen databasetilkobling, avslutter", log_file='scraper.log')
        return
    cur = conn.cursor()
    for item in items:
        finn_code = item.get('data-finn-code')
        title = item.find('h2')
        title = title.text.strip() if title else 'Ukjent'
        price = item.find('span', class_='price')
        price = price.text.strip() if price else 'Ukjent'
        created = item.find('time')
        created = created.get('datetime') if created else None
        try:
            cur.execute(
                "INSERT INTO torget (finn_code, title, price, created) VALUES (%s, %s, %s, %s) ON CONFLICT (finn_code) DO NOTHING;",
                (finn_code, title, price, created)
            )
        except Exception as e:
            log(f"Feil ved lagring av Finn-kode {finn_code}: {e}", log_file='scraper.log')
            continue
    conn.commit()
    log("Scraping fullført", log_file='scraper.log')
    cur.close()
    conn.close()

if __name__ == "__main__":
    scrape_finn()
EOF
if ! sudo mv "$TEMP_SCRAPER_PY" /var/www/finn/scraper.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke opprette scraper.py." | tee -a "$LOGFILE"
    exit 1
fi
sudo chown www-data:www-data /var/www/finn/scraper.py >> "$LOGFILE" 2>&1
sudo chmod 644 /var/www/finn/scraper.py >> "$LOGFILE" 2>&1
echo "✅ scraper.py opprettet." | tee -a "$LOGFILE"

# 5. Lag ocr.py
echo "🧠 Genererer ocr.py v1.6 for OCR-behandling..." | tee -a "$LOGFILE"
TEMP_OCR_PY="/tmp/ocr.py.tmp"
cat > "$TEMP_OCR_PY" << 'EOF'
# ocr.py v1.6
import pytesseract
import psycopg2
from PIL import Image
from utils import log, get_db_connection

def process_ocr():
    conn = get_db_connection()
    if not conn:
        log("Ingen databasetilkobling, avslutter", log_file='ocr.log')
        return
    cur = conn.cursor()
    try:
        cur.execute("SELECT finn_code FROM torget WHERE category IS NULL;")
        finn_codes = cur.fetchall()
    except Exception as e:
        log(f"Feil ved henting av Finn-koder for OCR: {e}", log_file='ocr.log')
        cur.close()
        conn.close()
        return
    for (finn_code,) in finn_codes:
        image_path = f"/var/www/finn/debug/{finn_code}.jpg"
        log(f"Starter OCR for Finn-kode {finn_code}", log_file='ocr.log')
        try:
            text = pytesseract.image_to_string(Image.open(image_path))
            category = 'Varmepumpe' if 'varmepumpe' in text.lower() else 'Ubehandlet'
            cur.execute("UPDATE torget SET category = %s WHERE finn_code = %s;", (category, finn_code))
            conn.commit()
            log(f"OCR fullført for Finn-kode {finn_code}: {category}", log_file='ocr.log')
        except Exception as e:
            log(f"Feil under OCR for Finn-kode {finn_code}: {e}", log_file='ocr.log')
            continue
    cur.close()
    conn.close()

if __name__ == "__main__":
    process_ocr()
EOF
if ! sudo mv "$TEMP_OCR_PY" /var/www/finn/ocr.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke opprette ocr.py." | tee -a "$LOGFILE"
    exit 1
fi
sudo chown www-data:www-data /var/www/finn/ocr.py >> "$LOGFILE" 2>&1
sudo chmod 644 /var/www/finn/ocr.py >> "$LOGFILE" 2>&1
echo "✅ ocr.py opprettet." | tee -a "$LOGFILE"

# 6. Lag index.html
echo "🧠 Genererer index.html v1.2 med tabell for webgrensesnitt..." | tee -a "$LOGFILE"
TEMP_INDEX_HTML="/tmp/index.html.tmp"
cat > "$TEMP_INDEX_HTML" << 'EOF'
<!-- index.html v1.2 -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>FINN Scraper</title>
    <style>
        table {
            border-collapse: collapse;
            width: 100%;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
        tr:nth-child(even) {background-color: #f9f9f9;}
    </style>
</head>
<body>
    <h1>Varmepumper fra FINN.no</h1>
    <table id="heat-pumps">
        <thead>
            <tr>
                <th>Finnkode</th>
                <th>Tittel</th>
                <th>Pris</th>
                <th>Kategori</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>
    <script>
        async function loadHeatPumps() {
            try {
                const response = await fetch('/api/get_heat_pumps');
                if (!response.ok) throw new Error('Network error');
                const data = await response.json();
                const tbody = document.querySelector('#heat-pumps tbody');
                tbody.innerHTML = data.items.map(item => `
                    <tr>
                        <td>${item.finn_code}</td>
                        <td>${item.title}</td>
                        <td>${item.price}</td>
                        <td>${item.KategoriTest || 'Ukjent'}</td>
                    </tr>
                `).join('');
            } catch (error) {
                console.error('Feil ved lasting av varmepumper:', error);
                document.querySelector('#heat-pumps tbody').innerHTML = '<tr><td colspan="4">Kunne ikke laste data</td></tr>';
            }
        }
        loadHeatPumps();
    </script>
</body>
</html>
EOF
if ! sudo mv "$TEMP_INDEX_HTML" /var/www/finn/index.html >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke opprette index.html." | tee -a "$LOGFILE"
    exit 1
fi
sudo chown www-data:www-data /var/www/finn/index.html >> "$LOGFILE" 2>&1
sudo chmod 644 /var/www/finn/index.html >> "$LOGFILE" 2>&1
echo "✅ index.html opprettet." | tee -a "$LOGFILE"

# 7. Test Flask direkte
echo "🔍 Tester Flask direkte på http://127.0.0.1:5001..." | tee -a "$LOGFILE"
if curl -s http://127.0.0.1:5001 > /dev/null; then
    echo "✅ Flask svarer på http://127.0.0.1:5001." | tee -a "$LOGFILE"
else
    echo "❌ Feil: Flask svarer ikke på http://127.0.0.1:5001. Sjekker flask.log..." | tee -a "$LOGFILE"
    cat /var/www/finn/flask.log >> "$LOGFILE" 2>&1
    exit 1
fi

echo "✅ Del 2 fullført: Nginx, Flask, utils.py, scraper.py, ocr.py og index.html satt opp." | tee -a "$LOGFILE"