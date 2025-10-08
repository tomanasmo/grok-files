#!/bin/bash
# finn_del1_v57.sh

LOGFILE="/tmp/finn_setup.log"
echo "Starting finn_del1_v57.sh at $(date)" > "$LOGFILE"

echo "🚀 Starter oppsett for FINN scraper - Del 1: Stoppe tjenester, konfigurere locale og installere pakker..." | tee -a "$LOGFILE"

# 1. Installer locales-pakken hvis den mangler
echo "📦 Installerer locales-pakken for UTF-8-støtte..." | tee -a "$LOGFILE"
if ! dpkg -l | grep -q locales; then
    if ! sudo apt-get update >> "$LOGFILE" 2>&1 || ! sudo apt-get install -y locales >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunne ikke installere locales-pakken. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ locales-pakken installert." | tee -a "$LOGFILE"

# 2. Konfigurer en_US.UTF-8 og nb_NO.UTF-8 locale
echo "🔍 Konfigurerer en_US.UTF-8 og nb_NO.UTF-8 locale..." | tee -a "$LOGFILE"
if ! locale -a | grep -q "en_US.utf8"; then
    echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen >> "$LOGFILE" 2>&1
fi
if ! locale -a | grep -q "nb_NO.utf8"; then
    echo "nb_NO.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen >> "$LOGFILE" 2>&1
fi
if ! sudo locale-gen en_US.UTF-8 nb_NO.UTF-8 >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Kunne ikke generere en_US.UTF-8 eller nb_NO.UTF-8 locale." | tee -a "$LOGFILE"
    exit 1
fi

# Aktiver locale med dpkg-reconfigure
echo "🔄 Aktiverer locale med dpkg-reconfigure..." | tee -a "$LOGFILE"
sudo dpkg-reconfigure -f noninteractive locales >> "$LOGFILE" 2>&1

# Sett locale i /etc/default/locale og /etc/environment
echo "LANG=en_US.UTF-8" | sudo tee /etc/default/locale > /dev/null
echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/default/locale > /dev/null
echo "LANG=en_US.UTF-8" | sudo tee -a /etc/environment > /dev/null
echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/environment > /dev/null

# Eksporter locale i skriptets miljø
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
source /etc/profile 2>/dev/null || true
echo "✅ en_US.UTF-8 og nb_NO.UTF-8 locale konfigurert. Start ny terminal eller bruk SSH hvis emoji eller norske tegn (å, ø, æ) ikke vises korrekt i Proxmox-konsollen." | tee -a "$LOGFILE"

# Test locale
if locale | grep -q "en_US.UTF-8"; then
    echo "✅ Locale-test: UTF-8 støtte bekreftet." | tee -a "$LOGFILE"
else
    echo "⚠️ Advarsel: Locale kan kreve omstart av terminalen eller SSH for full effekt." | tee -a "$LOGFILE"
fi

# 3. Sjekk og konverter skriptets filkoding til UTF-8
echo "🔍 Sjekker filkoding for $0..." | tee -a "$LOGFILE"
if ! file "$0" | grep -q "UTF-8"; then
    echo "⚠️ Advarsel: Skriptet er ikke i UTF-8. Konverterer til UTF-8..." | tee -a "$LOGFILE"
    if ! sudo apt-get install -y iconv >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunne ikke installere iconv. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
        exit 1
    fi
    TEMP_SCRIPT="/tmp/finn_del1_temp.sh"
    if ! iconv -f WINDOWS-1252 -t UTF-8 "$0" > "$TEMP_SCRIPT" >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunne ikke konvertere skript til UTF-8." | tee -a "$LOGFILE"
        exit 1
    fi
    sudo mv "$TEMP_SCRIPT" "$0" >> "$LOGFILE" 2>&1
    sudo chmod +x "$0" >> "$LOGFILE" 2>&1
    echo "✅ Skript konvertert til UTF-8. Kjør skriptet på nytt." | tee -a "$LOGFILE"
    exit 0
fi
echo "✅ Skriptet er i UTF-8." | tee -a "$LOGFILE"

# 4. Installer console-setup for konsoll-fontstøtte
echo "📦 Installerer console-setup for konsoll-fontkonfigurasjon..." | tee -a "$LOGFILE"
if ! dpkg -l | grep -q console-setup; then
    if ! sudo apt-get update >> "$LOGFILE" 2>&1 || ! sudo apt-get install -y console-setup >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunde ikke installere console-setup. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ console-setup installert." | tee -a "$LOGFILE"

# 5. Konfigurer konsoll-font til Lat2-Terminus16 for bedre Unicode-støtte
echo "🔧 Konfigurerer konsoll-font til Lat2-Terminus16 for bedre Unicode-støtte..." | tee -a "$LOGFILE"
echo "CODESET=\"Lat2\"" | sudo tee /etc/default/console-setup > /dev/null
echo "FONTFACE=\"Terminus\"" | sudo tee -a /etc/default/console-setup > /dev/null
echo "FONTSIZE=\"16x32\"" | sudo tee -a /etc/default/console-setup > /dev/null
sudo setupcon >> "$LOGFILE" 2>&1 || echo "⚠️ Advarsel: setupcon kan kreve omstart eller ny TTY for full effekt." | tee -a "$LOGFILE"
echo "✅ Konsoll-font konfigurert. For Proxmox-konsoll, bruk SSH med Windows Terminal for bedre emoji-støtte." | tee -a "$LOGFILE"

# 6. Installer fonts-noto-color-emoji for emoji-støtte
echo "📦 Installerer fonts-noto-color-emoji for emoji-støtte..." | tee -a "$LOGFILE"
if ! dpkg -l | grep -q fonts-noto-color-emoji; then
    if ! sudo apt-get update >> "$LOGFILE" 2>&1 || ! sudo apt-get install -y fonts-noto-color-emoji >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunne ikke installere fonts-noto-color-emoji. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ fonts-noto-color-emoji installert." | tee -a "$LOGFILE"

# 7. Test emoji og norske tegn
echo "🧪 Tester emoji og norske tegn (å, ø, æ) i terminalen..." | tee -a "$LOGFILE"
echo -e "\U1F680 🚀 ✅ å ø æ" | tee -a "$LOGFILE"
echo "✅ Emoji- og tegn-test fullført (sjekk om rakett, hake og å, ø, æ vises korrekt over). For Proxmox-konsoll, bruk SSH med Windows Terminal hvis noe mangler." | tee -a "$LOGFILE"

# 8. Stopp eksisterende tjenester for å unngå portkonflikter
echo "🛑 Stopper eksisterende finn.service og finn-web.service..." | tee -a "$LOGFILE"
sudo systemctl stop finn.service >> "$LOGFILE" 2>&1 || echo "⚠️ Advarsel: Kunne ikke stoppe finn.service, fortsetter..." | tee -a "$LOGFILE"
sudo systemctl stop finn-web.service >> "$LOGFILE" 2>&1 || echo "⚠️ Advarsel: Kunde ikke stoppe finn-web.service, fortsetter..." | tee -a "$LOGFILE"
sudo systemctl disable finn.service >> "$LOGFILE" 2>&1 || echo "⚠️ Advarsel: Kunne ikke deaktivere finn.service, fortsetter..." | tee -a "$LOGFILE"
sudo systemctl disable finn-web.service >> "$LOGFILE" 2>&1 || echo "⚠️ Advarsel: Kunde ikke deaktivere finn-web.service, fortsetter..." | tee -a "$LOGFILE"

# 9. Installer net-tools for netstat
echo "📦 Installerer net-tools for netstat..." | tee -a "$LOGFILE"
if ! command -v netstat > /dev/null; then
    if ! sudo apt-get update >> "$LOGFILE" 2>&1 || ! sudo apt-get install -y net-tools >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: Kunne ikke installere net-tools. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ net-tools (netstat) installert." | tee -a "$LOGFILE"

# 10. Sjekk og drep prosesser på port 5001
echo "🔍 Sjekker om port 5001 er i bruk..." | tee -a "$LOGFILE"
if sudo netstat -tuln | grep ':5001' >> "$LOGFILE" 2>&1; then
    echo "Port 5001 er i bruk. Identifiserer prosess..." | tee -a "$LOGFILE"
    PID=$(sudo netstat -tulnp | grep ':5001' | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$PID" ]; then
        echo "Dreper prosess med PID $PID..." | tee -a "$LOGFILE"
        sudo kill -9 "$PID" >> "$LOGFILE" 2>&1 || {
            echo "❌ Feil: Kunne ikke drepe prosess på port 5001." | tee -a "$LOGFILE"
            exit 1
        }
    else
        echo "❌ Feil: Kunne ikke identifisere prosess på port 5001." | tee -a "$LOGFILE"
        exit 1
    fi
fi
echo "✅ Port 5001 er nå ledig." | tee -a "$LOGFILE"

# 11. Installer nødvendige pakker system-wide, inkludert Nginx
echo "📦 Installerer requests, beautifulsoup4, pillow, tesseract-ocr, tesseract-ocr-nor, pip, postgresql, psycopg2 og nginx..." | tee -a "$LOGFILE"
if ! sudo apt update >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: apt update mislyktes. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    exit 1
fi
if ! sudo apt install -y python3-requests python3-bs4 python3-pil tesseract-ocr tesseract-ocr-nor python3-pip postgresql python3-psycopg2 nginx >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: apt install mislyktes. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    exit 1
fi

# Installer Python-avhengigheter via pip
echo "📦 Installerer pytesseract, pandas, numpy, bottleneck, flask og jinja2 via pip..." | tee -a "$LOGFILE"
sudo pip3 uninstall -y bottleneck >> "$LOGFILE" 2>&1 || true
if ! sudo pip3 install --break-system-packages pytesseract pandas numpy==1.26.4 bottleneck==1.4.0 flask jinja2 >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: pip install pytesseract, pandas, numpy, bottleneck, flask eller jinja2 mislyktes. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
    exit 1
fi

# Sjekk installerte versjoner
echo "🔍 Sjekker installerte versjoner av numpy og bottleneck..." | tee -a "$LOGFILE"
NUMPY_VERSION=$(pip3 show numpy | grep '^Version:' | awk '{print $2}')
BOTTLENECK_VERSION=$(pip3 show bottleneck | grep '^Version:' | awk '{print $2}')
echo "Numpy versjon: $NUMPY_VERSION" | tee -a "$LOGFILE"
echo "Bottleneck versjon: $BOTTLENECK_VERSION" | tee -a "$LOGFILE"
if [[ "$NUMPY_VERSION" == "1.26.4" && "$BOTTLENECK_VERSION" == "1.4.0" ]]; then
    echo "✅ Korrekte versjoner av numpy (1.26.4) og bottleneck (1.4.0) er installert." | tee -a "$LOGFILE"
else
    echo "❌ Feil: Forventede versjoner (numpy==1.26.4, bottleneck==1.4.0) ble ikke installert korrekt. Faktiske versjoner: numpy=$NUMPY_VERSION, bottleneck=$BOTTLENECK_VERSION" | tee -a "$LOGFILE"
    exit 1
fi

# Sjekk om tesseract er installert og tilgjengelig i PATH
echo "🔍 Sjekker om tesseract-ocr er tilgjengelig..." | tee -a "$LOGFILE"
if ! command -v tesseract >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: tesseract-ocr er ikke installert eller ikke i PATH. Prøver å installere igjen..." | tee -a "$LOGFILE"
    sudo apt install -y tesseract-ocr >> "$LOGFILE" 2>&1 || {
        echo "❌ Feil: Kunde ikke installere tesseract-ocr. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
        exit 1
    }
fi
echo "✅ tesseract-ocr er tilgjengelig." | tee -a "$LOGFILE"

# Sjekk om port 5001 er ledig for Flask
echo "🔍 Dobbeltsjekker om port 5001 er ledig for Flask..." | tee -a "$LOGFILE"
if sudo netstat -tuln | grep ':5001' >> "$LOGFILE" 2>&1; then
    echo "❌ Feil: Port 5001 er fortsatt i bruk etter forsøk på å drepe prosess." | tee -a "$LOGFILE"
    exit 1
fi
echo "✅ Port 5001 er ledig." | tee -a "$LOGFILE"

# Sjekk om port 5432 er ledig for PostgreSQL
echo "🔍 Sjekker om port 5432 er ledig for PostgreSQL..." | tee -a "$LOGFILE"
if ! sudo netstat -tuln | grep ':5432' >> "$LOGFILE" 2>&1; then
    echo "⚠️ Advarsel: Port 5432 er ikke i bruk. Sjekker om PostgreSQL kjører..." | tee -a "$LOGFILE"
    if ! sudo systemctl status postgresql >> "$LOGFILE" 2>&1; then
        echo "❌ Feil: PostgreSQL-tjenesten kjører ikke. Starter tjenesten..." | tee -a "$LOGFILE"
        sudo systemctl start postgresql >> "$LOGFILE" 2>&1 || {
            echo "❌ Feil: Kunne ikke starte PostgreSQL. Sjekk $LOGFILE for detaljer." | tee -a "$LOGFILE"
            exit 1
        }
    fi
fi
echo "✅ Port 5432 er i bruk av PostgreSQL." | tee -a "$LOGFILE"

echo "✅ Del 1 fullført: Tjenester stoppet, locale konfigurert og pakker installert." | tee -a "$LOGFILE"
echo "👉 Kjør finn_del2_v75.sh for å fortsette med Nginx- og PostgreSQL-konfigurasjon." | tee -a "$LOGFILE"