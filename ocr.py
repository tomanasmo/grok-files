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
