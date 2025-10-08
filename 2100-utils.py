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
