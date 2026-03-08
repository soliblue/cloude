# Cloude Cloud - Business Plan

## Vision
"Your own AI computer from your phone." A hosted environment where anyone - technical or not - gets a personal machine with Claude Code running on it, controlled entirely from the Cloude iOS app. No terminal, no SSH, no complexity.

---

## Product

### What the user gets
- A persistent Linux machine (Hetzner) that's always on
- Claude Code running on it with full shell access
- The Cloude iOS app as their interface
- Their files, projects, and data persist between sessions
- Claude remembers them, their preferences, their work
- Ability to host websites, APIs, databases, cron jobs on their machine
- Ability to build and deploy iOS/Android apps via GitHub Actions

### What the user never sees
- Linux, terminal, SSH, nginx, DNS config
- Container orchestration, server management
- Build pipelines, CI/CD complexity

---

## Business Model

### Tier 1: Machine Only (bring your own Claude sub)
| Plan | Specs | Hetzner cost | We charge | Margin |
|------|-------|-------------|-----------|--------|
| Starter | 2 vCPU, 4GB, 40GB | ~$4/mo | $10/mo | $6 |
| Pro | 4 vCPU, 8GB, 80GB | ~$6/mo | $14/mo | $8 |
| Power | 8 vCPU, 16GB, 160GB | ~$10/mo | $22/mo | $12 |
| Max | 16 vCPU, 32GB, 320GB | ~$18/mo | $40/mo | $22 |

### Tier 2: Machine + AI (everything bundled)
| Plan | Includes | Our cost | We charge | Margin |
|------|----------|----------|-----------|--------|
| Starter + Pro | CX23 + Claude Pro ($20) | ~$24/mo | $40/mo | $16 |
| Starter + Max | CX23 + Claude Max ($100) | ~$104/mo | $150/mo | $46 |
| Pro + Max | CX33 + Claude Max ($100) | ~$106/mo | $160/mo | $54 |
| Power + Max | CX43 + Claude Max ($100) | ~$110/mo | $170/mo | $60 |

### Revenue streams
- Machine hosting (primary, recurring)
- AI subscription markup (bundled tier)
- Add-ons: extra storage, custom domains, backups
- Potentially: Apple Developer account bundling ($99/yr)

---

## Infrastructure

### Per-user setup
- Hetzner cloud server (not containers - each user gets a real VM)
- Persistent storage (files survive reboots, upgrades)
- Cloude agent (Linux port of Mac agent) pre-installed
- WebSocket connection to iOS app via gateway
- Pre-installed skills on every machine

### Architecture
```
iPhone (Cloude app)
    |
    v (WebSocket)
Cloude Gateway (auth, routing)
    |
    v
Per-user Hetzner VM
    |- Cloude Agent (Linux)
    |- Claude Code (CLI)
    |- User's files & projects
    |- Hosted websites/apps (nginx)
    |- Cron jobs, databases, etc.
```

### Shared infrastructure
- Gateway server (routes WebSocket connections to correct user VM)
- GitHub Actions macOS runners (for iOS app builds, shared across all users)
- Provisioning service (Hetzner API - spin up/resize/destroy VMs)
- Billing service

### iOS builds (for users who want to build apps)
- GitHub Actions free tier: 2,000 min/mo (200 macOS min at 10x multiplier)
- Public repos: unlimited free
- ~20 iOS builds/month free per user
- User provides: Apple Developer account ($99/yr) + GitHub token
- Pre-installed skill teaches Claude how to write GitHub workflow, push, deploy to TestFlight

---

## Onboarding Flow

### Step 1: Download & Sign Up
- Free app on App Store
- Create account (email or Apple Sign In)
- Choose tier: "Machine only" or "Machine + AI"
- Choose machine size (recommend Starter for most)
- Payment (Stripe, not IAP - avoid Apple's 30% cut)

### Step 2: Machine Provisioning (automated, ~60 seconds)
- Hetzner API creates VM
- Install Claude Code, Cloude agent, pre-configured skills
- Generate auth token, store in user's Keychain
- WebSocket connection established

### Step 3: First Chat
- Guided first message: "What would you like to build?"
- Claude introduces itself, explains what it can do
- Maybe a quick demo: "Want me to create a personal website for you?"
- User sees their first project come to life in minutes

### Step 4: (If Tier 2) Claude Subscription
- Either: user logs into their Anthropic account through OAuth
- Or: we provision a subscription on their behalf (API key injected into their VM)

### Step 5: Ongoing
- User chats from phone, Claude does things on their machine
- One-tap machine upgrade when they need more power
- Scheduled tasks, automations build up over time
- Their machine becomes their digital home

---

## Pre-installed Skills (on every user machine)

### Core skills
- **deploy-website**: Build and deploy a website to the machine, set up nginx, configure domain
- **build-ios-app**: Set up Xcode project, GitHub workflow, TestFlight deployment
- **build-android-app**: Set up Flutter/React Native project, build APK
- **setup-database**: Install and configure Postgres/SQLite/Redis
- **cron-job**: Set up recurring tasks
- **backup**: Automated backups of user data

### Productivity skills
- **file-manager**: Organize, search, manage files
- **data-analysis**: Process CSVs, generate charts, analyze data
- **web-scraper**: Scrape websites, monitor prices, track changes
- **email-automation**: Send emails via SMTP (user provides credentials)

---

## Key Risks

### Anthropic competition
- Risk: Anthropic launches their own mobile app or hosted Claude Code
- Mitigation: Move fast, build user base, the opinionated UX is the moat. Cursor proved this works.

### ToS compliance
- Risk: Bulk-buying subscriptions or account sharing violates Anthropic ToS
- Mitigation: Tier 2 uses one legitimate subscription per user. Or pivot to API-based billing. Talk to Anthropic about reseller/partner program.

### Security
- Risk: Running arbitrary CLI commands on behalf of users
- Mitigation: Each user has isolated VM (not shared containers). Standard Linux security (firewalls, limited sudo). Regular updates.

### Unit economics
- Risk: Heavy users burn through API credits, eroding margins on bundled tier
- Mitigation: Smart model routing (Sonnet for simple tasks, Opus for complex). Usage caps on bundled tier. Monitor per-user costs closely.

### Apple App Store
- Risk: Apple rejects or takes 30% cut
- Mitigation: Handle payments via web/Stripe, not IAP. The app is free - payments happen outside the App Store.

---

## Go-to-Market

### Phase 1: Dogfood (week 1-2)
- Port Mac agent to Linux
- Set up own Hetzner box, run Cloude from it
- Validate the experience works end-to-end

### Phase 2: Alpha (week 3-4)
- Build provisioning flow (Hetzner API integration)
- Onboarding in the app
- 10 beta users (friends, Twitter followers)

### Phase 3: Launch
- Product Hunt launch
- Demo video: "I built an app from my phone in 2 minutes"
- TikTok/Reels content showing the workflow
- Indie hacker communities (HN, Reddit, IndieHackers)

### Phase 4: Growth
- Content marketing (screen recordings, tutorials)
- Referral program
- Pre-built templates ("launch a blog", "build a store", "track expenses")

---

## Marketing Angles

### For developers
- "Claude Code from anywhere. No Mac required."
- "Your dev environment in your pocket."

### For non-technical users
- "Your own AI computer for $10/mo."
- "Tell it what you want. It builds it."
- "Build an app from your phone."

### Viral demo ideas
- Building a website while walking the dog
- Deploying an iOS app from the toilet
- "I asked my phone to build me a business" (full walkthrough)
- Before/after: "This website was made by someone who can't code, from their phone"

---

## Open Questions

- [ ] Anthropic partner/reseller program - does it exist? Can we get volume pricing?
- [ ] Stripe vs IAP - can we avoid Apple's 30% for a free app with web billing?
- [ ] Domain management - do we offer subdomains (yourname.cloude.app) or let users bring their own?
- [ ] Collaboration - can two users share a machine? (e.g. small team)
- [ ] Free tier - offer a time-limited trial? Or a very small always-free machine?
- [ ] Geographic expansion - Hetzner has US, EU, Singapore. Start EU only?
- [ ] Legal entity - where to incorporate, terms of service, privacy policy
- [ ] GDPR compliance - user data on EU servers (Hetzner Germany is good for this)
