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
