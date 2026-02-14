import asyncio, json, sys, os
from playwright.async_api import async_playwright

CHROME_USER_DATA = os.path.join(os.path.expanduser('~'), 'Library', 'Application Support', 'Google', 'Chrome')
PROFILE = 'Profile 3'
PROXY_API_URL = 'https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&country_code__in=US&page_size=1'

async def get_proxy():
    env_path = os.path.join(os.path.dirname(__file__), '..', '..', '..', '.env')
    api_key = None
    with open(env_path) as f:
        for line in f:
            if line.startswith('WEBSHARE_API_KEY='):
                api_key = line.strip().split('=', 1)[1]

    import requests
    r = requests.get(PROXY_API_URL, headers={'Authorization': f'Token {api_key}'})
    p = r.json()['results'][0]
    return {
        'server': f"http://{p['proxy_address']}:{p['port']}",
        'username': p['username'],
        'password': p['password'],
    }

async def login():
    print("Fetching US proxy...")
    proxy = await get_proxy()
    print(f"Using proxy: {proxy['server']}")

    async with async_playwright() as p:
        context = await p.chromium.launch_persistent_context(
            user_data_dir=CHROME_USER_DATA,
            headless=False,
            channel='chrome',
            proxy=proxy,
            viewport={'width': 1280, 'height': 900},
            args=[
                '--disable-blink-features=AutomationControlled',
                f'--profile-directory={PROFILE}',
            ],
        )

        page = context.pages[0] if context.pages else await context.new_page()
        await page.goto('https://sora.chatgpt.com/', timeout=60000)

        print("\nBrowser opened with your personal Chrome profile.")
        print("Sign in to Sora if needed. Waiting for login (checking every 3s)...\n")

        for i in range(120):
            title = await page.title()
            if 'sora' in title.lower() and 'moment' not in title.lower():
                cookies = await context.cookies()
                auth = [c for c in cookies if 'session-token' in c['name']]
                if auth:
                    print(f"Logged in! Title: {title}")
                    print(f"Session cookies saved in Chrome profile.")
                    await context.close()
                    print("Done — session persisted.")
                    return
            await page.wait_for_timeout(3000)

        print("Timeout — didn't detect login after 6 minutes.")
        await context.close()

if __name__ == '__main__':
    asyncio.run(login())
