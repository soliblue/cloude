import asyncio, json, sys, os
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'browser-data')

async def get_proxy():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '.env')
    api_key = None
    with open(env_path) as f:
        for line in f:
            if line.startswith('WEBSHARE_API_KEY='):
                api_key = line.strip().split('=', 1)[1]
    import requests
    r = requests.get('https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&country_code__in=US&page_size=1',
        headers={'Authorization': f'Token {api_key}'})
    p = r.json()['results'][0]
    return {
        'server': f"http://{p['proxy_address']}:{p['port']}",
        'username': p['username'],
        'password': p['password'],
    }

async def test():
    print("Fetching US proxy...")
    proxy = await get_proxy()

    async with async_playwright() as p:
        context = await p.chromium.launch_persistent_context(
            user_data_dir=BROWSER_DATA,
            headless=False,
            channel='chrome',
            proxy=proxy,
            args=['--disable-blink-features=AutomationControlled'],
        )
        page = context.pages[0] if context.pages else await context.new_page()
        print("Loading sora...")
        await page.goto('https://sora.chatgpt.com/', timeout=60000)
        await page.wait_for_timeout(5000)

        print("Fetching API data...\n")
        result = await page.evaluate("""
            async () => {
                const sessionResp = await fetch('/api/auth/session');
                const session = await sessionResp.json();
                const token = session.accessToken;
                const headers = { 'Authorization': 'Bearer ' + token };

                const pending = await (await fetch('/backend/nf/pending/v2', { headers })).json();
                const drafts = await (await fetch('/backend/project_y/profile/drafts?limit=5', { headers })).json();
                const profile_feed = await (await fetch('/backend/project_y/profile_feed/me?limit=5&cut=nf2', { headers })).json();

                return { pending, drafts, profile_feed };
            }
        """)

        print("=== PENDING ===")
        print(json.dumps(result['pending'], indent=2)[:1500])
        print("\n=== DRAFTS ===")
        print(json.dumps(result['drafts'], indent=2)[:3000])
        print("\n=== PROFILE FEED ===")
        print(json.dumps(result['profile_feed'], indent=2)[:3000])

        await context.close()

if __name__ == '__main__':
    asyncio.run(test())
