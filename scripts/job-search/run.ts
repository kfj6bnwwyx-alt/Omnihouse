import Anthropic from "@anthropic-ai/sdk";
import { betaZodTool } from "@anthropic-ai/sdk/helpers/beta/zod";
import { google } from "googleapis";
import { z } from "zod/v4";

// @anthropic-ai/sdk@0.95.1's betaZodTool runtime needs zod/v4 schemas, but its
// .d.ts types reference zod (v3). Cast schemas with `asV3Schema` at the call
// site to silence the typecheck; runtime is v4-correct.
const asV3Schema = <T>(schema: T): import("zod").ZodType => schema as never;

interface JobRow {
  date_seen: string;
  company: string;
  role: string;
  location: string;
  remote_type: string;
  comp: string;
  source: string;
  url: string;
  fit_tier: "Strong" | "Worth a look" | "Stretch";
  why_fit: string;
  mission_flag: "Green" | "Neutral" | "Red";
  status: string;
  dedup_key: string;
}

const SHEET_ID = required("SHEET_ID");
const JOBS_TAB = process.env.JOBS_TAB_NAME ?? "Jobs";
const SKIP_TAB = process.env.SKIP_LIST_TAB_NAME ?? "Skip List";
const EMAIL_TO = required("EMAIL_TO");
const TODAY = new Date().toISOString().slice(0, 10);

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env var: ${name}`);
  return v;
}

function sheetsClient() {
  const json = JSON.parse(
    Buffer.from(required("GOOGLE_SERVICE_ACCOUNT_JSON_B64"), "base64").toString("utf8"),
  );
  const auth = new google.auth.GoogleAuth({
    credentials: json,
    scopes: ["https://www.googleapis.com/auth/spreadsheets"],
  });
  return google.sheets({ version: "v4", auth });
}

function gmailClient() {
  const oauth2 = new google.auth.OAuth2(
    required("GMAIL_OAUTH_CLIENT_ID"),
    required("GMAIL_OAUTH_CLIENT_SECRET"),
  );
  oauth2.setCredentials({ refresh_token: required("GMAIL_OAUTH_REFRESH_TOKEN") });
  return google.gmail({ version: "v1", auth: oauth2 });
}

const sheetsReadDedup = betaZodTool({
  name: "sheets_read_dedup",
  description:
    "Read existing dedup_keys (column M of the Jobs tab) and skip-list company names (column A of the Skip List tab). Call this ONCE at the start of the run before any web discovery.",
  inputSchema: asV3Schema(z.object({})),
  run: async () => {
    const sheets = sheetsClient();
    const [jobsResp, skipResp] = await Promise.all([
      sheets.spreadsheets.values
        .get({ spreadsheetId: SHEET_ID, range: `${JOBS_TAB}!M:M` })
        .catch(() => null),
      sheets.spreadsheets.values
        .get({ spreadsheetId: SHEET_ID, range: `${SKIP_TAB}!A:A` })
        .catch(() => null),
    ]);
    const dedupKeys = (jobsResp?.data.values ?? [])
      .slice(1)
      .map((r) => (r[0] ?? "").toString().toLowerCase().trim())
      .filter(Boolean);
    const skipCompanies = (skipResp?.data.values ?? [])
      .slice(1)
      .map((r) => (r[0] ?? "").toString().toLowerCase().trim())
      .filter(Boolean);
    return JSON.stringify({
      dedup_keys: dedupKeys,
      skip_companies: skipCompanies,
      jobs_tab_exists: jobsResp !== null,
      skip_tab_exists: skipResp !== null,
    });
  },
});

const sheetsAppendJobs = betaZodTool({
  name: "sheets_append_jobs",
  description:
    "Append job rows to the Jobs tab. Call this with EVERY job included in the email digest. Columns are appended in this order: date_seen, company, role, location, remote_type, comp, source, url, fit_tier, why_fit, mission_flag, status, dedup_key.",
  inputSchema: asV3Schema(
    z.object({
      rows: z
        .array(
          z.object({
            date_seen: z.string(),
            company: z.string(),
            role: z.string(),
            location: z.string(),
            remote_type: z.string(),
            comp: z.string().default(""),
            source: z.string(),
            url: z.string(),
            fit_tier: z.enum(["Strong", "Worth a look", "Stretch"]),
            why_fit: z.string(),
            mission_flag: z.enum(["Green", "Neutral", "Red"]),
            status: z.string().default("New"),
            dedup_key: z.string(),
          }),
        )
        .min(0),
    }),
  ),
  run: async ({ rows }: { rows: JobRow[] }) => {
    if (rows.length === 0) return "No rows to append.";
    const sheets = sheetsClient();
    const values = rows.map((r) => [
      r.date_seen,
      r.company,
      r.role,
      r.location,
      r.remote_type,
      r.comp,
      r.source,
      r.url,
      r.fit_tier,
      r.why_fit,
      r.mission_flag,
      r.status,
      r.dedup_key,
    ]);
    await sheets.spreadsheets.values.append({
      spreadsheetId: SHEET_ID,
      range: `${JOBS_TAB}!A:M`,
      valueInputOption: "RAW",
      insertDataOption: "INSERT_ROWS",
      requestBody: { values },
    });
    return `Appended ${values.length} row(s) to ${JOBS_TAB}.`;
  },
});

const gmailCreateDraft = betaZodTool({
  name: "gmail_create_draft",
  description:
    "Create a Gmail draft for Simona to review and send. Pass HTML body styled per the brief. Plain-text fallback is optional but recommended.",
  inputSchema: asV3Schema(
    z.object({
      to: z.string(),
      subject: z.string(),
      htmlBody: z.string(),
      plainBody: z.string().optional(),
    }),
  ),
  run: async ({ to, subject, htmlBody, plainBody }) => {
    const gmail = gmailClient();
    const boundary = `=_b_${Date.now()}`;
    const mime = [
      `To: ${to}`,
      `Subject: ${subject}`,
      "MIME-Version: 1.0",
      `Content-Type: multipart/alternative; boundary="${boundary}"`,
      "",
      `--${boundary}`,
      "Content-Type: text/plain; charset=utf-8",
      "Content-Transfer-Encoding: 7bit",
      "",
      plainBody ?? stripHtml(htmlBody),
      "",
      `--${boundary}`,
      "Content-Type: text/html; charset=utf-8",
      "Content-Transfer-Encoding: 7bit",
      "",
      htmlBody,
      "",
      `--${boundary}--`,
    ].join("\r\n");
    const raw = Buffer.from(mime).toString("base64url");
    const resp = await gmail.users.drafts.create({
      userId: "me",
      requestBody: { message: { raw } },
    });
    return `Draft created: ${resp.data.id}`;
  },
});

function stripHtml(html: string): string {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<[^>]+>/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

const SYSTEM_PROMPT = `You run a daily curated job search for Simona Lo. Today's date is ${TODAY}.

# About Simona
Award-winning Creative Director / Art Director with 25+ years of agency leadership. Executive-level history: VP Group Creative Director at Digitas (JennAir luxury appliance work), SVP Executive Creative Director at Rosetta/SapientRazorfish (Samsung CRM oversight), Group Creative Director at Ogilvy (Aetna integrated brand campaigns). Also B-Reel, MRM/McCann, Razorfish.

Recent work via Seriph (her independent practice): Reckitt DTC CPG social campaigns (Air Wick, Finish, Jet Dry, Lysol, Resolve) at MRM/McCann, Samsung CRM email systems, MasterCard Global B2B Enterprise visual branding.

Notable awards: Cannes Bronze Lion, Effie Gold, One Show Gold, Webby, Jay Chiat Grand Prix, W3 Gold.

Brand experience: DTC/CPG, luxury (JennAir, David Yurman), financial services (American Express, BlackRock, MasterCard, TD Ameritrade, Prudential, TIAA-CREF, E*TRADE), travel (British Airways, Marriott, IHG), healthcare (Aetna, Enfamil), automotive (Ford, Mercedes-Benz, Acura, Nissan, Audi), retail, entertainment (Disney, Sony Pictures, FX, Universal), consumer brands (Coca-Cola, Anheuser Busch, Axe, Stila, IKEA, Microsoft, Samsung).

# What she's looking for
Roles: Creative Director, Senior Creative Director, Group Creative Director, Executive Creative Director, Art Director, Senior Art Director, Associate Creative Director, Senior Designer, Visual Designer, Design Lead, Design Director.

Explicitly EXCLUDE: Product Designer, UX Designer, UI Designer, Service Designer, Industrial Designer, Game Designer, any role primarily software-product design rather than advertising/marketing/brand creative.

Location: Remote-first preferred. Hybrid acceptable for full-time roles in NYC metro. Freelance and contract welcome. Onsite-only roles outside NYC = exclude.

Comp: Senior level. No hard floor, but flag anything below $130k base for full-time or below $100/hr for freelance as "low for level."

# Sources to check (priority order)
1. LinkedIn Jobs — search for the role titles above + remote, sort by date, posted last 24h. Use \`web_search\` with \`site:linkedin.com/jobs/view\` and role variants.
2. Working Not Working
3. Dribbble Jobs
4. Behance JobList
5. Built In NYC — design/creative category (\`web_fetch\` https://www.builtinnyc.com/jobs/search/creative-director and /art-director — this is reliably accessible and includes posted-date and comp ranges)
6. We Work Remotely — design jobs
7. Authentic Jobs
8. AIGA Design Jobs
9. Indeed — filtered to her role titles + remote
10. Upwork — senior-level only, $80+/hr, established clients only
11. Career pages for these brands (last 24h): Glossier, Warby Parker, Rothy's, Allbirds, Mejuri, Quince, Oatly, Liquid Death, Magic Spoon, Olipop, Chamberlain Coffee, Rare Beauty, Fenty, Tatcha, Aesop, Vuori, Alo, Lululemon, Casper, Brooklinen, Parachute, Away, Recess, Poppi, Hims/Hers, Ro, Function of Beauty, Curology, Spotify, Netflix, Hulu, NYT, Vox Media

If a source returns 403/503/empty, note it for the email footer ("Sources skipped today: ...") and continue. Do not fail the run on a single bad source.

# Workflow
1. **First**: call \`sheets_read_dedup\` to load \`dedup_keys\` and \`skip_companies\`. Use this to dedupe and skip across runs.
2. Run discovery via \`web_search\` and \`web_fetch\` across the sources above. Aim for postings in the last 24-48 hours.
3. For each candidate, generate a \`dedup_key\`:
   - Lowercase the company name, strip "Inc", "LLC", "Ltd", and punctuation.
   - Lowercase the role title, strip "Senior", "Sr.", "Sr", "Lead", and parenthetical team names.
   - Concatenate: \`{normalized_company}::{normalized_role}\`.
   - Example: "Glossier" + "Senior Art Director (Social)" -> \`glossier::art director\`.
4. Drop a candidate if:
   - \`dedup_key\` matches anything in the loaded \`dedup_keys\`.
   - Normalized company matches anything in \`skip_companies\`.
   - Role title contains: product designer, UX, UI, service design, game design, industrial design.
   - Onsite-only outside NYC metro.

# Mission-driven assessment
For each surviving candidate, do a 60-second mission check by \`web_fetch\`-ing the company's About / Our Story page. Flag:
- **Green**: B Corp, Public Benefit Corporation, or explicit mission language around climate/sustainability, health equity, education access, social justice, or measurable social/environmental impact backed by specifics.
- **Neutral**: standard for-profit, no strong signals. (Most companies.)
- **Red**: extractive/harmful — fossil fuels, gambling, predatory fintech, defense weapons, tobacco, vaping, addiction-design products. Note the concern but still include the job (Simona decides).

Skip the deep research. Just read the About page.

# Fit scoring
- **Strong**: role title and seniority match her targets, brand/industry aligns with her experience, remote or NYC hybrid, comp signals appropriate.
- **Worth a look**: decent role + seniority but one weaker dimension (unfamiliar industry, hybrid in another city, comp not listed but company size suggests right range, freelance scope unclear).
- **Stretch**: right industry/interesting brand but role might be a level below, or right role but industry is outside her wheelhouse.

# Curation rule (most important)
Quality over quantity. Do NOT pad the email.
- Maximum 8 jobs total.
- Aim for 3-6 typical.
- If <3 Strong matches exist, say so honestly. Do not promote Worth-a-Look to Strong to fill space.
- If zero matches exist, send the brief "no matches today" email.

# Append rows + create draft
After curation, ALWAYS in this order:
1. Call \`sheets_append_jobs\` with one row per included job (the same set going into the email). Use \`date_seen: "${TODAY}"\` and \`status: "New"\`. Do not include skipped/deduped jobs.
2. Call \`gmail_create_draft\` exactly once with \`to: "${EMAIL_TO}"\` and the full HTML email.

# Email format
Subject: \`Daily job matches - {date in "Mon DD" format} - {N} matches\` (or "0 matches" if zero).

HTML spec:
- Max width 600px, centered.
- System font stack: \`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif\`.
- Body 15px, line-height 1.5, color #1a1a1a on white.
- Section headers (Strong / Worth a look / Stretch): 13px uppercase, letter-spacing 0.05em, color #666, with a thin 1px solid #e5e5e5 bottom border.
- Each job in a card: 16px vertical padding, 1px solid #e5e5e5 bottom border between cards, no card backgrounds (clean white).
- Job title (role + company): 17px, weight 600, color #000.
- Meta line below title: 13px, color #666, format "{location} · {remote_type} · {source}{ · comp if listed}".
- Mission flag if Green or Red: small inline pill — Green = #d4edda bg / #155724 text "Mission-driven: {reason}". Red = #f8d7da bg / #721c24 text "Flag: {reason}".
- Why-fit line: 14px, color #333, italic. Reference her specific past work ("matches her Reckitt social CPG work at MRM/McCann", not "great fit for your background").
- Apply link: 14px, color #0066cc, weight 500.
- Footer: 12px gray with a "Manage in sheet" link to https://docs.google.com/spreadsheets/d/${SHEET_ID}/edit. Note any sources skipped today.

Order in email: Strong matches first, then Worth a look, then Stretch.

If zero matches: send a clean short email saying "No new matches found today across {N} sources checked. Tomorrow."

# Tone
She is senior. The email should respect that:
- No "Great news!" or marketing language.
- No emoji.
- Direct, scannable, one-line-per-fact.
- Why-fit lines reference specific past work.

# Output
After all tools have run, briefly summarize what you appended and drafted (job counts, draft ID). Do not produce a long final report — the email itself is the deliverable.`;

async function main() {
  const client = new Anthropic();
  const userKickoff = `Run the daily job search for ${TODAY}. Read dedup state, do discovery, filter, score, then APPEND rows to the Jobs tab and CREATE THE DRAFT. Be honest about curation; no padding. Send "0 matches" email if nothing qualifies.`;

  const finalMessage = await client.beta.messages.toolRunner({
    model: "claude-opus-4-7",
    max_tokens: 16000,
    thinking: { type: "adaptive" },
    output_config: { effort: "xhigh" },
    cache_control: { type: "ephemeral" },
    system: SYSTEM_PROMPT,
    tools: [
      { type: "web_search_20260209", name: "web_search" },
      { type: "web_fetch_20260209", name: "web_fetch" },
      sheetsReadDedup,
      sheetsAppendJobs,
      gmailCreateDraft,
    ],
    messages: [{ role: "user", content: userKickoff }],
  });

  for (const block of finalMessage.content) {
    if (block.type === "text") console.log(block.text);
  }
  console.log(`\nstop_reason: ${finalMessage.stop_reason}`);
  console.log(`usage: ${JSON.stringify(finalMessage.usage)}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
