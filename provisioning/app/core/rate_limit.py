import threading
import time
from collections import defaultdict, deque
from collections.abc import Callable

from fastapi import HTTPException, Request, status


Bucket = tuple[str, str]
attempts: dict[Bucket, deque[float]] = defaultdict(deque)
lock = threading.Lock()


def limit(name: str, max_attempts: int, window_seconds: int) -> Callable[[Request], None]:
    def dependency(request: Request):
        now = time.time()
        with lock:
            bucket = attempts[(name, client_ip(request))]
            while bucket and bucket[0] <= now - window_seconds:
                bucket.popleft()
            if len(bucket) >= max_attempts:
                raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="rate limit exceeded")
            bucket.append(now)

    return dependency


def client_ip(request: Request) -> str:
    connecting_ip = request.headers.get("cf-connecting-ip")
    if connecting_ip:
        return connecting_ip.strip()
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",", 1)[0].strip()
    if request.client:
        return request.client.host
    return "unknown"
