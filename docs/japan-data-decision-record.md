# Japan data decision record: ODPT and Shinkansen timetables

Status: **Decided 2026-10-07: option A (rider-entered trips) for 1.0, with B and C
pursued in parallel (section 5).**
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
5. **Services exist, but none is self-serve.** Ekispert and NAVITIME document
   Shinkansen train number, name, platform and stops, behind sales-led contracts
   with free 90-day trials. Their terms forbid keeping results (Ekispert: fetch
   every time; NAVITIME: no caching unless the application says so), which
   collides with offline trips and a Worker snapshot. The raw JR timetable
   dataset these vendors license (交通新聞社, monthly CSV/XML/GTFS) fits the
   snapshot model but is sold to companies only (F11 to F14).
6. **Decision:** Jacob chose option A on 2026-10-07. Japan ships in 1.0 as
   rider-entered trips with reminders and countdowns, and the trials and
   licence inquiries start now (options B and C), so a licensed source can
   follow once quotes, terms and a legal entity exist.

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
- The services research (F11 to F14) was done by three parallel readers using a
  summarizing page fetcher, so quoted wording is relayed, not byte-exact. Re-read
  every contract term in the original before relying on it (gaps G7 to G9).

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

**F11. No open or official source allows Shinkansen train-level reuse.**
Checked 2026-10-07 for timetables and status:

| Source | Covers | Terms | Usable? |
| --- | --- | --- | --- |
| ODPT and CKAN, every publisher | JR East Kanto lines; a search for 新幹線 returns only JR East's exclusions | Basic, CC BY, Challenge | No Shinkansen |
| GTFS Data Repository, Mobility Database, Transitland | No JR feed found (one Kurobe City bus line is named 新幹線生地線) | n/a | No |
| Research GTFS (gtfs-gis.jp/gtfs4research) | Hokuriku Shinkansen, 2023 to 2025 editions; dropped from the 2026-06 edition | 「データの利用は調査・研究目的に限ります」, unofficial | No |
| MLIT and data.go.jp | An annual ridership PDF; no timetable data | n/a | No |
| JR East, Central, West, Hokkaido, Kyushu sites and Smart EX | Timetables and status are published | JR East's site rules refuse 「複製・転用・転載・電磁的加工・送信・頒布・二次的使用」 of the photographs, logos, images and text on the site and do not name timetables. JR Central's notice (relayed, not re-read) forbids copying without the rights holder's permission | Not without permission; scraping them is what 2.7 removed |
| JR East 「リアルタイムデータ連携基盤」 (real-time data linkage platform) | Delay time and position for JR East's Shinkansen (Tohoku, Hokkaido, Joetsu, Hokuriku, Yamagata, Akita), not Tokaido or Sanyo | Offered to route-guidance providers for a fee (「有償で提供可能」); Yahoo!, Val Laboratory and Jorudan are named users (Impress Watch, 2023-02-21 and 2023-08-31) | Paid, companies only |

The author of gtfs-gis.jp writes 「我が国の鉄道についてはオープンデータで公開されているものがほとんどありません」
(Japanese rail has almost no open data).

**F12. Commercial timetable services exist, and they are sales-led.**

| Service | Shinkansen train-level data | Who can sign up | Price | Keeping results |
| --- | --- | --- | --- | --- |
| Ekispert API, Standard plan (Val Laboratory) | Yes, documented: train name and number, platform and stops, with times from the six JR companies. Per-line coverage unverified | Marketed to companies (法人向け); the terms set no corporate or Japan requirement; invoice billing, annual or monthly | On request: initial fee plus metered, and timetable data adds operator licence fees | Banned: fetch every time (TOS 27(1)(8)) |
| Ekispert Free and Prepaid | No: Free returns only web page URLs, Prepaid has no timetable search | Self-serve | Free; 5,500 yen per 5,000 requests | n/a |
| NAVITIME API, direct | Documented as a paid option (`train_data=timetable` adds train number, train name, platform and stops). Shinkansen coverage unverified | Trial form, then sales and invoice; the product page says 法人向け | Table unpublished; setup fee and a 10,000-access minimum | No caching unless the application names it (Art. 5.5) |
| NAVITIME on RapidAPI | No: train timetable data is 「APIマーケットでは利用不可」 | Self-serve | Free for 500 accesses; $200 or $300 a month | Cache banned |
| Jorudan Open API and Biz API | Open: no, routes ignore timetables. Biz: unverified | Open: self-serve after review. Biz: sales | Open: free, 10,000 calls a month. Biz: from 354,000 yen | No sublicensing |
| Ekitan | Unverified | Inquiry form, companies | Unpublished | Unpublished |
| Google Routes, Apple MapKit | No: Google transit returns no results in Japan, MapKit returns ETA only | Self-serve | n/a | Google bans storing |

Both Ekispert and NAVITIME offer a free 90-day trial. Ekispert's trial is for
evaluation and building only, must not be shown to third parties (which likely
rules out external TestFlight), and limits the data area (*reported*: Tokyo,
Kanagawa, Osaka and Hokkaido). NAVITIME says a trial key arrives in two to four
business days. Neither can back a released app.

**F13. Those terms collide with offline trips and a Worker snapshot.** Ekispert
TOS 27(1)(8) bans 「鉄道時刻情報の利用により出力されるデータを保持して再利用する行為」
(keeping and reusing timetable output) and says the data must be fetched each
time. NAVITIME Art. 5.5 bars saving data 「キャッシュ等に」 except for uses named
in the application. Both also restrict passing the service on: Ekispert 27(1)(7)
bans secondary use and resale, NAVITIME 5.2 bars 「譲渡、使用許諾、貸与その他の一切の処分」,
and neither says outright whether a server may relay normalized results to app
users. Ekispert 27(1)(10) needs written consent for a competing 経路検索・乗換案内
service, which a Japan trip search could be read as. Each of these needs the
vendor's written answer (G7, G8).

**F14. The upstream dataset can be licensed directly.** 交通新聞社 (Kotsu
Shimbun) sells JR旅客6社 train timetables, formations and station data as CSV, XML
or GTFS, updated monthly, to companies and organizations only, under a
時刻情報使用許諾契約 (time-information licence agreement). Its listed customers
include NAVITIME, Jorudan, Ekitan, Val Laboratory and Google. A monthly dataset is
the shape the Worker's snapshot expects, and it would allow offline use if the
licence says so. Price, the field list (train numbers, platforms) and whether a
foreign company or sole proprietor qualifies are unverified (G9).

## 4. Options

| | What a rider gets in 1.0 | Data rights | Cost and effort | Main risk |
| --- | --- | --- | --- | --- |
| **A. Rider-entered trips** | Add a trip from the ticket (train, date, stations, times, car, seat); countdown, reminders, offline, history. A later option is prefilling it from a pasted Smart EX or えきねっと confirmation, parsed on the device (formats unverified) | None needed; the rider's own data | Lowest. Needs a manual trip form (plan items 1.6 and 1.7 start it) and a "from your ticket" provenance kind | No train search for Japan; less magic than a feed |
| **B. Licensed timetable API** (Ekispert Standard or NAVITIME direct) | Train search, train number and name, platform, stops (documented; per-line Shinkansen coverage unverified) | By contract, with fees (F12) | Recurring fees, an operator licence fee on Ekispert, invoice onboarding. The 90-day trial cannot back a release | The terms ban keeping results (F13), which breaks offline trips and the Worker snapshot unless the vendor agrees in writing. Without that, the design is a query-through relay with nothing stored, which the vendor must also allow |
| **C. Operator data licence** (交通新聞社 monthly dataset, or a deal with an operator) | Train search from a nightly snapshot, offline; the fields the dataset holds | By licence agreement (時刻情報使用許諾契約, F14) | Price unpublished. Companies and organizations only. A new adapter into the Worker's snapshot builder under `commercial-agreement` | Needs a legal entity and a budget; field list, price and eligibility unverified (G9) |
| **D. NS-led 1.0** | Real Netherlands boards; Japan marked coming soon | NS terms already reviewed | Lowest engineering | Drops the Japan promise from the first release |
| E. Self-compiled timetable | Same as B | Unclear; copying a compiled timetable may breach copyright or terms | Ongoing manual work | **Not recommended** without legal advice |
| F. Unofficial scrapers and aggregators (JR sites, Yahoo!, delay-info feeds) | Same as B | None | Low | **Not recommended**: App Review 5.2.2 and terms risk |

B and C do not exclude each other, and neither blocks A. The Ekispert and
NAVITIME trials are free for 90 days and can show the real response shape, line
coverage and field names while the written answers are pending. They cannot
back a released app or a public TestFlight (F12).

## 5. Decision

**Decided 2026-10-07: A for 1.0.** Jacob chose rider-entered trips on the
project thread's decision card. B and C start now so a licensed source can follow
in 1.1, and D is the fallback if A slips. Starting costs time, not money, and
commits to nothing:

- Request the Ekispert and NAVITIME trial keys, and put the questions in G7 and
  G8 to both vendors in writing.
- Send the licence inquiry to 交通新聞社 (G9).
- Revisit this record when the first written answers arrive. B is workable for
  1.0 or 1.1 only if a vendor agrees in writing to what Trainy needs: a Worker
  relay, and a rider's saved trip keeping the train, times and platform it was
  found with. C is workable if the licence reaches a sole proprietor or the
  company Trainy forms.

Under A the plan changes as follows:

- **2.2** Worker ingestion is built source-neutral and stays dormant until a
  licensed feed exists (section 7).
- **2.3** splits. The Release hygiene part does not depend on a data source and
  proceeds with Phase 1: drop the `ODPTConsumerKey` Info.plist entry and the
  local-key path from Release builds, and make the starter catalog Debug-only.
  The proxy-client rewrite waits for a licensed source.
- **2.4, 2.6, 2.8** wait. **2.5** proceeds on N02 (F9). **2.7** is done here.
- **1.6 and 1.7** carry the Japan experience. Implement manual trip entry (do
  not remove it) with train, date, stations, times, car and seat, and add a
  rider-entered kind to `SourceKind` once the Phase 0 split lands, so a fact the
  rider typed never reads as a feed fact.
- **Copy and listing:** do not describe Japan as live or as searchable
  schedules until a licensed feed ships. Correct the "Production Ready" line in
  `docs/Provider_Status.md`.
- **Line status** has no open Shinkansen source; link to each operator's own
  status page instead of reproducing it.

## 6. Gaps only an authenticated call or a person can close

| # | Gap | How to close |
| --- | --- | --- |
| G1 | Does the logged-in Center expose any Shinkansen railway? | After registering, run `curl -s "https://api.odpt.org/api/v4/odpt:Operator?acl:consumerKey=$KEY"` and look for `JR-Central`, `JR-West`, `JR-Kyushu`, `JR-Hokkaido`; then `odpt:Railway?odpt:operator=odpt.Operator:JR-East` and look for `*Shinkansen`. Expected: none. If `odpt:Operator` is not served, use the `odpt:Railway` form for each operator. Keep the key out of chat and logs. The local check in `provider-proxy/README.md` does the same through the Worker's parser with the key in a mode-600 file |
| G2 | Full text of the Basic License and current API guidelines: commercial use, redistribution, caching, attribution. This matters only if a Basic-licensed ODPT dataset is ever used, since the services research found no ODPT Shinkansen data | Read https://developer.odpt.org/terms after login |
| G3 | May JR East's Challenge data be used after the contest? | Ask the ODPT secretariat (odpt-office@ubin.jp) |
| G4 | Per-token rate limits | Developer site, or the secretariat |
| G5 | Update cadence for any dataset we would use (`odpt:frequency`, `dct:valid`) | Inspect a response |
| G6 | Who can sign: a sole proprietor outside Japan, or a newly formed company? Ekispert, NAVITIME and 交通新聞社 are all marketed to companies, and the Apple account type is also open | Ask in the same written inquiries (G7 to G9); settle the legal entity together with the Apple Developer enrollment |
| G7 | Ekispert: price including operator licence fees and the minimum term; may a Worker relay results to app users (TOS 27(1)(7) and (10)); may a rider's saved trip keep the train, times and platform it was found with (27(1)(8)); English output and romaji station input; which Shinkansen lines and date range the timetable covers; how the key's domain check works from a Cloudflare Worker | Written questions to Val Laboratory (info@val.co.jp or https://api-info.ekispert.com/form/inquiry/), after reading the terms in the original. Use the trial only to inspect responses: it forbids showing results to third parties |
| G8 | NAVITIME: price of the train-timetable option and the 10,000-access minimum; does naming "saving a rider's tracked trip" in the application satisfy Art. 5.5; may a server relay results; which Shinkansen lines are covered | Trial form, then written questions to sales (https://api-sdk.navitime.co.jp/api/specs/) |
| G9 | 交通新聞社 dataset: price; whether a foreign sole proprietor or a new company qualifies; field list (train numbers, platforms, formations); delivery format and schedule; whether a server snapshot and on-device storage are licensed uses | Inquiry in Japanese via https://www.kotsu.co.jp/service/jikoku_solution/data_sales/ |
| G10 | Is any licensed per-train delay or position feed open to a small app? JR East sells its platform data to route-guidance providers (F11), and the vendors in F12 describe line-level operation information only | Ask in the G7 to G9 inquiries. Until one is licensed, do not call Japan live (plan 2.8) |

## 7. What the Worker build does about this

`provider-proxy` gains a **source-neutral Japan snapshot service** (2.2): a
validated snapshot in KV, a nightly ingestion, and `/v1/japan/*` routes for
stations, trip search, trip detail and line-level notices. Its ODPT adapter
reads the railways in `JAPAN_ODPT_RAILWAYS`, which default to the Shinkansen
railway IDs the app guessed, so a first live run *tests this record's
prediction* and is expected to report no data. It then keeps any previous
snapshot and says so in health. The service is built and **switched off**: it
ships with no licence declared and no ODPT key. Four behaviours encode this record:

- **A licence gate.** The operator declares the licence the key's data may be
  republished under (`JAPAN_SOURCE_LICENSE`). Only `odpt-basic`,
  `commercial-agreement` and `cc-by-4.0` count. The Challenge Limited License
  (`odpt-challenge`), an empty value and an unknown value are refused: no request
  is made, nothing is stored, and the routes stop serving even data stored under
  an earlier declaration. Challenge data cannot be published through the public
  routes.
- **No empty overwrite.** A run with fewer than 10 trips, more than 25% rejected
  timetables, or under half the trips of the served snapshot never replaces a
  good snapshot.
- **Honest absence.** Without a snapshot the routes answer `503`, never sample
  data, and health reports `japan` as `unsupported`, `offline` or
  `missingCredential` as the case may be.
- **Line status is separate.** The disruptions route reads the operator feed
  directly, behind the same licence gate, and does not depend on a timetable
  snapshot. Shinkansen line notices therefore do not wait for timetables, but
  they appear only if ODPT carries those lines (G1).

**Closing G1 without deploying anything.** `provider-proxy/README.md` has a
step, "Check what ODPT returns, locally", that runs the real ingestion on the
loopback simulator with the key in a git-ignored mode-600 file. The console
reports, per railway, whether ODPT knows it and how many timetables it holds.
That answers G1 with the Worker's own parser and keeps the key off the command
line. G2 to G4 still need a person.

**If a licensed source arrives.** A dataset licence (option C) fits the shape
already built: a new adapter reads the vendor's monthly files into the same
snapshot builder, the operator declares `commercial-agreement`, and the routes,
guards, health and tests stay as they are. An API whose terms require fetching
every time (option B) does not fit the snapshot. It would be a query-through
route with nothing stored, which makes the Worker a relay that the vendor must
approve (G7, G8), and a tracked trip could not keep vendor-supplied times
offline unless the vendor allows it. No vendor adapter is built, because price,
terms and eligibility are unknown and a trial key cannot back a released app.

Setup, cost, the secret name and the production steps are in
`provider-proxy/README.md`. Running the nightly job needs Workers Paid; the
production account is on Free.

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
- JR East site rules (copyright clause): https://www.jreast.co.jp/site/rules.html
- JR East real-time data linkage platform: https://www.watch.impress.co.jp/docs/news/1480396.html
  (2023-02-21) · https://www.watch.impress.co.jp/docs/news/1527576.html (2023-08-31)
- Research GTFS for Hokuriku Shinkansen, gtfs-gis.jp/gtfs4research (*reported*;
  exact page not kept)
- Ekispert API: plans https://api-info.ekispert.com/plan/ · trial
  https://api-info.ekispert.com/form/trial/ · API reference
  https://docs.ekispert.com/v1/api/ · FAQ https://docs.ekispert.com/v1/faq/ ·
  restrictions https://docs.ekispert.com/v1/get-started/restriction/ · terms
  https://docs.ekispert.com/v1/WebService_TOS.pdf · official sample
  https://docs.ekispert.com/v1/api/search/course.html
- NAVITIME API: https://api-sdk.navitime.co.jp/api/specs/ (route search guide,
  trial, terms of use, product description and RapidAPI terms under it)
- Jorudan: https://norikae.jorudan.co.jp/openapi/ ·
  https://biz.jorudan.co.jp/service/biz_api.html
- Ekitan: https://go.ekitan.com/service/asp/transit/ ·
  https://go.ekitan.com/developer/trial/
- Google coverage: https://developers.google.com/maps/coverage
- 交通新聞社 data sales: https://www.kotsu.co.jp/service/jikoku_solution/data_sales/

Every page in F11 to F14 was read through a summarizing fetcher, so quoted
wording is relayed, not byte-exact. The JR East site rules and the two Impress
Watch articles were re-checked afterwards with targeted questions. Moovit, HERE,
Rome2rio, Apple MapKit and Google Routes were also checked and found unusable
for Shinkansen train data (not self-serve, no Japan transit, or caching banned).
