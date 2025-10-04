#!/bin/bash
# finn_del3b_v126.sh (Del 3B: category.py, index.html, status-/loggfiler, tjenester, tester)

LOGFILE="/tmp/finn_setup.log"
echo "Starting finn_del3b_v126.sh at $(date)" >> "$LOGFILE"

# Valider skriptets syntaks før kjøring
if ! bash -n "$0" >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Syntaksfeil i skriptet. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    echo "Linjer nær feilen:" >> "$LOGFILE"
    tail -n 20 "$0" >> "$LOGFILE"
    exit 1
fi
echo "✅ Skriptsyntaks validert." | tee -a "$LOGFILE"

echo "🚀 Fortsetter oppsett for FINN scraper - Del 3B: category.py, index.html, status-/loggfiler, tjenester, tester..." | tee -a "$LOGFILE"

# 1. Lag category.py v1.6
echo "🧠 Genererer category.py v1.6 for kategorioppdatering..." | tee -a "$LOGFILE"
TEMP_CATEGORY_PY="/tmp/category.py.tmp"
cat > "$TEMP_CATEGORY_PY" << 'EOF'
# category.py v1.6
import os
import requests
import re
from bs4 import BeautifulSoup
from utils import log, get_db_connection

def fetch_category(finn_code):
    url = f"https://www.finn.no/recommerce/forsale/item/{finn_code}"
    log(f"Henter kategori for Finn-kode {finn_code} fra {url}", log_file='category.log')
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        log(f"Vellykket respons fra {url}", log_file='category.log')
    except requests.RequestException as e:
        log(f"Feil ved henting av URL {url}: {e}", log_file='category.log')
        return None

    # Lagre rå HTML for feilsøking
    debug_path = f"/var/www/finn/debug/{finn_code}.html"
    try:
        with open(debug_path, 'w', encoding='utf-8') as f:
            f.write(response.text)
        log(f"Rå HTML lagret til {debug_path}", log_file='category.log')
    except Exception as e:
        log(f"Feil ved lagring av rå HTML for {finn_code}: {e}", log_file='category.log')

    try:
        soup = BeautifulSoup(response.text, 'lxml')
        breadcrumb = soup.find('nav', id='breadcrumbs')
        if not breadcrumb:
            log(f"Ingen breadcrumb funnet for Finn-kode {finn_code}", log_file='category.log')
            return None
        
        log(f"Funnet breadcrumb for Finn-kode {finn_code}: {breadcrumb}", log_file='category.log')
        div = breadcrumb.find('div', class_='flex space-x-8')
        if not div:
            log(f"Ingen div med class 'flex space-x-8' i breadcrumb for Finn-kode {finn_code}", log_file='category.log')
            return None
        
        items = div.find_all('a', class_='s-text-link')
        log(f"Fant {len(items)} a-elementer med class 's-text-link' i breadcrumb for Finn-kode {finn_code}: {items}", log_file='category.log')
        
        categories = []
        for item in items:
            item_str = str(item).strip()
            match = re.search(r'>((?:[^<>]+|<[^>]+>)*?)<', item_str)
            if match:
                text = re.sub(r'<[^>]+>', '', match.group(1)).strip()
                categories.append(text)
            else:
                categories.append('')
        log(f"Rå kategorier funnet: {categories}", log_file='category.log')
        
        if not categories:
            log(f"Ingen kategorier ekstrahert for Finn-kode {finn_code}", log_file='category.log')
            return None
        
        category = categories[-1] if categories else None
        log(f"Ekstrahert kategori for Finn-kode {finn_code}: {category}", log_file='category.log')
        return category
    except Exception as e:
        log(f"Feil ved parsing av kategori for Finn-kode {finn_code}: {e}", log_file='category.log')
        return None

def update_categories():
    status_file = "/var/www/finn/category_status.txt"
    try:
        with open(status_file, 'w') as f:
            f.write("Running")
        log("Starter kategorioppdatering for KategoriTest...", log_file='category.log')
        
        conn = get_db_connection()
        if not conn:
            log("Kan ikke oppdatere KategoriTest: Ingen databasetilkobling", log_file='category.log')
            return
        
        cur = conn.cursor()
        cur.execute("SELECT finn_code FROM torget WHERE KategoriTest IS NULL OR KategoriTest = '' OR KategoriTest = 'Ubehandlet';")
        rows = cur.fetchall()
        
        log(f"Fant {len(rows)} annonser for KategoriTest-oppdatering", log_file='category.log')
        
        for row in rows:
            finn_code = row[0]
            category = fetch_category(finn_code)
            if category:
                cur.execute("UPDATE torget SET KategoriTest = %s WHERE finn_code = %s;", (category, finn_code))
                conn.commit()
                log(f"Oppdatert KategoriTest for Finn-kode {finn_code} til {category}", log_file='category.log')
            else:
                log(f"Ingen kategori funnet for Finn-kode {finn_code}", log_file='category.log')
        
        cur.close()
        conn.close()
        log("KategoriTest-oppdatering fullført.", log_file='category.log')
    except Exception as e:
        log(f"Feil i KategoriTest-oppdatering: {e}", log_file='category.log')
    finally:
        with open(status_file, 'w') as f:
            f.write("Idle")

if __name__ == '__main__':
    update_categories()
EOF

if ! sudo mv "$TEMP_CATEGORY_PY" /var/www/finn/category.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke flytte category.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/category.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for category.py." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/category.py >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for category.py." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ category.py v1.6 generert." | tee -a "$LOGFILE"

# 2. Lag index.html v9
echo "📄 Genererer index.html v9 for webgrensesnitt..." | tee -a "$LOGFILE"
TEMP_INDEX_HTML="/tmp/index.html.tmp"
cat > "$TEMP_INDEX_HTML" << 'EOF'
<!DOCTYPE html>
<html lang="no">
<head>
    <meta charset="UTF-8">
    <title>Varmepumper på FINN</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .statuses { font-weight: bold; margin-bottom: 10px; }
        .status { color: green; margin-bottom: 10px; }
        .filters { margin-bottom: 10px; }
        .filters label { margin-right: 15px; }
    </style>
    <script>
        let allAds = []; // Lagre rådata for filtrering

        // Oppdater kategori via POST-forespørsel
        async function updateCategory(finn_code, category) {
            try {
                const response = await fetch(`/api/update_category/${finn_code}`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ category: category })
                });
                const data = await response.json();
                if (data.success) {
                    fetchAds(); // Oppdater tabellen for å vise ny kategori
                }
            } catch (error) {
                // Ingen tilbakemelding, feil logges på serversiden
            }
        }

        // Oppdater statuser
        async function fetchStatuses() {
            const statusesDiv = document.getElementById('statuses');
            statusesDiv.innerHTML = 'Laster statuser...';
            let statusText = '';
            try {
                const scraperResponse = await fetch('/api/scraper_status');
                const scraperData = await scraperResponse.json();
                statusText += `Scraper: ${scraperData.status} | `;
            } catch (error) {
                statusText += 'Scraper: Feil | ';
            }
            try {
                const ocrResponse = await fetch('/api/ocr_status');
                const ocrData = await ocrResponse.json();
                statusText += `OCR: ${ocrData.status} | `;
            } and
            try {
                const categoryResponse = await fetch('/api/category_status');
                const categoryData = await categoryResponse.json();
                statusText += `Category: ${categoryData.status} | `;
            } catch (error) {
                statusText += 'Category: Feil | ';
            }
            statusesDiv.innerHTML = statusText.slice(0, -3); // Fjern siste "| "
        }

        // Filtrer annonser basert på avkrysningsbokser
        function filterAds() {
            const showUbehandlet = document.getElementById('filterUbehandlet').checked;
            const showVoid = document.getElementById('filterVoid').checked;
            const showVarmepumpe = document.getElementById('filterVarmepumpe').checked;
            const tableBody = document.getElementById('adsTable').getElementsByTagName('tbody')[0];
            tableBody.innerHTML = ''; // Tøm tabellen

            // Sjekk om minst én boks er avkrysset
            if (!showUbehandlet && !showVoid && !showVarmepumpe) {
                document.getElementById('status').innerText = 'Ingen kategorier valgt';
                return;
            }

            const filteredAds = allAds.filter(item => {
                return (showUbehandlet && item.category === 'Ubehandlet') ||
                       (showVoid && item.category === 'Void') ||
                       (showVarmepumpe && item.category === 'Varmepumpe');
            });

            filteredAds.forEach(item => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><a href="https://www.finn.no/recommerce/forsale/item/${item.finn_code}" target="_blank">${item.finn_code || ''}</a></td>
                    <td>${item.title || ''}</td>
                    <td>${item.price || ''}</td>
                    <td>${item.created_at || ''}</td>
                    <td>${item.KategoriTest || ''}</td>
                    <td>
                        <select onchange="updateCategory('${item.finn_code}', this.value)">
                            <option value="Ubehandlet" ${item.category === 'Ubehandlet' ? 'selected' : ''}>Ubehandlet</option>
                            <option value="Varmepumpe" ${item.category === 'Varmepumpe' ? 'selected' : ''}>Varmepumpe</option>
                            <option value="Void" ${item.category === 'Void' ? 'selected' : ''}>Void</option>
                        </select>
                    </td>
                `;
                tableBody.appendChild(row);
            });

            document.getElementById('status').innerText = `Sist oppdatert: ${allAds.length > 0 ? allAds[0].updated_at : 'Ukjent'}, Antall rader: ${filteredAds.length}`;
        }

        // Asynkron henting av annonser
        async function fetchAds() {
            try {
                const response = await fetch('/api/get_heat_pumps');
                const data = await response.json();
                if (data.error) {
                    document.getElementById('status').innerText = 'Feil ved henting av annonser: ' + data.error;
                    return;
                }
                allAds = data.items || []; // Lagre rådata
                allAds.updated_at = data.updated_at || 'Ukjent';
                filterAds(); // Filtrer og vis annonser
            } catch (error) {
                document.getElementById('status').innerText = 'Feil ved henting av annonser: ' + error;
            }
        }

        // Kjør begge funksjonene ved lasting
        window.onload = () => {
            fetchStatuses();
            fetchAds();
        };
    </script>
</head>
<body>
    <h1>Varmepumper på FINN</h1>
    <div class="filters">
        <label><input type="checkbox" id="filterUbehandlet" onchange="filterAds()" checked> Ubehandlet</label>
        <label><input type="checkbox" id="filterVoid" onchange="filterAds()"> Void</label>
        <label><input type="checkbox" id="filterVarmepumpe" onchange="filterAds()"> Varmepumpe</label>
    </div>
    <div id="statuses" class="statuses">Laster statuser...</div>
    <div id="status" class="status">Laster annonser...</div>
    <table id="adsTable">
        <thead>
            <tr>
                <th>Finn-kode</th>
                <th>Tittel</th>
                <th>Pris</th>
                <th>Opprettet</th>
                <th>Finn-kategori</th>
                <th>Kategori</th>
            </tr>
        </thead>
        <tbody></tbody>
    </table>
</body>
</html>
EOF

if ! sudo mv "$TEMP_INDEX_HTML" /var/www/finn/index.html >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke flytte index.html." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown www-data:www-data /var/www/finn/index.html >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for index.html." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/index.html >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for index.html." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ index.html v9 generert." | tee -a "$LOGFILE"

# 3. Stopp og deaktiver finn-index.service (hvis den eksisterer)
echo "🛑 Sjekker og deaktiverer finn-index.service..." | tee -a "$LOGFILE"
if systemctl list-unit-files | grep -q "finn-index.service"; then
    if systemctl is-active --quiet finn-index.service; then
        sudo systemctl stop finn-index.service >> "$LOGFILE" 2>&1 || echo "⚠️ Advarsel: Kunne ikke stoppe finn-index.service, fortsetter..." | tee -a "$LOGFILE"
    fi
    if systemctl is-enabled --quiet finn-index.service; then
        sudo systemctl disable finn-index.service >> "$LOGFILE" 2>&1 || echo "⚠️ Advarsel: Kunde ikke deaktivere finn-index.service, fortsetter..." | tee -a "$LOGFILE"
    fi
    if [ -f /etc/systemd/system/finn-index.service ]; then
        sudo rm /etc/systemd/system/finn-index.service >> "$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            echo "❌ Feil: Kunne ikke fjerne finn-index.service." | tee -a "$LOGFILE"
            exit 1
        fi
    fi
    sudo systemctl daemon-reload >> "$LOGFILE" 2>&1
    echo "✅ finn-index.service stoppet og deaktivert." | tee -a "$LOGFILE"
else
    echo "✅ finn-index.service finnes ikke, ingen handling nødvendig." | tee -a "$LOGFILE"
fi

# 4. Slett generate_index.py hvis den eksisterer
echo "🗑️ Sletter generate_index.py hvis den eksisterer..." | tee -a "$LOGFILE"
if [ -f /var/www/finn/generate_index.py ]; then
    if ! sudo rm /var/www/finn/generate_index.py >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke slette generate_index.py." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ generate_index.py fjernet." | tee -a "$LOGFILE"

# 5. Slett index_status.txt hvis den eksisterer
echo "🗑️ Sletter index_status.txt hvis den eksisterer..." | tee -a "$LOGFILE"
if [ -f /var/www/finn/index_status.txt ]; then
    if ! sudo rm /var/www/finn/index_status.txt >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke slette index_status.txt." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ index_status.txt fjernet." | tee -a "$LOGFILE"

# 6. Opprett statusfiler
echo "📄 Oppretter statusfiler..." | tee -a "$LOGFILE"
echo "Idle" | sudo tee /var/www/finn/scraper_status.txt >> "$LOGFILE" 2>&1
echo "Idle" | sudo tee /var/www/finn/ocr_status.txt >> "$LOGFILE" 2>&1
echo "Idle" | sudo tee /var/www/finn/category_status.txt >> "$LOGFILE" 2>&1
if ! sudo chown www-data:www-data /var/www/finn/*_status.txt >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for statusfiler." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/*_status.txt >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for statusfiler." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Statusfiler opprettet." | tee -a "$LOGFILE"

# 7. Opprett logfiler
echo "📝 Oppretter logfiler..." | tee -a "$LOGFILE"
touch /var/www/finn/scraper.log /var/www/finn/ocr.log /var/www/finn/flask.log /var/www/finn/category.log
if ! sudo chown www-data:www-data /var/www/finn/*.log >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for logfiler." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /var/www/finn/*.log >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for logfiler." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Logfiler opprettet." | tee -a "$LOGFILE"

# 8. Konfigurer logrotate for loggfiler
echo "🔄 Konfigurerer logrotate for loggfiler..." | tee -a "$LOGFILE"
if ! command -v logrotate > /dev/null; then
    echo "🔍 Installerer logrotate..." | tee -a "$LOGFILE"
    if ! sudo apt-get install -y logrotate >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke installere logrotate." | tee -a "$LOGFILE"
        exit 1
    fi
fi
cat > /tmp/finn-logrotate.conf << 'EOF'
/var/www/finn/*.log {
    daily
    rotate 7
    size 10M
    compress
    delaycompress
    missingok
    notifempty
    create 644 www-data www-data
    postrotate
        /bin/kill -HUP `cat /var/run/syslogd.pid 2> /dev/null` 2> /dev/null || true
    endscript
}
EOF
if ! sudo mv /tmp/finn-logrotate.conf /etc/logrotate.d/finn >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke opprette logrotate-konfigurasjon." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown root:root /etc/logrotate.d/finn >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for logrotate-konfigurasjon." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /etc/logrotate.d/finn >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for logrotate-konfigurasjon." | tee -a "$LOGFILE"
    exit 1
fi
# Test logrotate-konfigurasjon
if ! sudo logrotate -d /etc/logrotate.d/finn >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Logrotate-konfigurasjonstest mislyktes. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Logrotate konfigurert for loggfiler." | tee -a "$LOGFILE"

# 9. Installer curl for Flask-test
echo "📦 Installerer curl for Flask-test..." | tee -a "$LOGFILE"
if ! command -v curl > /dev/null; then
    if ! sudo apt-get update >> "$LOGFILE" 2>&1 || ! sudo apt-get install -y curl >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke installere curl. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ curl installert." | tee -a "$LOGFILE"

# 10. Opprett systemd-tjeneste for finn.service
echo "⚙️ Genererer finn.service..." | tee -a "$LOGFILE"
TEMP_SERVICE="/tmp/finn.service.tmp"
cat > "$TEMP_SERVICE" << 'EOF'
[Unit]
Description=FINN Scraper
After=network.target

[Service]
ExecStart=/usr/bin/python3 /var/www/finn/scraper.py
Restart=always
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5
User=www-data
Environment=PYTHONUNBUFFERED=1
WorkingDirectory=/var/www/finn

[Install]
WantedBy=multi-user.target
EOF

if ! sudo mv "$TEMP_SERVICE" /etc/systemd/system/finn.service >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke flytte finn.service." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chown root:root /etc/systemd/system/finn.service >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke endre eier for finn.service." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo chmod 644 /etc/systemd/system/finn.service >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke sette rettigheter for finn.service." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ finn.service generert." | tee -a "$LOGFILE"

# 11. Start eller restart systemd-tjenester
echo "🚀 Starter eller restarter systemd-tjenester..." | tee -a "$LOGFILE"
for service in finn.service finn-web.service finn-ocr.service finn-category.service; do
    if ! sudo cp /var/www/finn/$service /etc/systemd/system/ >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke kopiere $service til /etc/systemd/system/." | tee -a "$LOGFILE"
        exit 1
    fi
    if ! sudo systemctl enable $service >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke aktivere $service." | tee -a "$LOGFILE"
        exit 1
    fi
    if ! sudo systemctl restart $service >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke restarte $service. Sjekker journalctl..." | tee -a "$LOGFILE"
        sudo journalctl -u $service -n 50 >> "$LOGFILE" 2>&1
        exit 1
    fi
    echo "✅ $service startet." | tee -a "$LOGFILE"
    # Sjekk tjenestestatus
    if ! sudo systemctl is-active --quiet $service; then
        echo "❌ Feil: $service kjører ikke etter restart. Sjekker journalctl..." | tee -a "$LOGFILE"
        sudo journalctl -u $service -n 50 >> "$LOGFILE" 2>&1
        exit 1
    fi
done
if ! sudo systemctl daemon-reload >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunde ikke laste inn systemd-konfigurasjoner." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Systemd-tjenester startet." | tee -a "$LOGFILE"

# 12. Test Flask direkte
echo "🔍 Tester Flask direkte på http://127.0.0.1:5001..." | tee -a "$LOGFILE"
if curl -s http://127.0.0.1:5001 > /dev/null; then
    echo "✅ Flask svarer på http://127.0.0.1:5001." | tee -a "$LOGFILE"
else
    echo "❌ Feil: Flask svarer ikke på http://127.0.0.1:5001. Sjekker flask.log..." | tee -a "$LOGFILE"
    cat /var/www/finn/flask.log >> "$LOGFILE" 2>&1
    exit 1
fi

# 13. Test PostgreSQL-tilkobling lokalt
echo "🔍 Tester PostgreSQL-tilkobling lokalt på port 5434..." | tee -a "$LOGFILE"
if PGPASSWORD=finn_2025 psql -h localhost -p 5434 -U www-data -d finn -w -c "SELECT 1;" >> "$LOGFILE" 2>&1; then
    echo "✅ PostgreSQL-tilkobling fungerer lokalt på port 5434." | tee -a "$LOGFILE"
else
    echo "❌ Feil: PostgreSQL-tilkobling mislyktes lokalt på port 5434. Sjekker PostgreSQL-logger..." | tee -a "$LOGFILE"
    PG_VERSION=$(ls /etc/postgresql/ | grep -E '^[0-9]+$' | sort -nr | head -n 1)
    cat /var/log/postgresql/postgresql-${PG_VERSION}-main.log >> "$LOGFILE" 2>&1
    exit 1
fi

echo "✅ Del 3B fullført: category.py, index.html, status-/loggfiler, tjenester og tester satt opp." | tee -a "$LOGFILE"
echo "✅ Klar! utils.py, scraper.py, ocr.py, app.py, category.py, index.html, finn.service, finn-web.service, finn-ocr.service, finn-category.service og Nginx-konfigurasjon er satt opp." | tee -a "$LOGFILE"
echo "👉 Sjekk status med:" | tee -a "$LOGFILE"
echo "   sudo systemctl status finn.service" | tee -a "$LOGFILE"
echo "   sudo systemctl status finn-web.service" | tee -a "$LOGFILE"
echo "   sudo systemctl status finn-ocr.service" | tee -a "$LOGFILE"
echo "   sudo systemctl status finn-category.service" | tee -a "$LOGFILE"
echo "👉 Sjekk kategori-logger med:" | tee -a "$LOGFILE"
echo "   cat /var/www/finn/category.log" | tee -a "$LOGFILE"