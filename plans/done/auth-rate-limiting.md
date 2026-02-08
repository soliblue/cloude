# Auth Rate Limiting
<!-- priority: 10 -->
<!-- build: 56 -->

Rate limiting for auth attempts in `AuthManager.swift`. 3 max attempts with 5-minute lockout window. `isRateLimited()` and `recordFailedAttempt()` methods.
