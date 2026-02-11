import asyncio, json, sys, os
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'browser-data')
PROXY_API_URL = 'https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&country_code__in=US&page_size=1'

async def get_proxy():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '.env')
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

async def run():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'login'

    print("Fetching US proxy...")
    proxy = await get_proxy()
    print(f"Proxy: {proxy['server']}")

    async with async_playwright() as p:
        context = await p.chromium.launch_persistent_context(
            user_data_dir=BROWSER_DATA,
            headless=False,
            channel='chrome',
            proxy=proxy,
            args=['--disable-blink-features=AutomationControlled'],
        )

        page = context.pages[0] if context.pages else await context.new_page()

        if mode == 'login':
            await page.goto('https://sora.chatgpt.com/', timeout=60000)
            print("Sign in to Sora. Type 'done' when ready.")
            while True:
                line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
                if line.strip().lower() == 'done':
                    break
            print("Session saved. Testing...")

        elif mode == 'create':
            prompt = sys.argv[2] if len(sys.argv) > 2 else 'A goldfish swimming in clear water'
            await page.goto('https://sora.chatgpt.com/', timeout=60000)
            print("Waiting for page...")
            await page.wait_for_timeout(5000)
            title = await page.title()
            print(f"Title: {title}")

            print("Getting access token...")
            token_result = await page.evaluate("""
                async () => {
                    try {
                        const resp = await fetch('/api/auth/session');
                        const data = await resp.json();
                        return { ok: true, token: data.accessToken, email: data.user?.email };
                    } catch(e) {
                        return { ok: false, error: e.message };
                    }
                }
            """)
            print(f"Token result: ok={token_result.get('ok')}, email={token_result.get('email')}")

            if not token_result.get('token'):
                print("No token — not logged in. Run 'python3 session.py login' first.")
                await context.close()
                return

            print(f"Creating video: {prompt[:60]}...")
            result = await page.evaluate("""
                async ({prompt, token}) => {
                    const resp = await fetch('/backend/nf/create', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer ' + token,
                        },
                        body: JSON.stringify({
                            kind: "video",
                            prompt,
                            title: null,
                            orientation: "landscape",
                            size: "small",
                            n_frames: 150,
                            inpaint_items: [],
                            remix_target_id: null,
                            project_id: null,
                            metadata: null,
                            cameo_ids: null,
                            cameo_replacements: null,
                            model: "sy_8",
                            style_id: null,
                            audio_caption: null,
                            audio_transcript: null,
                            video_caption: null,
                            storyboard_id: null,
                        })
                    });
                    return { status: resp.status, body: await resp.text() };
                }
            """, {"prompt": prompt, "token": token_result['token']})

            print(f"Status: {result['status']}")
            print(f"Response: {result['body'][:1000]}")

        await context.close()

if __name__ == '__main__':
    asyncio.run(run())
