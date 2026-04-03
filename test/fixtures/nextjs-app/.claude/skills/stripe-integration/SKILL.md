---
name: stripe-integration
description: "Create Stripe payment integrations with proper security patterns. Use when adding payments, checkout, webhooks, or subscriptions."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Stripe Integration

## Steps

1. Verify Stripe SDK is installed: check `stripe` in package.json dependencies.
2. Generate integration code following Stripe best practices:
   - Webhook signature verification with `stripe.webhooks.constructEvent()`
   - Idempotency keys for all mutating operations
   - Proper error handling for `StripeError` types
3. Create API routes for Stripe endpoints in `src/app/api/`:
   - `src/app/api/checkout/route.ts` -- create checkout sessions
   - `src/app/api/webhooks/stripe/route.ts` -- handle Stripe webhooks
4. Add TypeScript types for Stripe events.
5. Validate environment variables: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PUBLISHABLE_KEY`.

## Rules

- **Never** hardcode any Stripe keys -- always use `process.env`.
- Always verify webhook signatures before processing events.
- Use Stripe's official TypeScript types.
- Handle payment failures gracefully with user-facing error messages.
- Log Stripe errors for debugging but never expose internal details to users.
