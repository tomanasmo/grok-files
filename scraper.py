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
