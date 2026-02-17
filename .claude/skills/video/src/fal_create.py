import argparse, json, os, sys, time
import fal_client

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_DIR = os.path.join(SKILL_DIR, 'data', 'raw')
BUDGET_FILE = os.path.expanduser('~/.config/fal/budget.json')

MODELS = {
    'wan-t2v': {
        'endpoint': 'fal-ai/wan/v2.2-a14b/text-to-video',
        'type': 'text-to-video',
        'cost_480p': 0.04,
        'cost_720p': 0.08,
        'default_resolution': '480p',
    },
    'wan-i2v': {
        'endpoint': 'fal-ai/wan-i2v',
        'type': 'image-to-video',
        'cost_480p': 0.20,
        'cost_720p': 0.40,
        'default_resolution': '480p',
    },
    'kling-std': {
        'endpoint': 'fal-ai/kling-video/v2.1/standard/text-to-video',
        'type': 'text-to-video',
        'cost_5s': 0.28,
        'cost_10s': 0.56,
        'default_duration': '5',
    },
    'kling-pro': {
        'endpoint': 'fal-ai/kling-video/v2.1/pro/text-to-video',
        'type': 'text-to-video',
        'cost_5s': 0.49,
        'cost_10s': 0.98,
        'default_duration': '5',
    },
    'kling-std-i2v': {
        'endpoint': 'fal-ai/kling-video/v2.1/standard/image-to-video',
        'type': 'image-to-video',
        'cost_5s': 0.28,
        'cost_10s': 0.56,
        'default_duration': '5',
    },
}

DAILY_BUDGET = 5.00

def load_fal_key():
    for path in [
        os.path.join(SKILL_DIR, '..', '..', '.env'),
        os.path.expanduser('~/Desktop/CODING/ai-videos/.env'),
        os.path.expanduser('~/Desktop/CODING/cloude/.env'),
    ]:
        resolved = os.path.abspath(path)
        if os.path.exists(resolved):
            with open(resolved) as f:
                for line in f:
                    if line.startswith('FAL_KEY='):
                        return line.strip().split('=', 1)[1]
    print("ERROR: FAL_KEY not found in any .env file")
    sys.exit(1)

def load_budget():
    os.makedirs(os.path.dirname(BUDGET_FILE), exist_ok=True)
    if os.path.exists(BUDGET_FILE):
        with open(BUDGET_FILE) as f:
            data = json.load(f)
        today = time.strftime('%Y-%m-%d')
        if data.get('date') == today:
            return data
    return {'date': time.strftime('%Y-%m-%d'), 'spent': 0.0, 'videos': 0, 'log': []}

def save_budget(budget):
    os.makedirs(os.path.dirname(BUDGET_FILE), exist_ok=True)
    with open(BUDGET_FILE, 'w') as f:
        json.dump(budget, f, indent=2)

def estimate_cost(model_key, resolution='480p', duration='5'):
    model = MODELS[model_key]
    if 'kling' in model_key:
        return model[f'cost_{duration}s']
    return model.get(f'cost_{resolution}', model.get('cost_480p', 0.20))

def check_budget(cost):
    budget = load_budget()
    remaining = DAILY_BUDGET - budget['spent']
    if cost > remaining:
        print(f"BUDGET EXCEEDED: need ${cost:.2f} but only ${remaining:.2f} left today (${budget['spent']:.2f}/{DAILY_BUDGET:.2f} spent)")
        print(f"Videos generated today: {budget['videos']}")
        return False
    return True

def record_spend(cost, model_key, prompt):
    budget = load_budget()
    budget['spent'] = round(budget['spent'] + cost, 4)
    budget['videos'] += 1
    budget['log'].append({
        'time': time.strftime('%H:%M:%S'),
        'model': model_key,
        'cost': cost,
        'prompt': prompt[:80],
    })
    save_budget(budget)
    remaining = DAILY_BUDGET - budget['spent']
    print(f"  Cost: ${cost:.2f} | Today: ${budget['spent']:.2f}/{DAILY_BUDGET:.2f} | Remaining: ${remaining:.2f}")

def build_wan_params(prompt, resolution, aspect_ratio, num_frames, image_url=None):
    params = {
        'prompt': prompt,
        'resolution': resolution,
        'aspect_ratio': aspect_ratio,
        'num_frames': num_frames,
        'frames_per_second': 16,
    }
    if image_url:
        params['image_url'] = image_url
    return params

def build_kling_params(prompt, duration, aspect_ratio, image_url=None):
    params = {
        'prompt': prompt,
        'duration': duration,
        'aspect_ratio': aspect_ratio,
    }
    if image_url:
        params['image_url'] = image_url
    return params

def upload_image_to_fal(image_path):
    print(f"  Uploading image: {image_path}")
    url = fal_client.upload_file(image_path)
    print(f"  Uploaded: {url}")
    return url

def generate(model_key, prompt, resolution='480p', aspect_ratio='16:9', duration='5', num_frames=81, image_path=None):
    model = MODELS[model_key]
    cost = estimate_cost(model_key, resolution, duration)

    if not check_budget(cost):
        return None

    print(f"\nGenerating with {model_key} ({model['endpoint']})")
    print(f"  Prompt: {prompt[:100]}")
    print(f"  Est. cost: ${cost:.2f}")

    image_url = None
    if image_path:
        image_url = upload_image_to_fal(image_path)

    if 'kling' in model_key:
        params = build_kling_params(prompt, duration, aspect_ratio, image_url)
    else:
        params = build_wan_params(prompt, resolution, aspect_ratio, num_frames, image_url)

    def on_queue_update(update):
        if isinstance(update, fal_client.InProgress):
            for log in (update.logs or []):
                print(f"  {log.get('message', log)}")

    result = fal_client.subscribe(model['endpoint'], arguments=params, with_logs=True, on_queue_update=on_queue_update)

    video_url = result.get('video', {}).get('url')
    if not video_url:
        print(f"  ERROR: No video URL in response: {json.dumps(result, indent=2)[:500]}")
        return None

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    timestamp = int(time.time() * 1000) % 10000000000
    prefix = 'kling' if 'kling' in model_key else 'wan'
    filename = f"{prefix}_{timestamp}.mp4"
    filepath = os.path.join(OUTPUT_DIR, filename)

    import urllib.request
    print(f"  Downloading video...")
    urllib.request.urlretrieve(video_url, filepath)
    size_mb = os.path.getsize(filepath) / 1024 / 1024
    print(f"  Saved: {filepath} ({size_mb:.1f} MB)")

    record_spend(cost, model_key, prompt)
    return filepath

def generate_batch(jobs, model_key):
    results = []
    for i, job in enumerate(jobs):
        print(f"\n{'='*50}")
        print(f"Job {i+1}/{len(jobs)}")

        prompt = job['prompt']
        resolution = job.get('resolution', '480p')
        aspect_ratio = job.get('aspect_ratio', '16:9')
        duration = job.get('duration', '5')
        num_frames = job.get('num_frames', 81)
        image_path = job.get('image')
        job_model = job.get('model', model_key)

        path = generate(job_model, prompt, resolution, aspect_ratio, duration, num_frames, image_path)
        if path:
            results.append(path)
        else:
            print(f"  SKIPPED (budget or error)")
            break

    print(f"\n{'='*50}")
    print(f"Done! {len(results)}/{len(jobs)} videos generated:")
    for p in results:
        print(f"  {p}")
    return results

def show_budget():
    budget = load_budget()
    remaining = DAILY_BUDGET - budget['spent']
    print(f"Date: {budget['date']}")
    print(f"Spent: ${budget['spent']:.2f} / ${DAILY_BUDGET:.2f}")
    print(f"Remaining: ${remaining:.2f}")
    print(f"Videos: {budget['videos']}")
    if budget.get('log'):
        print(f"\nLog:")
        for entry in budget['log']:
            print(f"  {entry['time']} | {entry['model']} | ${entry['cost']:.2f} | {entry['prompt']}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate videos via fal.ai (Wan / Kling)')
    parser.add_argument('prompt', nargs='?')
    parser.add_argument('-m', '--model', default='wan-t2v', choices=list(MODELS.keys()))
    parser.add_argument('-r', '--resolution', default='480p', choices=['480p', '580p', '720p'])
    parser.add_argument('-a', '--aspect-ratio', default='16:9', choices=['16:9', '9:16', '1:1'])
    parser.add_argument('-d', '--duration', default='5', choices=['5', '10'])
    parser.add_argument('-f', '--frames', type=int, default=81)
    parser.add_argument('-i', '--image', help='Reference image for image-to-video')
    parser.add_argument('-b', '--batch', help='JSON file with array of jobs')
    parser.add_argument('--budget', action='store_true', help='Show budget status')
    parser.add_argument('--daily-limit', type=float, help='Override daily budget limit')
    args = parser.parse_args()

    if args.daily_limit:
        DAILY_BUDGET = args.daily_limit

    os.environ['FAL_KEY'] = load_fal_key()

    if args.budget:
        show_budget()
    elif args.batch:
        with open(args.batch) as f:
            jobs = json.load(f)
        generate_batch(jobs, args.model)
    elif args.prompt:
        if args.image and 'i2v' not in args.model:
            if 'kling' in args.model:
                args.model = 'kling-std-i2v'
            else:
                args.model = 'wan-i2v'
        generate(args.model, args.prompt, args.resolution, args.aspect_ratio, args.duration, args.frames, args.image)
    else:
        print("Provide a prompt, --batch file, or --budget")
        sys.exit(1)
