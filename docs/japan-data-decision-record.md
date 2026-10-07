# Japan data decision record: ODPT and Shinkansen timetables

Status: **Proposed, needs a decision from Jacob (section 5).**
Date: 2026-10-07 · Plan item: [2.1](engineering-plan.md#phase-2--real-japan-data)
(blocks 2.2 to 2.8) · Author: Claude, from public documentation only.

## TL;DR

1. **ODPT does not carry Shinkansen timetables.** The only JR company in the
   catalog is JR East, and its timetable, train-location, GTFS and station
   timetable datasets all say 新幹線は含みません ("Shinkansen is not included")
   and cover Kanto commuter lines. JR Central, JR West, JR Kyushu and JR
   Hokkaido do not appear as data providers.
2. **JR East's ODPT data is Challenge-only.** All eight JR East datasets carry the
   *Public Transport Open Data Challenge Limited License* and the tag
   *Challenge 2026 only*. The Challenge rules limit the data to building the
   entry, forbid giving it to third parties, and require entries to be free to
   use during the contest. That rules out a paid app, and it rules out a Worker
   that republishes the data to app users.
3. **No open per-train realtime exists for Shinkansen.** The only JR realtime on
   ODPT is JR East GTFS-RT for Kanto commuter lines. The honest promise for Japan
   is a timetable plus line-level status, if either can be licensed, or trip
   times the rider enters.
4. **The earlier "ODPT works" evidence does not hold.** The ODPT fixtures in the
   repo are synthetic, and `scripts/ODPTSmoke.swift` passes on results from the
   JR East HTML scraper, so "16 Tokyo to Shin-Osaka trips" most likely came from
   the scraper, not ODPT (finding F7). The scraper is removed in this change.
5. **Recommendation:** ship Japan in 1.0 as rider-entered trips with reminders
   and countdowns (option A), and start the licensed-API and operator-deal
   conversations in parallel for 1.1 (options B and C).

## 1. Question

The plan assumed ODPT would expose Shinkansen timetables by service day, line
status, station and line geometry, and possibly per-train realtime, under terms
that allow a paid app (E7, 2.1, 2.2). This record answers that from public
documentation and lists what only an authenticated call or a person can confirm.

## 2. How this was researched, and its limits

Pages were read on 2026-10-07 through a page fetcher. Three limits matter:

- **developer.odpt.org is a JavaScript app**, so its terms, license texts and API
  specification could not be read. They are listed as gaps (section 6).
- The sandbox cannot reach ODPT hosts, so no API call was made. Nothing here
  comes from a live response.
- Where a source is a blog or a summary, it is marked *reported* and not relied
  on for a legal conclusion.

## 3. Findings

**F1. The ODPT Center has two license families.** Tokyo Metro's ten datasets on
the catalog carry the *Public Transportation Open Data Basic License*. JR East's
eight carry the *Challenge Limited License* ("Challenge 2026 only"). A 2022
developer post reports that the Center's terms made commercial use possible
(*reported*); the Basic License text is unread (gap G2).

**F2. JR East's datasets are Kanto commuter lines, without Shinkansen.** The
timetable dataset page says, verbatim:
「東京都、神奈川県、埼玉県、千葉県とその周辺の一部の在来線を対象とします。
新幹線は含みません。」 It also excludes some limited express trains, through-running
and extra trains.

| Dataset (JR East) | Format | Shinkansen |
| --- | --- | --- |
| Train timetable | JSON | Excluded |
| Station timetable | JSON | Excluded |
| Train location | JSON | Excluded |
| Train information (GTFS) | GTFS | Excluded |
| Train realtime (GTFS-RT) | Protocol Buffers | Excluded |
| Station information, route information, passenger survey | JSON | Not stated |

**F3. No other passenger JR company is on the Center.** A catalog search for
新幹線 returns five datasets, all JR East entries that exclude it. The organization
list has 132 providers; its first page shows JR East, JR East i-Stations and JR
Freight (a container-freight timetable), and no JR Central, West, Kyushu,
Hokkaido or Shikoku entry. The list looks name-sorted, so those would be expected
on that page, but I only saw page one. The Challenge 2026 and 2025 data lists name
no other passenger JR company and no Shinkansen. Confirm in the logged-in
catalog (G1).

**F4. Realtime is commuter-line only.** JR East's GTFS-RT covers part of the Kanto
area and excludes Shinkansen. A 2024 developer write-up reports that it carries
no vehicle positions (*reported*). There is no open per-train Shinkansen feed.

**F5. Terms that can be quoted today.** The Challenge 2026 entry rules (read in
English and Japanese; wording paraphrased, so re-read before relying on it):

| Rule | Effect |
| --- | --- |
| Conditions of entry, art. 3 | Entries must be free for anyone to use during the contest |
| Art. 25 | Challenge data may be used only to develop the entry |
| Art. 27 | Challenge data must not be given to third parties, paid or free |
| Arts. 18, 19 | Provider may stop or change the data; supply runs to the end of the Challenge |
| Art. 17 | No warranty of accuracy or completeness |

A Tokyo Challenge API guideline (2018, historical) also required showing where
the data came from, the retrieval time and `dc:date`, an accuracy disclaimer, not
using data past `dct:valid`, and refreshing at `odpt:frequency`. Plan to honor
all of these anyway; the current guideline is on the developer site (G2).

**F6. Access mechanics.** Registration is free, approval was reported as about two
business days, and the token is the `acl:consumerKey` query parameter. The Center
host is `api.odpt.org/api/v4`; each Challenge has its own host (for example
`api-challenge2024.odpt.org`). **Rate limits are not documented anywhere I could
read** (G4). Because the token travels in the URL, the Worker must never log
upstream URLs.

**F7. The repo's evidence for ODPT Shinkansen data is weak.**
`Tests/TrainyCoreTests/Fixtures/SOURCE_NOTES.md` says the ODPT fixtures are
"synthetic". `scripts/ODPTSmoke.swift` accepts a trip if its source is ODPT *or* a
string containing "official timetable", which is what the scraper emits. The app
turns an ODPT 404 into an empty list. `docs/Provider_Status.md` says "Japan ODPT:
Production Ready", but the matrix there records credential access only. The
project's own docs also expected the gap: `TrainyIOS/README.md` said "If ODPT
exposes route metadata but no timetable rows for a Shinkansen railway, Trainy
uses official JR timetable pages", and `docs/phase-0-baseline.md` records the
provider order as ODPT, then the JR pages "when ODPT route metadata exists but
timetable rows are missing". Both describe the scraper as the path that actually
fills the gap.

**F8. The scraper was the real source.** `JREastTimetableClient` parsed
`timetables.jreast.co.jp` HTML (including JR Central's Tokaido trains) with no
license. The plan flags this as an App Review risk (guideline 5.2.2) and a terms
risk; it is removed in this change (2.7).

**F9. Geometry is solved separately.** MLIT's 国土数値情報 *Railway data (N02)*
covers all passenger lines and stations including a Shinkansen class, as GeoJSON,
Shapefile or GML. Versions from 2020 on are CC BY 4.0, with source attribution
required; the 2024 edition reflects 2024-12-31. It has geometry and no times.
This suits 2.5 and needs no ODPT.

**F10. Cloudflare limits shape ingestion.** Workers Free allows 10 ms CPU per
invocation *including Cron Triggers*, 50 subrequests per invocation (KV counts),
and KV allows 1,000 writes and 100,000 reads per day. Workers Paid allows 30 s
CPU for cron intervals under an hour and 15 min otherwise. Parsing a
multi-megabyte timetable cannot fit in 10 ms, so **nightly ingestion inside the
Worker needs the Workers Paid plan**, or must run elsewhere and upload a
snapshot.

## 4. Options

| | What a rider gets in 1.0 | Data rights | Cost and effort | Main risk |
| --- | --- | --- | --- | --- |
| **A. Rider-entered trips** | Add a trip from the ticket (train, date, stations, times, car, seat); countdown, reminders, offline, history | None needed; the rider's own data | Lowest. Needs the 1.6 form and a "from your ticket" provenance kind | No train search for Japan; less magic than a feed |
| **B. Licensed timetable API** (for example Ekispert) | Train search, stop lists, possibly operation status | By contract | Recurring fees; contract terms for caching and offline use must be checked before building 2.2 to 2.4 | Terms may forbid storing results, which breaks offline and the snapshot model |
| **C. Operator data deal** | Same as B if granted | By agreement | Free if granted; slow and uncertain | 1.0 cannot depend on it |
| **D. NS-led 1.0** | Real Netherlands boards; Japan marked coming soon | NS terms already reviewed | Lowest engineering | Drops the Japan promise from the first release |
| E. Self-compiled timetable | Same as B | Unclear; copying a compiled timetable may breach copyright or terms | Ongoing manual work | **Not recommended** without legal advice |
| F. Unofficial scrapers and aggregators (JR sites, Yahoo!, delay-info feeds) | Same as B | None | Low | **Not recommended**: App Review 5.2.2 and terms risk |

Only Ekispert was checked: a free trial and a JSON/XML API exist
(https://api-info.ekispert.com/form/trial/). Its Shinkansen train-level coverage,
pricing and terms are unverified. Other vendors were not researched.

## 5. Recommendation and decision needed

Choose **A for 1.0**, then pursue **B and C** for 1.1, with D as the fallback if
A slips. Under A the plan changes as follows:

- **2.2** Worker ingestion is built source-neutral and stays dormant until a
  licensed feed exists (section 7).
- **2.3, 2.4, 2.6, 2.8** wait for the decision. **2.5** proceeds on N02 (F9).
  **2.7** is done here.
- **Copy and listing:** do not describe Japan as live or as searchable
  schedules until a licensed feed ships. Correct the "Production Ready" line in
  `docs/Provider_Status.md`.
- **Line status** has no open Shinkansen source; link to each operator's own
  status page instead of reproducing it.

## 6. Gaps only an authenticated call or a person can close

| # | Gap | How to close |
| --- | --- | --- |
| G1 | Does the logged-in Center expose any Shinkansen railway? | After registering, run `curl -s "https://api.odpt.org/api/v4/odpt:Operator?acl:consumerKey=$KEY"` and look for `JR-Central`, `JR-West`, `JR-Kyushu`, `JR-Hokkaido`; then `odpt:Railway?odpt:operator=odpt.Operator:JR-East` and look for `*Shinkansen`. Expected: none. If `odpt:Operator` is not served, use the `odpt:Railway` form for each operator. Keep the key out of chat and logs |
| G2 | Full text of the Basic License and current API guidelines: commercial use, redistribution, caching, attribution | Read https://developer.odpt.org/terms after login |
| G3 | May JR East's Challenge data be used after the contest? | Ask the ODPT secretariat (odpt-office@ubin.jp) |
| G4 | Per-token rate limits | Developer site, or the secretariat |
| G5 | Update cadence for any dataset we would use (`odpt:frequency`, `dct:valid`) | Inspect a response |
| G6 | Pricing, caching and offline terms, and Shinkansen coverage, of a licensed API | Ekispert trial form; ask for written terms |

## 7. What the Worker build does about this

`provider-proxy` gains a **source-neutral Japan snapshot service** (2.2): a
validated snapshot in KV, a scheduled ingestion, and `/v1/japan/*` routes. Its
ODPT adapter targets the Shinkansen railway IDs the app guessed, so a first live
run *tests this record's prediction* and is expected to report no data. It then
keeps the previous snapshot and says so in health. Three guards encode this
record:

- **A license gate.** A source must declare a commercial-use license; the
  Challenge Limited License is refused outright, so Challenge data cannot be
  published through the public routes.
- **No empty overwrite.** A run that finds zero trips never replaces a good
  snapshot.
- **Honest absence.** Without a snapshot the routes answer 503, never sample data.

Setup, cost and the secret name are in `provider-proxy/README.md`.

## 8. Sources (read 2026-10-07)

- ODPT overview and Center: https://www.odpt.org/overview/ and https://www.odpt.org/
- JR East organization and datasets: https://ckan.odpt.org/organization/jreast ·
  https://ckan.odpt.org/dataset/jreast__r_train_timetable ·
  https://ckan.odpt.org/dataset/odpt_jreast_tokyo_area
- Catalog search for 新幹線: https://ckan.odpt.org/dataset?q=新幹線 ·
  organizations: https://ckan.odpt.org/organization/
- Tokyo Metro datasets (Basic License): https://ckan.odpt.org/organization/tokyometro
- Challenge 2026: https://challenge2026.odpt.org/ja/opendata.html ·
  https://challenge2026.odpt.org/ja/entry.html
- Tokyo Challenge API guideline (2018): https://developer-tokyochallenge.odpt.org/terms/api_guideline.html
- API migration post (2022, *reported*): https://mikan.github.io/2022/03/31/migrate-odpt-api/
- JR East GTFS and GTFS-RT write-up (2024, *reported*): https://zenn.dev/takoyaki3/articles/25c036daaf0d75
- MLIT Railway data N02: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N02-2024.html ·
  terms: https://nlftp.mlit.go.jp/ksj/other/agreement.html
- Cloudflare limits: https://developers.cloudflare.com/workers/platform/limits/ ·
  https://developers.cloudflare.com/kv/platform/limits/
