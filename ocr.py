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
