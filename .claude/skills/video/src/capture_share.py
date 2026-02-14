import asyncio, json, sys, os
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'browser')

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

async def capture():
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

        print("Fetching full draft data for latest video...\n")
        result = await page.evaluate("""
            async () => {
                const session = await (await fetch('/api/auth/session')).json();
                const token = session.accessToken;
                const headers = { 'Authorization': 'Bearer ' + token };

                const drafts = await (await fetch('/backend/project_y/profile/drafts?limit=3', { headers })).json();

                // Also try to read the first draft
                let draftDetail = null;
                if (drafts.items && drafts.items.length > 0) {
                    const genId = drafts.items[0].id;
                    try {
                        const readResp = await fetch('/backend/project_y/profile/drafts/' + genId + '/read', {
                            method: 'POST',
                            headers: { ...headers, 'Content-Type': 'application/json' },
                        });
                        draftDetail = await readResp.json();
                    } catch(e) {}
                }

                return { drafts, draftDetail };
            }
        """)

        print("=== LATEST DRAFT (full) ===")
        if result['drafts'].get('items'):
            print(json.dumps(result['drafts']['items'][0], indent=2))

        print("\n=== DRAFT DETAIL (from /read) ===")
        if result.get('draftDetail'):
            print(json.dumps(result['draftDetail'], indent=2)[:3000])

        await context.close()

if __name__ == '__main__':
    asyncio.run(capture())
