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
