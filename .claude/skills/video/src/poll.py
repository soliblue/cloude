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

async def poll(task_id):
    print("Fetching US proxy...")
    proxy = await get_proxy()

    async with async_playwright() as p:
        context = await p.chromium.launch_persistent_context(
            user_data_dir=BROWSER_DATA,
            headless=True,
            channel='chrome',
            proxy=proxy,
            args=['--disable-blink-features=AutomationControlled'],
        )
        page = context.pages[0] if context.pages else await context.new_page()
        print("Loading sora...")
        await page.goto('https://sora.chatgpt.com/', timeout=60000)

        for i in range(10):
            title = await page.title()
            if 'sora' in title.lower() and 'moment' not in title.lower():
                break
            await page.wait_for_timeout(2000)

        print(f"Page: {await page.title()}")
        await page.wait_for_timeout(3000)

        result = await page.evaluate("""
            async (taskId) => {
                const sessionResp = await fetch('/api/auth/session');
                if (!sessionResp.ok) return { error: 'session failed: ' + sessionResp.status };
                const session = await sessionResp.json();
                const token = session.accessToken;
                if (!token) return { error: 'no token' };

                const endpoints = [
                    '/backend/status',
                    '/backend/nf/' + taskId,
                    '/backend/tasks/' + taskId,
                ];

                const results = {};
                for (const ep of endpoints) {
                    try {
                        const resp = await fetch(ep, {
                            headers: { 'Authorization': 'Bearer ' + token }
                        });
                        const text = await resp.text();
                        results[ep] = { status: resp.status, body: text.substring(0, 500) };
                    } catch(e) {
                        results[ep] = { error: e.message };
                    }
                }
                return results;
            }
        """, task_id)

        for ep, r in result.items():
            print(f"\n--- {ep} ---")
            if 'error' in r:
                print(f"Error: {r['error']}")
            else:
                print(f"Status: {r['status']}")
                body = r.get('body', '')
                if 'Just a moment' in body:
                    print('Cloudflare blocked')
                else:
                    print(body)

        await context.close()

if __name__ == '__main__':
    task_id = sys.argv[1] if len(sys.argv) > 1 else None
    if not task_id:
        print("Usage: python3 poll.py <task_id>")
        sys.exit(1)
    asyncio.run(poll(task_id))
