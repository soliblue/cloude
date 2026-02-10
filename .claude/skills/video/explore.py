import asyncio, json, sys, os
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'browser-data')

async def get_proxy():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '.env')
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

async def explore():
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

        async def log_response(response):
            url = response.url
            if '/backend/' not in url:
                return
            print(f"  <- {response.status} {url[:120]}")
            if 'drafts' in url and '/read' in url:
                try:
                    body = await response.json()
                    print(f"  DRAFT BODY: {json.dumps(body, indent=2)[:2000]}")
                except:
                    pass

        page.on('request', lambda req: print(f"  -> {req.method} {req.url[:120]}") if '/backend/' in req.url else None)
        page.on('response', log_response)

        print("Opening sora.chatgpt.com...")
        await page.goto('https://sora.chatgpt.com/', timeout=60000)

        print("\nBrowser is open. All /backend/ requests are logged above.")
        print("Navigate around Sora to find your generated video.")
        print("Type 'done' to close.\n")

        while True:
            line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
            if line.strip().lower() == 'done':
                break

        await context.close()

if __name__ == '__main__':
    asyncio.run(explore())
