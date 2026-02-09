import asyncio, json, sys, os, time, requests
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'browser-data')
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output')
PROXY_API_URL = 'https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&country_code__in=US&page_size=1'

async def get_proxy():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '.env')
    api_key = None
    with open(env_path) as f:
        for line in f:
            if line.startswith('WEBSHARE_API_KEY='):
                api_key = line.strip().split('=', 1)[1]
    r = requests.get(PROXY_API_URL, headers={'Authorization': f'Token {api_key}'})
    p = r.json()['results'][0]
    return {
        'server': f"http://{p['proxy_address']}:{p['port']}",
        'username': p['username'],
        'password': p['password'],
    }

async def create_video(prompt, orientation='landscape', size='small', n_frames=150, image_path=None):
    os.makedirs(OUTPUT_DIR, exist_ok=True)

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

        print("Loading sora.chatgpt.com...")
        await page.goto('https://sora.chatgpt.com/', timeout=60000)
        await page.wait_for_timeout(5000)

        title = await page.title()
        if 'moment' in title.lower():
            print("ERROR: Cloudflare challenge. Re-run session.py login")
            await context.close()
            sys.exit(1)

        print(f"Page loaded: {title}")

        file_id = None
        if image_path:
            print(f"\nUploading reference image: {image_path}")
            import base64, mimetypes
            mime = mimetypes.guess_type(image_path)[0] or 'image/png'
            filename = os.path.basename(image_path)
            with open(image_path, 'rb') as img:
                img_b64 = base64.b64encode(img.read()).decode()

            upload_result = await page.evaluate("""
                async ({img_b64, mime, filename}) => {
                    const session = await (await fetch('/api/auth/session')).json();
                    const token = session.accessToken;
                    if (!token) return { error: 'No access token' };

                    const bytes = Uint8Array.from(atob(img_b64), c => c.charCodeAt(0));
                    const file = new File([bytes], filename, { type: mime });
                    const form = new FormData();
                    form.append('file', file);
                    form.append('use_case', 'inpaint_safe');

                    const resp = await fetch('/backend/project_y/file/upload', {
                        method: 'POST',
                        headers: { 'Authorization': 'Bearer ' + token },
                        body: form,
                    });
                    return { status: resp.status, body: await resp.text() };
                }
            """, {"img_b64": img_b64, "mime": mime, "filename": filename})

            if upload_result.get('error') or upload_result.get('status') != 200:
                print(f"ERROR uploading image: {upload_result}")
                await context.close()
                sys.exit(1)

            upload_data = json.loads(upload_result['body'])
            file_id = upload_data['file_id']
            print(f"Uploaded: {file_id}")

        inpaint_items = [{"kind": "file", "file_id": file_id}] if file_id else []

        print(f"\nCreating video: {prompt[:80]}...")
        create_result = await page.evaluate("""
            async ({prompt, orientation, size, n_frames, inpaint_items}) => {
                const session = await (await fetch('/api/auth/session')).json();
                const token = session.accessToken;
                if (!token) return { error: 'No access token' };

                const resp = await fetch('/backend/nf/create', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + token,
                    },
                    body: JSON.stringify({
                        kind: "video", prompt, title: null, orientation, size, n_frames,
                        inpaint_items, remix_target_id: null, project_id: null,
                        metadata: null, cameo_ids: null, cameo_replacements: null,
                        model: "sy_8", style_id: null, audio_caption: null,
                        audio_transcript: null, video_caption: null, storyboard_id: null,
                    })
                });
                return { status: resp.status, body: await resp.text() };
            }
        """, {"prompt": prompt, "orientation": orientation, "size": size, "n_frames": n_frames, "inpaint_items": inpaint_items})

        if create_result.get('error') or create_result.get('status') != 200:
            print(f"ERROR: {create_result}")
            await context.close()
            sys.exit(1)

        task_data = json.loads(create_result['body'])
        task_id = task_data['id']
        print(f"Task created: {task_id}")
        print(f"Videos remaining: {task_data.get('rate_limit_and_credit_balance', {}).get('estimated_num_videos_remaining', '?')}")

        # Step 2: Poll until done
        print("\nWaiting for video to generate...")
        for i in range(120):
            pending = await page.evaluate("""
                async () => {
                    const session = await (await fetch('/api/auth/session')).json();
                    const resp = await fetch('/backend/nf/pending/v2', {
                        headers: { 'Authorization': 'Bearer ' + session.accessToken }
                    });
                    return await resp.json();
                }
            """)

            if not pending or len(pending) == 0:
                print("Video ready!")
                break

            task_status = None
            for t in pending:
                if t.get('id') == task_id or t.get('task_id') == task_id:
                    task_status = t
                    break

            if task_status:
                pct = task_status.get('progress', task_status.get('percentage', '?'))
                print(f"  [{i*5}s] Progress: {pct}")
            else:
                if i > 2:
                    print("Video ready! (task no longer in pending)")
                    break
                print(f"  [{i*5}s] Waiting...")

            await page.wait_for_timeout(5000)

        # Step 3: Get download URL from drafts (retry to wait for our video)
        print("\nFetching download URL...")
        download_url = None
        gen_id = None
        for attempt in range(6):
            drafts = await page.evaluate("""
                async () => {
                    const session = await (await fetch('/api/auth/session')).json();
                    const resp = await fetch('/backend/project_y/profile/drafts?limit=10', {
                        headers: { 'Authorization': 'Bearer ' + session.accessToken }
                    });
                    return await resp.json();
                }
            """)

            if drafts.get('items'):
                for draft in drafts['items']:
                    if draft.get('task_id') == task_id or draft.get('prompt', '').strip() == prompt.strip():
                        gen_id = draft.get('id')
                        download_url = draft.get('download_urls', {}).get('no_watermark') or draft.get('downloadable_url')
                        print(f"Found: {gen_id}")
                        print(f"Prompt: {draft.get('prompt', '?')[:80]}")
                        print(f"Size: {draft.get('width')}x{draft.get('height')}, {draft.get('duration_s')}s")
                        break

            if download_url:
                break
            print(f"  Draft not ready yet, retrying ({attempt + 1}/6)...")
            await page.wait_for_timeout(5000)

        if not download_url:
            print("ERROR: Could not find download URL for our task")
            await context.close()
            sys.exit(1)

        # Step 4: Download the MP4
        timestamp = int(time.time())
        filename = f"sora_{timestamp}.mp4"
        filepath = os.path.join(OUTPUT_DIR, filename)

        print(f"\nDownloading to {filepath}...")
        proxy_url = f"http://{proxy['username']}:{proxy['password']}@{proxy['server'].replace('http://', '')}"
        r = requests.get(download_url, proxies={'https': proxy_url, 'http': proxy_url}, timeout=120)

        with open(filepath, 'wb') as f:
            f.write(r.content)

        size_mb = len(r.content) / 1024 / 1024
        print(f"Downloaded: {filepath} ({size_mb:.1f} MB)")

        await context.close()
        return filepath

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('prompt')
    parser.add_argument('--orientation', '-o', default='landscape', choices=['landscape', 'portrait', 'square'])
    parser.add_argument('--size', '-s', default='small', choices=['small', 'large'])
    parser.add_argument('--frames', '-f', type=int, default=150, choices=[150, 300, 450, 600])
    parser.add_argument('--image', '-i', help='Reference image path to guide generation')
    args = parser.parse_args()

    asyncio.run(create_video(args.prompt, args.orientation, args.size, args.frames, args.image))
