# Shelfie — Product Spec (Flutter + Supabase + Chrome/Edge Extension)

## 1) Product Overview

A personal "read & watch later" system that works across:
- **Browser extension (Chrome/Edge)** to save the current page/video via right-click.
- **Flutter app** (Windows desktop + Android phone initially; iOS/macOS optional later) to organize and consume saved items.

No accounts/logins for now (single user). Future-ready for **Google SSO** and **auto-tagging with an LLM**.

---

## 2) Core Use Cases

1. **Save from browser**  
    - Right-click → "Save to Read/View Later".  
    - Extension sends the page URL to a Supabase **Edge Function** that fetches metadata (title, description/snippet, hero image).  
    - For YouTube, fetch title + thumbnail.  
    - Item appears in the app under **Unread** (Reading or Viewing list).

2. **View & manage in app**  
    - See **Reading** (articles) and **Viewing** (videos) lists as cards with title + hero image + snippet + link.  
    - Open item in browser.  
    - Mark as **Read/View** (moves to Archive; stores finished_date).  
    - Manually add URL in app; app/Edge Function fetches metadata.  
    - Add/remove **tags** (preset + custom).  
    - **Search** & **filter by tags** across Unread and Archive.  
    - **Delete** item.

3. **Analytics in app**  
    - Key metrics + charts: pending items, completion rate, average time to complete, completions by week, tag/category trends, top domains/sources, streaks.

---

## 3) Architecture

### 3.1 High-Level

- **Client Apps**
  - Flutter (Windows desktop, Android).  
  - Browser Extension (Chrome/Edge Manifest V3).

- **Backend**
  - **Supabase Postgres** (primary DB).  
  - **Supabase Edge Functions** (metadata fetching, normalization, insert pipelines).  
  - **Supabase Auth** (unused for now; scaffolded for future Google SSO).  
  - **Storage** (optional later for caching thumbnails; initial version uses remote URLs).

- **Networking**
  - Flutter app uses **supabase-flutter** SDK.  
  - Extension calls **Edge Function** (preferred) or **Direct REST** as fallback.

### 3.2 Data Flow

**From extension/app (save URL) → Edge Function**
1. Request body: `{ url, source_type? }`  
2. Edge Function:
    - Validate URL.
    - Fetch HTML (server-side to avoid CORS).
    - Extract metadata:
      - `title`: `<title>` or `meta[property="og:title"]` or `meta[name="twitter:title"]`.  
      - `description`: `meta[name="description"]` or `meta[property=
     - `image_url`: `meta[property="og:image"]` or `meta[name="twitter:image"]`. Resolve **relative → absolute** against page URL.  
     - `canonical_url`: `<link rel="canonical">` if present; fallback to requested URL.  
     - `domain`: parse hostname.  
     - `content_type`: infer `article` vs `video` (YouTube domain mapping; fallback heuristics).  
   - **YouTube special-casing:**
     - Detect `youtube.com`/`youtu.be`.  
     - Extract `videoId`.  
     - Title: via **oEmbed** (`https://www.youtube.com/oembed?url=...&format=json`) or fallback to HTML `<title>`.  
     - Thumbnail: `https://img.youtube.com/vi/{videoId}/hqdefault.jpg`.  
     - No snippet required.
   - Insert row into `items` with status = `unread`.

**From app (update status/tags/search) → Supabase**
- Direct CRUD via Supabase client & SQL RPCs/views for filtering.

---

## 4) Data Model (Postgres / Supabase)

> Naming uses snake_case. Add `created_at`/`updated_at` timestamps everywhere. All IDs are `uuid` unless noted.

### 4.1 Tables

**`users`** (placeholder for future SSO)
- `id uuid pk default gen_random_uuid()`  
- `email text unique null`  
- `display_name text null`  
- `created_at timestamptz default now()`  
- `updated_at timestamptz default now()`

> For now, items can have `user_id null`. When SSO arrives, backfill a single user row and set FK.

**`items`** (saved pages/videos)
- `id uuid pk default gen_random_uuid()`
- `user_id uuid null references users(id) on delete set null`
- `url text not null` — original URL
- `canonical_url text null` — normalized/canonical URL (for dedup)
- `domain text not null` — e.g., `nytimes.com`, `youtube.com`
- `title text null`
- `description text null` — short snippet if available
- `image_url text null` — absolute URL; cleaned
- `content_type text not null check (content_type in ('article','video'))`
- `status text not null default 'unread' check (status in ('unread','completed'))`
- `added_at timestamptz not null default now()`  — (alias of created_at for clarity)
- `finished_at timestamptz null`  — set when marked completed
- `source_client text not null default 'unknown'` — `browser_extension`, `app_manual`, etc.
- `source_platform text null` — `windows`, `android`, `edge`, `chrome`, etc.
- `notes text null` — reserved
- `metadata jsonb not null default '{}'` — raw parsed meta (debug/future use)
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`

**Indexes:**
- `idx_items_status` on `(status)`
- `idx_items_added_at` on `(added_at desc)`
- `idx_items_finished_at` on `(finished_at desc)`
- `idx_items_domain` on `(domain)`
- `idx_items_title_trgm` on `title` (pg_trgm extension) for fuzzy search
- `idx_items_canonical_url_unique` unique on `(coalesce(canonical_url, url))` to prevent duplicates (deferrable initially deferred)

**`tags`**
- `id uuid pk default gen_random_uuid()`
- `user_id uuid null references users(id) on delete set null`
- `name text not null` (lowercase, unique per user)
- `type text not null default 'custom' check (type in ('preset','custom'))`
- `created_at timestamptz default now()`
- `updated_at timestamptz default now()`
- Unique index: `(user_id, name)`

**`item_tags`** (many-to-many)
- `item_id uuid references items(id) on delete cascade`
- `tag_id uuid references tags(id) on delete cascade`
- `created_at timestamptz default now()`
- PK: `(item_id, tag_id)`

**`events`** (optional, for analytics/streaks)
- `id uuid pk default gen_random_uuid()`
- `item_id uuid references items(id) on delete cascade`
- `event_type text not null check (event_type in ('added','completed','deleted','tag_added','tag_removed'))`
- `at timestamptz not null default now()`
- `metadata jsonb not null default '{}'`

### 4.2 Triggers

- **`set_updated_at`** on all tables to bump `updated_at`.
- **`items_set_finished_at`**: when `status` changes to `completed` and `finished_at is null`, set `finished_at = now()`. When reverting to `unread`, nullify `finished_at`.
- **`items_enforce_content_type`**: if domain is youtube/vimeo → `video`, else default `article`.
- **`items_normalize_image_url`**: ensure `image_url` stored absolute (done at Edge Function level; trigger validates not relative).
- **`items_events`**: log `added` on insert; `completed` on status change; `deleted` on delete.

### 4.3 Views / RPCs

**Views**
- `unread_items_v`: `select * from items where status='unread' order by added_at desc;`
- `archive_items_v`: `select * from items where status='completed' order by finished_at desc;`

**RPCs**
- `search_items(query text, tag_ids uuid[] default null, status_filter text default null)`  
  - Full-text/fuzzy over title/description/domain with optional tags and status.
- `analytics_summary(since timestamptz default now() - interval '90 days') returns jsonb`  
  - Computes metrics (see Analytics section).

---

## 5) Browser Extension (Chrome & Edge, MV3)

### 5.1 Features

- Adds a **context menu** item “Save to Read/View Later”.
- On click:
  - Gets `tab.url` and (optionally) `selectionText`.
  - Posts `{ url, source_client: 'browser_extension', source_platform: <browser name> }` to Supabase Edge Function.
  - Shows toast/badge confirmation.

- Optional: **Content script** to scrape `<title>` and metas as a fallback when Edge Function unavailable; still prefer server-side fetching (consistent, avoids CORS, handles relative URLs better).

### 5.2 Structure

- `manifest.json` (MV3):
  - `permissions`: `"contextMenus", "activeTab", "storage", "scripting", "tabs"`
  - `host_permissions`: `"<all_urls>"`
  - `background.service_worker`: `background.js`
  - `icons`: 16/32/48/128
  - (Edge uses same MV3 with Edge store)

- `background.js`:
  - Create context menu at install.
  - Handle `onClicked`.
  - Fetch to Edge Function endpoint with project anon key (stored in extension `storage` with simple obfuscation; acceptable for single-user MVP).
  - Retry logic & offline queue (store pending in `chrome.storage.local`, sync later).

- `content.js` (optional):
  - Extract `<title>`, OG tags when needed.

- **Settings page** (optional):
  - Configure Supabase URL & anon key.
  - Toggle: “Use content script fallback”.

### 5.3 Edge Function API Contract (Extension → Backend)

`POST /functions/v1/save_url`
```json
{
  "url": "https://example.com/article",
  "source_client": "browser_extension",
  "source_platform": "chrome"
}
```

Response (201):
```json
{
  "id": "uuid",
  "status": "unread",
  "content_type": "article",
  "title": "Example Title",
  "description": "Snippet...",
  "image_url": "https://example.com/og.jpg",
  "domain": "example.com",
  "added_at": "2025-08-13T01:23:45Z"
}
```
---

## 6) Supabase Edge Functions
Implement in Deno/TypeScript.

### 6.1 `save_url`
- Validate URL & dedup (check `coalesce(canonical_url, url)`).
- Fetch HTML with a standard User-Agent.
- Parse metadata:
    - title: <title> → og:title → twitter:title.
    - description: meta[name=description] → og:description.
    - image_url: og:image → twitter:image; resolve relative via URL API.
    - canonical_url: <link rel=canonical>.
    - domain: new URL(url).hostname.
- YouTube:
    - Extract videoId from URL patterns.
    - Fetch oEmbed JSON for title or parse <title>.
    - Set image_url = https://img.youtube.com/vi/{id}/hqdefault.jpg.
    - content_type = 'video'.
- Upsert into items.
- Return created row.

### 6.2 `add_item_manual`
Same as `save_url` but `source_client=app_manual`.

### 6.3 `update_status`
- Body:` { id: uuid, status: 'unread' | 'completed' }`.
- Applies trigger to set `finished_at`.

### 6.4 `list_presets`
Returns recommended preset tags (see below).
---

## 7) Preset Tags
Seed table with common categories (type=`preset`), e.g.:

ai-ml, engineering, product, design, startup, career, health, finance, read-later, watch-later, deep-dive, quick, tutorial, reference, news, longform, shortform.

Add via SQL seed or Edge Function on first run. Users can add custom tags any time.
---

## 8) Flutter App

### 8.1 Tech Choices

- **Language/Framework**: Flutter (3.x), Dart.
- **State mgmt**: Riverpod or Bloc (Riverpod recommended).
- **Data layer**: supabase_flutter, dio (for any direct calls), freezed + json_serializable for models.
- **Local caching** (optional): drift or hive for offline; initial MVP can rely on live queries.
- **Navigation**: go_router.
- **UI**: Material 3; flutter_blurhash (optional for image placeholders); cached_network_image.
- **Charts**: fl_chart.

### 8.2 Screens

**Home Tabs**: Reading | Viewing | Archive | Analytics

**Reading/Viewing Lists:**
- Grid/List toggle.
- Cards: hero image (16:9), title (2 lines), snippet (2 lines for articles), domain, added_at (relative), tags (chips).
- Actions: Open, Mark as Read/View, Tag, Delete.
- Search bar (debounced), Tag filter (multi-select), Sort (Added date, Domain, Title).

**Archive:**
- Reverse chronological by finished_at.
- Same card UI; status badge `Completed`.

**Add URL Modal/Dialog:**
- Input URL.
- On submit → call `add_item_manual`.
- Show preview card (title + image) after success.

**Item Details** (optional):
- Larger preview, all metadata, quick actions (Open, Toggle status, Edit tags).

**Tag Manager:**
- List tags, search tags, create/delete tag, mark preset/custom.

**Analytics:**
- Metrics tiles + charts (see §9).

### 8.3 UX Details

- **Hero image fallback**: show domain favicon (e.g., `https://www.google.com/s2/favicons?sz=64&domain_url={domain}`) or colored placeholder with domain initials.
- **Open in browser**: use `url_launcher`.
- **Mark as completed**: one-tap from card (checkbox icon).
- **Undo snackbar** on delete or mark completed.
- **Infinite scroll** with pagination (by `added_at`/`finished_at` cursor).
- **Pull-to-refresh**.

### 8.4 Performance

- Use `cached_network_image` with disk cache.
- Limit card text lines; lazy list builders.
- Paginate queries: page size 20–30.
---

## 9) Analytics (Metrics & Visualizations)

### 9.1 Metrics (top tiles)

- **Pending items**: count of `status='unread'` (Reading / Viewing and total).
- **Completed in last 7/30 days**.
- **Average time to complete**: `avg(finished_at - added_at)` for completed.
- **Completion rate**: completed / (completed + unread added in period).
- **Median time to complete**.

### 9.2 Charts

- **Completions by week** (last 12–26 weeks): bar chart; y=completed items.
- **Adds vs Completes over time** (line chart): two lines per week.
- **Breakdown by tags** (top 10 tags): horizontal bar; counts of completed in period.
- **Top domains** (pie or bar): share of total items added/completed.
- **Age of backlog** (histogram): distribution of `now - added_at` for unread.
- **Streaks** (line with annotations): consecutive days with ≥1 completion.

### 9.3 Computation

SQL in `analytics_summary()`:
- Use `generate_series` for weeks.
- Joins to `item_tags`/`tags` for tag breakdown.
- Return compact JSON for Flutter to render.

---

## 10) Search & Filters

- **Search** across title, description, domain using pg_trgm.
- **Filters:**
    - status (Unread/Completed/All)
    - content_type (Article/Video)
    - tag_ids (multi)
    - domain (select top N)
    - date range (added or finished)
- **Sort:**
    - Added (newest first)
    - Finished (newest first)
    - Title (A→Z)
    - Domain (A→Z)

---

## 11) Deduplication & Normalization

- Canonical URL via `<link rel=canonical>` if available.
- Strip tracking params (`utm_`, `fbclid`, etc.) in Edge Function.
- Unique index on `coalesce(canonical_url, url)`.
- On duplicate save:
    - Update `added_at` only if item was previously deleted; otherwise ignore.
    - Option: increment a `save_count` field (future).

---

## 12) Error Handling & Edge Cases

- **Relative og:image** → resolve with `new URL(src, pageURL).toString()`.
- **Missing metadata:**
    - Title: fallback to hostname or path.
    - Image: favicon or placeholder.
    - Description: empty (do not block).
- **Non-HTML URLs**: detect content-type; if not HTML and not YouTube, store URL, title from filename.
- **Private/paywalled pages**: metadata often still available; else minimal record.
- **Offline extension**: queue saves in `chrome.storage.local` and retry.

---

## 13) Security & Privacy

### 13.1 RLS (Row Level Security)

- For single-user dev, can temporarily relax RLS.
- Prepare policies that allow:
    - Anonymous reads/writes for items/tags only from your device IPs or with a secret header (via Edge Functions).
    - Prefer all writes via Edge Functions with a service role key (never exposed client-side). App reads can use anon key with RLS policies if needed.

### 13.2 Secrets

- Edge Functions use service role key from Supabase env.
- Extension uses anon key; acceptable for personal use.
- **CORS**: allow your app origins and `chrome-extension://*`.

---

## 14) Testing Strategy

### 14.1 Unit tests

- URL parser (YouTube ID extraction).
- Relative → absolute URL resolver.
- Metadata extractor on sample HTMLs.
- Dedup logic.

### 14.2 Integration tests

- Edge Function end-to-end with real pages (staged).
- Flutter: repository tests with Supabase emulator or test project.

### 14.3 UI tests

- List rendering & pagination.
- Search & filter interplay.
- Tag add/remove flows.

### 14.4 Manual scenarios

- Save same URL twice.
- Save YouTube short vs normal link vs youtu.be.
- Delete, undo, and re-add.
- Archive view ordering.

---

## 15) Deployment & Distribution

### 15.1 Supabase

- Create project, run schema SQL, deploy Edge Functions (`supabase functions deploy`).
- Configure CORS.

### 15.2 Flutter

- **Windows**: `flutter build windows` → installer via Inno Setup/Wix (optional).
- **Android**: `flutter build apk` (or appbundle).

### 15.3 Extension

- Load unpacked for dev.
- Package & publish to Chrome Web Store and Edge Add-ons (optional later).

---

## 16) Future Enhancements (Scaffolded)

### 16.1 Google SSO

- Enable Supabase Google provider; enforce RLS by `auth.uid()`.
- Migrate existing rows by setting `user_id` for your account.

### 16.2 LLM Auto-Tagging

- New Edge Function `auto_tag_url`:
    - Fetch page, run LLM (OpenAI/Azure) prompt to produce top 3 tags from your taxonomy; create missing tags and attach.
    - Toggle per user.

### 16.3 Read time & progress

- Estimate read time by word count (if content extraction added).
- Track "opened" events.

### 16.4 Content extraction & offline cache

- Use Readability library in Edge Function for clean text (optional).
- Store sanitized HTML or text for offline reading (Supabase Storage).

### 16.5 Multi-platform

- macOS/iOS builds.
- Firefox extension (MV2/MV3 parity).

---

## 17) Phase-wise Implementation (No Timelines)

### Phase 1 — MVP Save & Consume
- **DB**: items, triggers, minimal RLS (or disabled in dev).
- **Edge Function**: save_url (articles & YouTube).
- **Extension**: context menu → save_url.
- **Flutter app**: Reading/Viewing tabs, cards, open URL, mark completed, Archive.

### Phase 2 — Tags, Search, Filters
- **DB**: tags, item_tags, presets seeding, views/RPCs.
- **App**: Tag chips, Tag Manager, add/remove tags; search & filters; sort.
- **Edge Function**: add_item_manual, list_presets.

### Phase 3 — Analytics
- **DB**: events (optional), analytics_summary() RPC.
- **App**: Analytics dashboard (tiles + charts), date range selectors.

### Phase 4 — Robustness & Polish
- Dedup (canonical URL + UTM stripping).
- Offline queue in extension; cached images in app.
- Delete/Undo; confirmations; pagination tuning.
- Security hardening (RLS with function-only writes).
- Packaging (Windows installer; signed extension optional).

### Phase 5 — Future-Ready Hooks
- Scaffold Google SSO (disabled by default).
- Stub auto_tag_url endpoint (feature-flagged).

---

## 18) Example SQL (Schema Snippets)

```sql
-- Enable extensions
create extension if not exists pg_trgm;
create extension if not exists pgcrypto;

-- ITEMS
create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references public.users(id) on delete set null,
  url text not null,
  canonical_url text null,
  domain text not null,
  title text null,
  description text null,
  image_url text null,
  content_type text not null check (content_type in ('article','video')),
  status text not null default 'unread' check (status in ('unread','completed')),
  added_at timestamptz not null default now(),
  finished_at timestamptz null,
  source_client text not null default 'unknown',
  source_platform text null,
  notes text null,
  metadata jsonb not null default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_items_status on public.items(status);
create index if not exists idx_items_added_at on public.items(added_at desc);
create index if not exists idx_items_finished_at on public.items(finished_at desc);
create index if not exists idx_items_domain on public.items(domain);
create index if not exists idx_items_title_trgm on public.items using gin (title gin_trgm_ops);
create unique index if not exists idx_items_canonical_unique on public.items (coalesce(canonical_url, url));

-- TAGS
create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references public.users(id) on delete set null,
  name text not null,
  type text not null default 'custom' check (type in ('preset','custom')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, name)
);

-- ITEM_TAGS
create table if not exists public.item_tags (
  item_id uuid references public.items(id) on delete cascade,
  tag_id uuid references public.tags(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (item_id, tag_id)
);

-- VIEWS
create or replace view public.unread_items_v as
  select * from public.items where status='unread' order by added_at desc;

create or replace view public.archive_items_v as
  select * from public.items where status='completed' order by finished_at desc;

-- TRIGGERS
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger trg_items_updated_at before update on public.items
for each row execute function public.set_updated_at();

create or replace function public.items_status_finished_at()
returns trigger language plpgsql as $$
begin
  if new.status='completed' and (old.status is distinct from 'completed') then
    new.finished_at := coalesce(new.finished_at, now());
  elsif new.status='unread' and old.status='completed' then
    new.finished_at := null;
  end if;
  return new;
end $$;

create trigger trg_items_status_finished before update on public.items
for each row execute function public.items_status_finished_at();
```
---

## 19) Edge Function Pseudocode (`save_url`)
```ts
// Deno (Supabase Edge Function)
import { serve } from "std/http/server.ts";
import { createClient } from "supabase-sdk"; // pseudocode import

serve(async (req) => {
  try {
    const { url, source_client = "browser_extension", source_platform = "chrome" } = await req.json();

    const u = new URL(url); // will throw if invalid
    const domain = u.hostname;

    // fetch HTML
    const res = await fetch(url, { headers: { "user-agent": "ReadLaterBot/1.0" } });
    const html = await res.text();

    // parse meta (use a lightweight HTML parser)
    const meta = parseMeta(html); // find title, description, og:image, canonical

    // YouTube handling
    let content_type = "article";
    let image_url = meta.image_url;
    let title = meta.title;

    const vid = extractYouTubeId(u);
    if (vid) {
      content_type = "video";
      title = title || (await fetchOEmbedTitle(url)) || `YouTube Video (${vid})`;
      image_url = `https://img.youtube.com/vi/${vid}/hqdefault.jpg`;
    }

    // resolve relative image URLs
    if (image_url) image_url = new URL(image_url, url).toString();

    const canonical_url = meta.canonical_url ? new URL(meta.canonical_url, url).toString() : null;

    // insert
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data, error } = await supabase
      .from("items")
      .insert({
        url,
        canonical_url,
        domain,
        title,
        description: meta.description || null,
        image_url: image_url || null,
        content_type,
        status: "unread",
        source_client,
        source_platform,
        metadata: meta.raw
      })
      .select()
      .single();

    if (error) throw error;
    return new Response(JSON.stringify(data), { status: 201 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
```
---

## 20) Non-Functional Requirements

- **Performance**: save action < 1s for metadata fetch (network permitting); UI lists render under 16ms/frame on scroll.
- **Reliability**: retry with exponential backoff on failed saves; idempotent dedup.
- **Maintainability**: modular Edge Functions; typed models in Flutter; clear RPC boundaries.
- **Portability**: works on Windows + Android; future iOS/macOS with minimal changes.
- **Accessibility**: large touch targets, semantic labels for screen readers, sufficient contrast.

---

## 21) Definition of Done (per Phase)

- **P1**: Save from extension; items appear in Flutter; open & mark completed; archive ordering correct.
- **P2**: Tags CRUD; attach/detach tags; search and tag filters work across Unread/Archive.
- **P3**: Analytics renders with correct numbers vs SQL; date range switch affects charts.
- **P4**: Dedup verified on repeated saves; relative images resolved; extension offline queue tested.
- **P5**: Google SSO sign-in succeeds; items scoped by user_id when enabled (feature flag).

---


