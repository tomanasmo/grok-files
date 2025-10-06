# scraper.py v1.1
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
        if not finn_code:
            continue
        # Hent tittel
        title = item.find('h2')
        title = title.text.strip() if title else 'Ukjent'
        # Hent pris
        price_elem = item.find('span', class_=re.compile(r'price|status__price'))
        price = price_elem.text.strip().replace('\xa0', ' ') if price_elem else 'N/A'
        # Hent opprettelsestid
        created = item.find('time')
        created = created.get('datetime') if created else None
        # Hent beskrivelse fra annonsesiden
        description = 'N/A'
        try:
            ad_url = f"https://www.finn.no/recommerce/forsale/item/{finn_code}"
            ad_response = requests.get(ad_url, timeout=10)
            ad_response.raise_for_status()
            ad_soup = BeautifulSoup(ad_response.text, 'lxml')
            desc_meta = ad_soup.find('meta', property='og:description')
            description = desc_meta['content'].strip() if desc_meta else 'N/A'
        except requests.RequestException as e:
            log(f"Feil ved henting av beskrivelse for Finn-kode {finn_code}: {e}", log_file='scraper.log')
        try:
            cur.execute(
                "INSERT INTO torget (finn_code, title, price, created, description) VALUES (%s, %s, %s, %s, %s) ON CONFLICT (finn_code) DO UPDATE SET title = EXCLUDED.title, price = EXCLUDED.price, created = EXCLUDED.created, description = EXCLUDED.description;",
                (finn_code, title, price, created, description)
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
