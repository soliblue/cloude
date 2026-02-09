import asyncio, json, sys, os
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'browser-data')
OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'image_flow_capture.json')

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

async def capture():
    captured = []

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

        async def on_request(request):
            url = request.url
            if '/backend/' not in url and '/api/' not in url:
                return
            entry = {
                'type': 'request',
                'method': request.method,
                'url': url,
                'headers': dict(request.headers),
            }
            post = request.post_data
            if post:
                try:
                    entry['body'] = json.loads(post)
                except:
                    entry['body_raw'] = post[:5000]
                    entry['body_length'] = len(post)
                    if 'multipart' in request.headers.get('content-type', ''):
                        entry['content_type'] = request.headers['content-type']
            captured.append(entry)
            method_label = f"{request.method} {url.split('?')[0].split('sora.chatgpt.com')[-1]}"
            print(f"  -> {method_label}")
            if 'body' in entry:
                print(f"     BODY: {json.dumps(entry['body'])[:200]}")
            if 'body_raw' in entry:
                print(f"     RAW BODY: {entry['body_length']} bytes, type: {entry.get('content_type', '?')}")

        async def on_response(response):
            url = response.url
            if '/backend/' not in url:
                return
            entry = {
                'type': 'response',
                'status': response.status,
                'url': url,
            }
            try:
                body = await response.json()
                entry['body'] = body
                print(f"  <- {response.status} {url.split('?')[0].split('sora.chatgpt.com')[-1]}")
                preview = json.dumps(body)[:200]
                print(f"     BODY: {preview}")
            except:
                entry['body_text'] = (await response.text())[:2000]
            captured.append(entry)

        page.on('request', on_request)
        page.on('response', on_response)

        print("Opening sora.chatgpt.com...")
        await page.goto('https://sora.chatgpt.com/', timeout=60000)

        print(f"\n{'='*60}")
        print("Browser is open. Do the following:")
        print("  1. Click the image/reference button in Sora")
        print("  2. Attach an image")
        print("  3. Type a prompt and hit generate")
        print("  4. Wait for it to start processing")
        print(f"  5. Type 'done' here and press Enter")
        print(f"{'='*60}")
        print(f"\nCapturing all /backend/ and /api/ requests...\n")

        while True:
            line = await asyncio.get_event_loop().run_in_executor(None, sys.stdin.readline)
            if line.strip().lower() == 'done':
                break

        with open(OUTPUT_FILE, 'w') as f:
            json.dump(captured, f, indent=2, default=str)

        print(f"\nCaptured {len(captured)} requests/responses")
        print(f"Saved to: {OUTPUT_FILE}")

        await context.close()

if __name__ == '__main__':
    asyncio.run(capture())
