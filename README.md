# Encode Mail — encode.lol

A customizable webmail frontend designed to run on GitHub Pages with Supabase as the application backend and Cloudflare Email Service/Workers as the real mail transport.

## Architecture

- **GitHub Pages:** static React/Vite web app
- **Supabase:** Auth, Postgres, RLS, Storage, Edge Functions
- **Cloudflare Email Service:** inbound email routing and Worker processing
- **Outbound provider:** configured through the `send-email` Edge Function via `MAIL_API_URL` and `MAIL_API_KEY`

## Important: username-only signup

The UI asks only for username + password. Supabase Auth's password provider expects an email/phone identifier, so this project uses a private synthetic Auth identity such as `luna@accounts.encode.lol`. Users' public mailbox remains `luna@encode.lol`.

For this to work without an actual verification email, turn **Confirm email** off in Supabase Auth settings. If you leave confirmation enabled, users cannot complete signup because the synthetic Auth address is not a mailbox they can access.

## 1. Create Supabase project

Create a project, then open SQL Editor and run `supabase/schema.sql`.

In Auth settings:

- Enable Email/password provider.
- Disable email confirmation if you want signup to require no email.
- Set a suitable password minimum (the UI requires 8+ characters).

## 2. Configure local environment

Copy `.env.example` to `.env.local` and fill in:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
VITE_MAIL_DOMAIN=encode.lol
VITE_AUTH_DOMAIN=accounts.encode.lol
```

Then:

```bash
npm install
npm run dev
```

## 3. GitHub Pages

Push this folder to a GitHub repository.

In **Settings → Pages**, choose **GitHub Actions** as the source.

Add these repository Actions variables:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Do **not** put a Supabase service-role key in the frontend or GitHub Pages variables.

The included `.github/workflows/deploy.yml` builds and publishes the app on every push to `main`.

### Custom domain

In GitHub Pages, add `encode.lol` as the custom domain and follow GitHub's DNS instructions. Your DNS should point the web domain at GitHub Pages. Do not point your MX records at GitHub Pages.

## 4. Real incoming email

Configure `encode.lol` email DNS/Cloudflare Email Service so inbound mail reaches the Worker in `cloudflare/src/index.ts`.

Install Wrangler:

```bash
cd cloudflare
npm install
npx wrangler login
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx wrangler deploy
```

Update `cloudflare/wrangler.toml` with the real Supabase URL. Never commit the service-role key.

The Worker looks up the destination username in `profiles` and stores the message in `messages`.

### Note about parsing

The starter Worker stores the raw RFC822 text in `body_text`. For production, add a MIME parser (or a mail provider's parsed payload) so HTML, plain text, headers, inline images, and attachments are stored separately. The database and UI already have attachment fields.

## 5. Outbound email

Supabase Edge Functions cannot magically become an Internet SMTP server. Configure a transactional/outbound email API and set these function secrets:

```bash
supabase secrets set MAIL_DOMAIN=encode.lol
supabase secrets set MAIL_API_URL=https://YOUR_PROVIDER_ENDPOINT
supabase secrets set MAIL_API_KEY=YOUR_PROVIDER_SECRET
```

Then deploy:

```bash
supabase functions deploy send-email
```

The function sends `{from,to,subject,text}` to the provider and records the sent message in Supabase.

## 6. DNS checklist

You will need:

- `encode.lol` → GitHub Pages for the web app
- MX records for `encode.lol` → your chosen inbound email service
- SPF for outbound mail
- DKIM for outbound mail
- DMARC for `encode.lol`
- optional `accounts.encode.lol` only as an internal Auth identity namespace; it does not need to receive mail if confirmation is disabled

## Security

- The browser only receives the Supabase publishable/anon key.
- RLS restricts profiles/settings/messages/attachments to the authenticated user.
- Service-role credentials belong only in the Worker/server environment.
- Never put `SUPABASE_SERVICE_ROLE_KEY` or outbound provider secrets in `.env` files committed to GitHub.

## Current starter features

- username/password account creation without asking for an email
- `username@encode.lol` mailbox identity
- inbox, starred, sent, drafts UI, archive, spam, trash
- search
- read/unread
- star
- compose
- customizable theme, accent, density, previews, avatars, reading pane
- responsive desktop/mobile layout
- Supabase RLS schema
- attachment storage bucket/schema
- GitHub Pages Actions deployment
- Cloudflare inbound Worker starter
- Supabase outbound Edge Function starter

## Production hardening to add before opening it publicly

1. MIME parsing and attachment extraction in the inbound Worker.
2. Rate limiting and abuse controls for signup/send.
3. CAPTCHA or other anti-automation protection.
4. Recovery codes or optional recovery email because username-only accounts cannot receive password-reset mail.
5. Email reputation controls, SPF/DKIM/DMARC and bounce handling.
6. Message size limits and attachment scanning.
7. Better HTML sanitization before rendering message HTML.
