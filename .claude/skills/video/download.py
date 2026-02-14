import asyncio, json, os, time, requests
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'browser-data')
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output', 'raw')

async def get_proxy():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '.env')
    api_key = None
    with open(env_path) as f:
        for line in f:
            if line.startswith('WEBSHARE_API_KEY='):
                api_key = line.strip().split('=', 1)[1]
    r = requests.get('https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&country_code__in=US&page_size=1',
        headers={'Authorization': f'Token {api_key}'})
    p = r.json()['results'][0]
    return {
        'server': f"http://{p['proxy_address']}:{p['port']}",
        'username': p['username'],
        'password': p['password'],
    }

async def download_recent(limit=20):
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    existing_sizes = {os.path.getsize(os.path.join(OUTPUT_DIR, f)) for f in os.listdir(OUTPUT_DIR) if f.endswith('.mp4')}

    print("Fetching US proxy...")
    proxy = await get_proxy()

    p_instance = await async_playwright().start()
    context = await p_instance.chromium.launch_persistent_context(
        user_data_dir=BROWSER_DATA,
        headless=False,
        channel='chrome',
        proxy=proxy,
        args=['--disable-blink-features=AutomationControlled'],
    )
    page = context.pages[0] if context.pages else await context.new_page()

    print("Loading sora.chatgpt.com...")
    await page.goto('https://sora.chatgpt.com/', timeout=60000)
    await page.wait_for_timeout(5000)

    title = await page.title()
    if 'moment' in title.lower():
        print("ERROR: Cloudflare challenge. Re-run session.py login")
        await context.close()
        return

    print(f"Page loaded: {title}")

    drafts = await page.evaluate(f"""
        async () => {{
            const session = await (await fetch('/api/auth/session')).json();
            const resp = await fetch('/backend/project_y/profile/drafts?limit={limit}', {{
                headers: {{ 'Authorization': 'Bearer ' + session.accessToken }}
            }});
            return await resp.json();
        }}
    """)

    items = drafts.get('items') or []
    print(f"\nFound {len(items)} recent drafts on Sora")

    proxy_url = f"http://{proxy['username']}:{proxy['password']}@{proxy['server'].replace('http://', '')}"
    downloaded = []
    skipped = 0

    for draft in items:
        url = draft.get('download_urls', {}).get('no_watermark') or draft.get('downloadable_url')
        if not url:
            continue

        prompt = draft.get('prompt', '?')[:60]
        width = draft.get('width', '?')
        height = draft.get('height', '?')
        duration = draft.get('duration_s', '?')

        r = requests.head(url, proxies={'https': proxy_url, 'http': proxy_url}, timeout=30)
        content_length = int(r.headers.get('content-length', 0))

        if content_length in existing_sizes:
            skipped += 1
            continue

        print(f"\n  Downloading: {prompt}...")
        print(f"  Size: {width}x{height}, {duration}s")
        r = requests.get(url, proxies={'https': proxy_url, 'http': proxy_url}, timeout=120)
        timestamp = int(time.time() * 1000) % 10000000000
        filepath = os.path.join(OUTPUT_DIR, f"sora_{timestamp}.mp4")
        with open(filepath, 'wb') as f:
            f.write(r.content)
        size_mb = len(r.content) / 1024 / 1024
        print(f"  Saved: {filepath} ({size_mb:.1f} MB)")
        downloaded.append(filepath)
        existing_sizes.add(len(r.content))
        time.sleep(0.5)

    await context.close()
    await p_instance.stop()

    print(f"\n{'='*50}")
    print(f"Downloaded: {len(downloaded)} new, Skipped: {skipped} already had")
    for path in downloaded:
        print(f"  {path}")

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Download recent Sora videos without generating new ones')
    parser.add_argument('--limit', '-l', type=int, default=20, help='Number of recent drafts to check (default: 20)')
    args = parser.parse_args()
    asyncio.run(download_recent(args.limit))
