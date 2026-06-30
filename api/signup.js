// Vercel serverless function: POST /api/signup
// Called directly from the Webflow thank-you page via browser fetch.
// Upserts signup in Supabase, updates Kit subscriber's custom fields, adds the
// webinar tag (triggering the existing welcome automation with the referral link baked in).
//
// ENV VARS REQUIRED:
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   CONVERTKIT_API_SECRET
//   CONVERTKIT_WINNER_TAG_ID  (optional — applied when a referrer reaches REWARD_THRESHOLD)
//   REWARD_THRESHOLD          (optional — default 5)
//   WEBINAR_LANDING_URL       (server-authoritative webinar URL used in shareUrl)
//   DASHBOARD_BASE_URL        (e.g. https://app.naucidizajn.com)
//
// CORS origins allowed: naucidizajn.com and www.naucidizajn.com.

export const config = { runtime: 'nodejs' };

const ALLOWED_ORIGINS = [
  'https://naucidizajn.com',
  'https://www.naucidizajn.com',
];

export default async function handler(req, res) {
  const origin = req.headers.origin || '';
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];

  res.setHeader('Access-Control-Allow-Origin', allowedOrigin);
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Vary', 'Origin');

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch { body = {}; }
  }
  body = body || {};

  const email = cleanString(body.email).toLowerCase();
  const name = cleanString(body.name);
  const ref = cleanString(body.ref);
  const tagId = cleanString(body.tagId);
  // When tagId is empty, run Supabase-only mode (used by giveaway campaign — tracking
  // without Kit subscriber/automation; Bitrix sync happens via Make on a separate channel).
  const kitEnabled = !!tagId;

  // Webinar mode (kitEnabled=true): server is authoritative — uses the env-pinned URL so
  // Kit custom fields stay in sync with the campaign Kit thinks it's running.
  // Giveaway mode (kitEnabled=false): no Kit involved, so the body URL wins. Lets one
  // /api/signup serve multiple landing pages (giveaway-maj-2026, giveaway-jun-2026, etc.).
  const webinarUrl = kitEnabled
    ? (cleanString(process.env.WEBINAR_LANDING_URL) || cleanString(body.webinarUrl))
    : (cleanString(body.webinarUrl) || cleanString(process.env.WEBINAR_LANDING_URL));

  if (!email || !email.includes('@')) {
    return res.status(400).json({ error: 'invalid_email' });
  }
  if (!webinarUrl) {
    return res.status(400).json({ error: 'missing_config' });
  }

  const { firstName, lastName } = splitName(name);

  // 1. Upsert in Supabase. Idempotent on email.
  let signup;
  try {
    signup = await createSignup({ email, firstName, lastName, ref });
  } catch (err) {
    console.error('supabase create_signup failed', err);
    return res.status(500).json({ error: 'supabase_error' });
  }

  const dashboardUrl = `${process.env.DASHBOARD_BASE_URL}/?t=${signup.dashboard_token}`;
  const shareUrl = `${webinarUrl}?r=${signup.ref_code}`;

  // 2. Update Kit subscriber: custom fields + add tag (triggers welcome automation).
  //    Skipped in Supabase-only mode (kitEnabled=false) — used by giveaway campaign.
  if (kitEnabled) {
    try {
      await syncConvertKit({
        tagId,
        email,
        firstName,
        lastName,
        refCode: signup.ref_code,
        dashboardUrl,
        shareUrl,
      });
    } catch (err) {
      console.error('convertkit sync failed', err);
      // Signup is saved; return ref_code so widget still renders. Log for manual retry.
      return res.status(200).json({
        ok: true,
        ck: 'failed',
        refCode: signup.ref_code,
        dashboardUrl,
        shareUrl,
        count: 0,
        isNew: signup.is_new,
      });
    }

    // 3. If this signup pushes the referrer at or above REWARD_THRESHOLD, tag them.
    //    Best-effort — don't fail the response if tagging fails.
    if (signup.is_new && signup.referred_by) {
      try {
        await maybeTagWinner(signup.referred_by);
      } catch (err) {
        console.error('winner tag failed', err);
      }
    }
  }

  return res.status(200).json({
    ok: true,
    refCode: signup.ref_code,
    dashboardUrl,
    shareUrl,
    count: 0,
    isNew: signup.is_new,
    firstName: firstName || null,
  });
}

// ----- helpers -----

async function createSignup({ email, firstName, lastName, ref }) {
  const url = `${process.env.SUPABASE_URL}/rest/v1/rpc/create_signup`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: process.env.SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({
      p_email: email,
      p_first_name: firstName || null,
      p_last_name: lastName || null,
      p_referred_by: ref || null,
    }),
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`supabase ${resp.status}: ${txt}`);
  }

  const rows = await resp.json();
  const row = Array.isArray(rows) ? rows[0] : rows;
  if (!row) throw new Error('supabase returned no row');
  return {
    ref_code: row.out_ref_code,
    dashboard_token: row.out_dashboard_token,
    is_new: row.out_is_new,
    referred_by: row.out_referred_by,
  };
}

// Kit V4 API: two calls.
// 1. POST /v4/subscribers — upserts subscriber by email, writes custom fields
// 2. POST /v4/tags/{tag_id}/subscribers/{subscriber_id} — applies the tag,
//    which triggers the welcome automation.
async function syncConvertKit({ tagId, email, firstName, lastName, refCode, dashboardUrl, shareUrl }) {
  const apiKey = process.env.CONVERTKIT_API_SECRET;
  const headers = {
    'Content-Type': 'application/json',
    'X-Kit-Api-Key': apiKey,
  };

  // 1. Upsert subscriber with custom fields
  const createRes = await fetch('https://api.kit.com/v4/subscribers', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      email_address: email,
      first_name: firstName || undefined,
      state: 'active',
      fields: {
        last_name: lastName || '',
        referral_code: refCode,
        dashboard_url: dashboardUrl,
        share_url: shareUrl,
      },
    }),
  });

  if (!createRes.ok) {
    const txt = await createRes.text();
    throw new Error(`kit create_subscriber ${createRes.status}: ${txt}`);
  }
  const createJson = await createRes.json();
  const subscriberId = createJson?.subscriber?.id;
  if (!subscriberId) {
    throw new Error(`kit create_subscriber: no subscriber id in response: ${JSON.stringify(createJson).slice(0, 300)}`);
  }

  // 2. Apply tag (triggers welcome automation)
  const tagRes = await fetch(
    `https://api.kit.com/v4/tags/${encodeURIComponent(tagId)}/subscribers/${encodeURIComponent(subscriberId)}`,
    { method: 'POST', headers }
  );

  if (!tagRes.ok) {
    const txt = await tagRes.text();
    throw new Error(`kit apply_tag ${tagRes.status}: ${txt}`);
  }

  return { subscriberId };
}

// If a referrer's count just reached/exceeded the reward threshold, apply the winner
// tag in Kit. Idempotent — Kit accepts the same tag being applied multiple times.
async function maybeTagWinner(referrerRefCode) {
  const winnerTagId = process.env.CONVERTKIT_WINNER_TAG_ID;
  const apiKey = process.env.CONVERTKIT_API_SECRET;
  const threshold = Number(process.env.REWARD_THRESHOLD || 5);
  if (!winnerTagId || !apiKey) return;

  // Fetch referrer email + count of their referrals
  const supaHeaders = {
    apikey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
  };
  const refCodeEnc = encodeURIComponent(referrerRefCode);

  const [emailRes, countRes] = await Promise.all([
    fetch(`${process.env.SUPABASE_URL}/rest/v1/signups?ref_code=eq.${refCodeEnc}&select=email&limit=1`, { headers: supaHeaders }),
    fetch(`${process.env.SUPABASE_URL}/rest/v1/signups?referred_by=eq.${refCodeEnc}&select=ref_code`, {
      headers: { ...supaHeaders, Prefer: 'count=exact' },
    }),
  ]);

  if (!emailRes.ok || !countRes.ok) {
    throw new Error(`maybeTagWinner: supabase ${emailRes.status}/${countRes.status}`);
  }

  const referrerRows = await emailRes.json();
  const referrerEmail = referrerRows?.[0]?.email;
  if (!referrerEmail) return;

  const range = countRes.headers.get('content-range') || '*/0';
  const total = parseInt(range.split('/')[1] || '0', 10);
  if (total < threshold) return;

  // Apply Kit winner tag: upsert subscriber → apply tag
  const kitHeaders = { 'Content-Type': 'application/json', 'X-Kit-Api-Key': apiKey };
  const subRes = await fetch('https://api.kit.com/v4/subscribers', {
    method: 'POST',
    headers: kitHeaders,
    body: JSON.stringify({ email_address: referrerEmail, state: 'active' }),
  });
  if (!subRes.ok) throw new Error(`kit subscriber ${subRes.status}: ${await subRes.text()}`);
  const subId = (await subRes.json())?.subscriber?.id;
  if (!subId) throw new Error('kit subscriber: no id');

  const tagRes = await fetch(
    `https://api.kit.com/v4/tags/${encodeURIComponent(winnerTagId)}/subscribers/${encodeURIComponent(subId)}`,
    { method: 'POST', headers: kitHeaders }
  );
  if (!tagRes.ok) throw new Error(`kit apply winner tag ${tagRes.status}: ${await tagRes.text()}`);

  console.log(`[winner] tagged ${referrerEmail} (count=${total})`);
}

function cleanString(v) {
  if (typeof v !== 'string') return '';
  return v.trim();
}

function splitName(full) {
  if (!full) return { firstName: null, lastName: null };
  const parts = full.trim().split(/\s+/);
  if (parts.length === 1) return { firstName: parts[0], lastName: null };
  return { firstName: parts[0], lastName: parts.slice(1).join(' ') };
}
