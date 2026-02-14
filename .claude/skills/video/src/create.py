import asyncio, json, sys, os, time, requests
from playwright.async_api import async_playwright

BROWSER_DATA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'browser')
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data', 'raw')
PROXY_API_URL = 'https://proxy.webshare.io/api/v2/proxy/list/?mode=direct&country_code__in=US&page_size=1'

async def get_proxy():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '.env')
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

async def launch_browser(proxy):
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
        sys.exit(1)

    print(f"Page loaded: {title}")
    return p_instance, context, page

async def upload_image(page, image_path):
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
        print(f"  ERROR uploading image: {upload_result}")
        return None

    return json.loads(upload_result['body'])['file_id']

async def submit_job(page, prompt, orientation, size, n_frames, inpaint_items, audio_caption=None, audio_transcript=None):
    transcript_obj = {"text": audio_transcript} if audio_transcript else None
    create_result = await page.evaluate("""
        async ({prompt, orientation, size, n_frames, inpaint_items, audio_caption, audio_transcript}) => {
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
                    model: "sy_8", style_id: null, audio_caption: audio_caption,
                    audio_transcript: audio_transcript, video_caption: null, storyboard_id: null,
                })
            });
            return { status: resp.status, body: await resp.text() };
        }
    """, {"prompt": prompt, "orientation": orientation, "size": size, "n_frames": n_frames, "inpaint_items": inpaint_items, "audio_caption": audio_caption, "audio_transcript": transcript_obj})

    if create_result.get('error') or create_result.get('status') != 200:
        return None, create_result

    task_data = json.loads(create_result['body'])
    remaining = task_data.get('rate_limit_and_credit_balance', {}).get('estimated_num_videos_remaining', '?')
    return task_data['id'], remaining

async def poll_until_done(page, task_ids):
    print(f"\nWaiting for {len(task_ids)} video(s) to generate...")
    for i in range(240):
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
            print("All videos ready!")
            return

        pending_ids = {t.get('id') or t.get('task_id') for t in pending}
        still_pending = [tid for tid in task_ids if tid in pending_ids]

        if not still_pending:
            print("All videos ready!")
            return

        statuses = []
        for t in pending:
            tid = t.get('id') or t.get('task_id')
            if tid in task_ids:
                pct = t.get('progress', t.get('percentage', '?'))
                statuses.append(f"{pct}")
        print(f"  [{i*5}s] {len(still_pending)} pending: [{', '.join(statuses)}]")

        await page.wait_for_timeout(5000)

async def snapshot_draft_ids(page):
    drafts = await page.evaluate("""
        async () => {
            const session = await (await fetch('/api/auth/session')).json();
            const resp = await fetch('/backend/project_y/profile/drafts?limit=100', {
                headers: { 'Authorization': 'Bearer ' + session.accessToken }
            });
            return await resp.json();
        }
    """)
    return {d.get('id') for d in (drafts.get('items') or [])}

async def download_videos(page, proxy, task_ids, prompts, pre_draft_ids=None):
    print("\nFetching download URLs...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    proxy_url = f"http://{proxy['username']}:{proxy['password']}@{proxy['server'].replace('http://', '')}"
    downloaded = []
    target_count = len(task_ids)
    remaining_task_ids = set(task_ids)

    for attempt in range(18):
        if len(downloaded) >= target_count:
            break

        drafts = await page.evaluate("""
            async () => {
                const session = await (await fetch('/api/auth/session')).json();
                const resp = await fetch('/backend/project_y/profile/drafts?limit=100', {
                    headers: { 'Authorization': 'Bearer ' + session.accessToken }
                });
                return await resp.json();
            }
        """)

        if drafts.get('items'):
            for draft in drafts['items']:
                draft_id = draft.get('id')
                draft_task = draft.get('task_id')

                matched = False
                if draft_task in remaining_task_ids:
                    matched = True
                    remaining_task_ids.discard(draft_task)
                elif pre_draft_ids is not None and draft_id not in pre_draft_ids and draft_id not in {d for d in downloaded}:
                    matched = True

                if matched and len(downloaded) < target_count:
                    url = draft.get('download_urls', {}).get('no_watermark') or draft.get('downloadable_url')
                    if url:
                        timestamp = int(time.time() * 1000) % 10000000000
                        filename = f"sora_{timestamp}.mp4"
                        filepath = os.path.join(OUTPUT_DIR, filename)

                        print(f"\n  Downloading: {draft.get('prompt', '?')[:60]}...")
                        print(f"  Size: {draft.get('width')}x{draft.get('height')}, {draft.get('duration_s')}s")
                        r = requests.get(url, proxies={'https': proxy_url, 'http': proxy_url}, timeout=120)
                        with open(filepath, 'wb') as f:
                            f.write(r.content)
                        size_mb = len(r.content) / 1024 / 1024
                        print(f"  Saved: {filepath} ({size_mb:.1f} MB)")
                        downloaded.append(filepath)
                        if pre_draft_ids is not None:
                            pre_draft_ids.add(draft_id)

        remaining = target_count - len(downloaded)
        if remaining > 0:
            print(f"  {remaining} still waiting for download URLs... ({attempt + 1}/18)")
            await page.wait_for_timeout(5000)

    remaining = target_count - len(downloaded)
    if remaining > 0:
        print(f"\nWARNING: {remaining} video(s) could not be downloaded")

    return downloaded

async def create_video(prompt, orientation='landscape', size='small', n_frames=150, image_path=None, audio_caption=None, audio_transcript=None):
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("Fetching US proxy...")
    proxy = await get_proxy()

    p_instance, context, page = await launch_browser(proxy)

    file_id = None
    if image_path:
        print(f"\nUploading reference image: {image_path}")
        file_id = await upload_image(page, image_path)
        if not file_id:
            await context.close()
            sys.exit(1)
        print(f"Uploaded: {file_id}")

    inpaint_items = [{"kind": "file", "file_id": file_id}] if file_id else []

    pre_draft_ids = await snapshot_draft_ids(page)

    print(f"\nCreating video: {prompt[:80]}...")
    task_id, remaining = await submit_job(page, prompt, orientation, size, n_frames, inpaint_items, audio_caption, audio_transcript)
    if not task_id:
        print(f"ERROR: {remaining}")
        await context.close()
        sys.exit(1)

    print(f"Task created: {task_id}")
    print(f"Videos remaining: {remaining}")

    await poll_until_done(page, [task_id])
    downloaded = await download_videos(page, proxy, [task_id], [prompt], pre_draft_ids)

    await context.close()
    await p_instance.stop()
    return downloaded[0] if downloaded else None

async def create_batch(jobs):
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("Fetching US proxy...")
    proxy = await get_proxy()

    p_instance, context, page = await launch_browser(proxy)

    pre_draft_ids = await snapshot_draft_ids(page)
    print(f"Snapshot: {len(pre_draft_ids)} existing drafts")

    task_ids = []
    prompts = []
    for i, job in enumerate(jobs):
        prompt = job['prompt']
        orientation = job.get('orientation', 'landscape')
        size = job.get('size', 'small')
        n_frames = job.get('frames', 150)
        image_path = job.get('image')

        print(f"\n--- Job {i+1}/{len(jobs)} ---")

        file_id = None
        if image_path:
            print(f"Uploading: {image_path}")
            file_id = await upload_image(page, image_path)
            if file_id:
                print(f"Uploaded: {file_id}")
            else:
                print("SKIP: image upload failed")
                continue

        inpaint_items = [{"kind": "file", "file_id": file_id}] if file_id else []

        audio_caption = job.get('audio_caption')
        audio_transcript = job.get('audio_transcript')

        print(f"Creating: {prompt[:70]}...")
        if audio_transcript:
            print(f"  Narration: {audio_transcript[:60]}...")
        task_id, remaining = await submit_job(page, prompt, orientation, size, n_frames, inpaint_items, audio_caption, audio_transcript)
        if task_id:
            task_ids.append(task_id)
            prompts.append(prompt)
            print(f"Queued: {task_id} (remaining: {remaining})")
        else:
            print(f"SKIP: {remaining}")

        await page.wait_for_timeout(1000)

    if not task_ids:
        print("\nNo jobs submitted successfully")
        await context.close()
        await p_instance.stop()
        sys.exit(1)

    print(f"\n{'='*50}")
    print(f"Submitted {len(task_ids)} jobs, waiting for all to complete...")

    await poll_until_done(page, task_ids)
    downloaded = await download_videos(page, proxy, task_ids, prompts, pre_draft_ids)

    await context.close()
    await p_instance.stop()

    print(f"\n{'='*50}")
    print(f"Done! {len(downloaded)}/{len(task_ids)} videos downloaded:")
    for path in downloaded:
        print(f"  {path}")
    return downloaded

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('prompt', nargs='?')
    parser.add_argument('--orientation', '-o', default='landscape', choices=['landscape', 'portrait', 'square'])
    parser.add_argument('--size', '-s', default='small', choices=['small', 'large'])
    parser.add_argument('--frames', '-f', type=int, default=150, choices=[150, 300, 450, 600])
    parser.add_argument('--image', '-i', help='Reference image path for image-to-video')
    parser.add_argument('--batch', '-b', help='JSON file with array of jobs [{prompt, orientation, size, frames, image}]')
    parser.add_argument('--audio-caption', help='Sound effects / ambient audio description')
    parser.add_argument('--audio-transcript', help='Spoken narration text')
    args = parser.parse_args()

    if args.batch:
        with open(args.batch) as f:
            jobs = json.load(f)
        asyncio.run(create_batch(jobs))
    elif args.prompt:
        asyncio.run(create_video(args.prompt, args.orientation, args.size, args.frames, args.image, args.audio_caption, args.audio_transcript))
    else:
        print("ERROR: provide a prompt or --batch file")
        sys.exit(1)
