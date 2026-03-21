# Commercial Launch {cart.fill}
<!-- priority: 6 -->
<!-- tags: plans, security -->

> Full public launch checklist: rebranding, landing page, Stripe payments, App Store submission, and multi-tenant infrastructure.

Full public launch: rebranding, landing page, payments, App Store.

## Rebranding
- [ ] Pick a new name (discuss with Soli)
- [ ] New app icon + brand identity
- [ ] Update bundle IDs, project references, repo name
- [ ] New domain name

## Landing Page
- [ ] Design and build (likely on the new domain)
- [ ] Hero section: what it is, demo video/GIF
- [ ] Feature breakdown (agentic control, file browser, git, live activities, scheduled tasks, multi-env, etc.)
- [ ] Hosted environment pitch: "Your own cloud dev machine, controlled from your phone"
- [ ] Pricing section
- [ ] Download / App Store link

## Payments & Hosting
- [ ] Stripe integration for hosted environment subscriptions
- [ ] Pricing model (monthly, tiers?)
- [ ] VM provisioning flow: user signs up, gets a machine, agent auto-installed
- [ ] User dashboard: manage environment, billing, usage
- [ ] Auto-suspend idle VMs to save cost

## App Store
- [ ] App Store screenshots + preview video
- [ ] App Store description + keywords
- [ ] Privacy policy + terms of service
- [ ] Submit for review
- [ ] Handle review feedback (permissions, in-app purchase rules)

## Infrastructure
- [ ] Multi-tenant VM orchestration (Hetzner API? Fly.io? Railway?)
- [ ] Onboarding automation: provision VM, install agent, generate token
- [ ] Monitoring + alerting per user environment
- [ ] Backup / snapshot strategy

## Legal
- [ ] Terms of service
- [ ] Privacy policy
- [ ] Check Claude/Anthropic usage terms for reselling hosted access
