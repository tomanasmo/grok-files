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
