# KJ Silva’s Nikah RSVP

A separate mobile-friendly RSVP for KJ’s Nikah on **Thursday, October 29, 2026 at 4:00 p.m. at Petra Jama Masjid**. Guests choose one of three replies, enter a required name, and may add an optional phone number. The public page shows aggregate counts only; names, phone numbers, and individual replies are restricted to authorized organizers.

## Separation and hosting

- The site is published from its own public GitHub repository, `MexcanShyGuy/kj-nikah-rsvp-poll`, using free GitHub Pages.
- Its data uses Nikah-specific tables and RPC functions inside the existing free **KJ Dinner Poll** Supabase project. This keeps the poll separate at the table/function level without creating a third free-tier project or changing any existing dinner-poll table or response.
- The only browser-side key is the Supabase publishable key. Never put a Supabase secret/service-role key, database password, or organizer list in the website repository.

## Privacy model

- Row-level security is enabled and direct privileges on the response and organizer tables are revoked from public, anonymous, and authenticated clients.
- Anonymous visitors can call only bounded submit/update and aggregate-count functions. The public totals function never returns names, phone numbers, or individual answers.
- The private organizer function requires a signed-in session and checks the email against `kj_nikah_rsvp_organizers` before returning individual responses.
- A casual RSVP can be revised in the same browser; browser identity is not verified and this is not tamper-proof voting.
- No invitations or sign-in emails are sent automatically. A visitor requests a one-time link only by submitting the organizer sign-in form.

## Initial setup

The poll was connected to the existing KJ Dinner Poll Supabase project using the standalone schema in [`supabase-setup.sql`](./supabase-setup.sql). It creates only `kj_nikah_rsvp_*` objects and does not update the dinner poll.

To authorize an organizer, add that person’s exact, confirmed sign-in email privately to `kj_nikah_rsvp_organizers` in Supabase SQL Editor. Do not commit organizer addresses or the private allowlist to the public repository. The site owner’s personal email is the initial organizer; KJ’s address should be added only after he confirms which address he will use.

In Supabase Authentication → URL Configuration, add the deployed `/organizer.html` address to **Redirect URLs**. Do not change the project Site URL, which may be used by the existing dinner poll. Keep email OTP enabled.

## Review checks

- Confirm the public page displays the exact question, event date/location, and three choices.
- Confirm the total counters show aggregate counts only.
- Confirm the database returns an authorization error for anonymous requests to the private response function.
- Sign in on `/organizer.html` with an allowlisted organizer address to view private records.
- Do not submit a fake/test RSVP to the live family poll; the first recorded responses should be real.
