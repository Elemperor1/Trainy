# Document Heading

Trainy Global Rail Provider Status

Date: 2026-07-20

Summary

Trainy has successfully obtained access to most of the target provider ecosystem.

Scope note (updated 2026-07-20): the provider list below primarily describes upstream portal or credential access; app implementation truth is owned by `docs/global-provider-implementation-checklist.md`. Japan Shinkansen and Netherlands NS are the current rider-active Trainy experiences. NS station search, departure boards, service alerts, failure recovery, provenance, production proxy, quota boundary, and release configuration are verified end to end. Other entries marked Active below must not be read as implemented or rider-live unless the checklist says so.

Current provider status:

* Japan ODPT: Active
* Netherlands NS: Active
* Taiwan TDX: Active
* Switzerland Open Transport Data: Active
* France SNCF / transport.data.gouv.fr: Active
* Transport for NSW: Active
* Hong Kong MTR: Public, no credential required
* UK Darwin Push: Active
* MTA LIRR / Metro-North: Available, likely no credential required
* Germany DB: Deferred
* South Korea: Blocked

⸻

Provider Status Matrix

Provider Status Credential Status Implementation Priority
Japan ODPT Active Acquired Existing
Netherlands NS Active Acquired High
Taiwan TDX Active Acquired High
Switzerland OTD/OJP Active Acquired Medium
France SNCF Active Acquired Medium
Transport for NSW Active Acquired High
Hong Kong MTR Public No key required High
UK Darwin Push Active Acquired Medium
MTA LIRR / Metro-North Available Verify access path Medium
Germany DB Deferred Not acquired Low
South Korea TAGO Blocked Not obtainable None

⸻

Provider Details

Japan ODPT

Status: Production Ready

Credential:

ODPT_CONSUMER_KEY

Capabilities:

* Shinkansen timetable
* Train information
* Route search
* Existing Trainy integration

Priority:

Maintain as flagship provider.

⸻

Netherlands NS

Upstream access status: Active

Trainy implementation status: Production rider path verified and active

Subscription:

Ns-App

Credential:

NS_SUBSCRIPTION_KEY

Capabilities:

* Departures
* Trips
* Journey details
* Disruptions
* Station lookup
* Station disruption information

Source links:

* NS API portal: <https://apiportal.ns.nl/>
* NS starter guide: <https://apiportal.ns.nl/startersguide>
* NS App API product: <https://apiportal.ns.nl/product#product=NsApp>
* NS API list: <https://apiportal.ns.nl/apis>
* NS website disclaimer: <https://www.ns.nl/disclaimer.html>

Research notes:

* Public portal copy says the NS App API exposes open timetable, works, and station-information data for developers.
* Starter guide confirms a product subscription key is required on every request.
* Public conditions reviewed on 2026-07-20 require responsible use of NS server capacity, allow immediate cutoff for suspected abuse, place responsibility on the subscription owner, prohibit NS logo use, and prohibit changing data in a way that spreads incorrect information. Trainy uses text attribution and contains no NS logo asset.
* The authenticated active `Trainy` subscription and `Ns-App` Reisinformatie API page were reviewed on 2026-07-20. The external non-paying limit is 300 requests per five minutes; clients must honor `Retry-After` after `429`.
* The authenticated product/API pages displayed no separate cache-duration, attribution, license, or reuse clause. The starter guide says product conditions are accepted only when a terms link or checkbox is shown and that absence of such a control means no product conditions are established; the active product page showed none. Public NS conditions and the disclaimer therefore remain controlling. Trainy's text attribution is a conservative provenance disclosure and its bounded caches are engineering choices, not claimed NS-prescribed wording or TTLs.

Recommended MVP:

* Station search
* Departure boards
* Service alerts

Implemented boundary:

* Trainy iOS sends only station search text or a validated station code to the Trainy provider proxy.
* The proxy exposes fixed station-search, departures, disruptions, and provider-health `GET` routes; it is not a general-purpose NS relay.
* `NS_SUBSCRIPTION_KEY` is added only inside the Worker and never returned, logged, or passed to Xcode.
* Public results are normalized to the exact attribution `Data from Nederlandse Spoorwegen (NS)` and provenance source `NS Reisinformatie API`, with explicit freshness metadata.
* The production Worker reserves actual cache-miss attempts from one subscription-wide rolling budget of 240 requests per five minutes, leaving 20% headroom below NS's published limit. A 48/minute location-local fast guard shared across NS operations precedes that global budget; unavailable quota coordination fails closed.

Verification record (2026-07-20):

* Final local Worker smoke queried exact code `UT`, returned 5 station matches with `UT` first and 20 fresh Utrecht departures, and scanned captured responses/logs for the actual credential and upstream-only markers without replaying raw Wrangler output.
* The owner-approved free endpoint `https://trainy-ns-provider-proxy.trainy-jacob.workers.dev` reported the secret binding as configured without returning it. Bootstrap smoke returned 5 Utrecht station matches, 20 fresh departures, and 2 active disruptions; `POST` and unknown-route checks returned `405` and `404`.
* The approved byte-identical migration bridge became version `65f469e7-ef2b-4acf-8503-e6f3793be5a2` and deployment `f9f5f96a-21da-4db9-bb5f-e87538361f37`. It applied migration tag `v1` and created the SQLite `NS_UPSTREAM_QUOTA` state boundary while preserving the already-serving contract. Health, station search, departures, disruptions, `405`, `404`, headers, and credential safety passed before promotion continued.
* Hardened version `0ece40b0-b27a-43aa-a865-55445909a2a1` (`ns-quota-v1`) is the sole 100% version in deployment `46a26a6a-8abe-4091-9b19-3c32b20ccefa`. Repeated edge checks returned exact code `UT` first after propagation; a fresh Amsterdam cache miss returned five departures through the fail-closed global quota path, a persistent client received normalized `429` and later recovered, and final disruption, method, route, health, no-store, and security-header checks passed.
* A canonical iPhone 17 candidate containing only the public URL exercised the real rider path. Pre-promotion coverage kept an initial unavailable response honest and retryable, recovered to Utrecht, transitioned through stale/expired and back to fresh, showed two alerts and separate source disclosures, and recovered after no-match. Post-promotion it rendered one source-backed `UT` station, two current departures, one current alert, and separate fresh board/alert disclosures from the production Worker.
* iPhone 17 / iOS 26.5 exercised station results, a fresh board, source-backed no-match, automatic stale copy, forced offline fallback, and recovery after the Worker restarted. Light and Dark Mode and AX2XL were checked separately.
* VoiceOver was enabled in the simulator. Its accessibility tree exposed logical headings/order, the labelled station field and 44-point search action, station name/code buttons, source/freshness text, and 54-point tabs. The simulator was restored to Large text, Dark Mode, VoiceOver off, and normal contrast afterward.
* Credential-neutral verification passed 58/58 iOS tests and 35/35 Workerd contract tests. The Worker suite covers coalescing, absolute response deadlines, field/body bounds, strict collection/timestamp validation, stale preservation, exact-code search ranking, missing-credential rejection before upstream allowance accounting, shared/global rate limits, fail-closed quota coordination, and health isolation. The canonical build succeeded with ODPT empty and only the public HTTPS proxy base URL configured. The expanded scan initially found an authorized credential retained only in an earlier Xcode DerivedData build-command attachment; that generated cache was removed. The clean rerun checked 58,811 repository/generated/log files and 122 shipping app files and found neither authorized local provider value nor an NS upstream-only app marker.

Production rollout and operating boundary:

* Cloudflare rejected the first non-serving candidate upload with API code `10211` before mutation because the new Durable Object lifecycle migration required an immediate deploy. The owner then explicitly approved the one-time exact-current-code bridge. The bridge payload matched the prior Worker bundle at SHA-256 `5242b151c5d2ff393a3efa5c1ff33b46342daeea27fa802d23708c464e1ad727` and changed only the class export, binding, and SQLite migration lifecycle.
* The hardened candidate was uploaded without traffic, inspected, dry-run, and then promoted only after bridge checks passed. The downloaded active script's SHA-256 is `76866b72d9c41dde9c0d9402f3da56b34becf76893c4792153cb35d591cf1767`; it contains the exact-code ranking and one global quota object without exposing the Worker secret.
* The migration bridge is the valid post-migration rollback baseline. Original version `37bdadd5-3652-4c54-8ee8-e0cba777c6c2` cannot be used as a rollback target across the Durable Object lifecycle boundary. During an incident, roll back to bridge version `65f469e7-ef2b-4acf-8503-e6f3793be5a2` or disable the route; never delete the migration or state.
* The owner selected the free `workers.dev` hostname. It has no selected-zone WAF layer, but the subscription-wide Durable Object removes location-local quota accounting as the provider-capacity boundary. Define the monitoring/emergency-disable threshold and keep a custom-domain migration separately approval-gated.
* Release builds receive only the HTTPS proxy base URL. The app source contains no NS key or upstream host/header, and a missing proxy setting remains an honest unavailable state rather than changing provider status or loading a local credential.

Cloudflare account and observability record (2026-07-20):

* Wrangler OAuth, the targetless bootstrap, free-hostname attachment, migration bridge, candidate upload, and 100% promotion were separately approved. The final status check confirmed only version `0ece40b0-b27a-43aa-a865-55445909a2a1` at 100%.
* The temporary Wrangler OAuth session was logged out after verification, and its mode-600 plaintext fallback configuration file was removed. Future changes require a new short-lived authorization.
* The dedicated target is `trainy-ns-provider-proxy`; the existing shared `trainy-provider-proxy` service is not an allowed deployment target for this NS-only contract.
* Namespace IDs `1001` and `1002` were unused across the account's current Worker bindings. The final Worker keeps the 60/minute client guard, uses one shared 48/minute location-local fast guard, and enforces the global rolling 240/5-minute budget in the SQLite Durable Object. The account has zero zones, so the free hostname cannot receive a selected-zone WAF/rate rule.
* A real-secret dry run passed with the binding hidden. The Worker stores the secret server-side; public health reports only whether it is configured. Preview URLs remain disabled, and no custom domain or schedule exists.
* The dashboard confirms Workers Free: 100,000 requests/day, 10 ms CPU/request, and 200,000 Workers Logs events/day. Cloudflare documents three-day log retention for Free. Persisted automatic invocation logs and traces are disabled; the allowlisted custom event omits rider inputs. An authorized real-time Tail check nevertheless showed that Tail's transient platform envelope includes request URL, headers/IP, and Cloudflare metadata while the Tail session is active. Tail is therefore an incident-only, query-sensitive diagnostic surface, not evidence that Cloudflare never receives request metadata. Re-check membership, sampling, retention, and any new gateway/zone layer before traffic changes.
* The authenticated NS product review and complete release path are verified. NS is rider-active in Trainy provider metadata as of this record.

Priority:

Maintain as Trainy's first non-Japan rider-active provider.

⸻

Taiwan TDX

Status: Active

Credentials:

TDX_CLIENT_ID
TDX_CLIENT_SECRET

Capabilities:

* THSR timetable
* Taiwan Railway timetable
* Station boards
* Service information

Recommended MVP:

* THSR city-pair search
* Taiwan Railway departures

Priority:

Provider #3

⸻

Switzerland Open Transport Data

Status: Active

Credential:

Product-specific API Manager authToken credentials:

* `SWISS_OJP20_API_KEY` for `tedp_ojp20` / `ojp_2.0_plan`
* `SWISS_GTFS_RT_API_KEY` for `tedp_gtfs_rt` / `tedp_gtfs_rt_plan`
* `SWISS_GTFS_SA_API_KEY` for `tedp_gtfs_sa` / `tedp_gtfs_sa_plan`
* `SWISS_FORMATION_SERVICE_API_KEY` for `tedp_formation_service_api` / `formation_service_plan`
* `SWISS_SIRI_PT_API_KEY` for `tedp_siri_pt` / `siri_pt_plan`
* `SWISS_SIRI_SX_API_KEY` for `tedp_siri_sx` / `siri_sx_plan`
* `SWISS_SIRI_ET_API_KEY` for `tedp_siri_et` / `siri_et_plan`
* `SWISS_OJPFARE_API_KEY` for `tedp_ojpfare` / `ojp_fare_plan`

Do not assume a generic Swiss token has access to every product.

Capabilities:

* GTFS
* GTFS-RT
* OJP
* SIRI
* Nationwide rail coverage

Implementation Notes:

Backend normalization recommended.

Priority:

Provider #5

⸻

France SNCF / transport.data.gouv.fr

Status: Active

Credential:

TRANSPORT_DATA_GOUV_FR_TOKEN
SNCF_API_TOKEN (if required)

Capabilities:

* GTFS
* GTFS-RT
* Station information
* Timetable data

Implementation Notes:

Backend ingestion required.

Priority:

Provider #6

⸻

Transport for NSW

Status: Active

Credential:

TFNSW_API_KEY

Capabilities:

* GTFS
* GTFS-RT
* Vehicle positions
* Trip updates

Recommended MVP:

Sydney Trains departures.

Priority:

Provider #4

⸻

Hong Kong MTR

Status: Active

Credential:

None required

Source:

DATA.GOV.HK MTR Next Train dataset

Capabilities:

* Realtime arrivals
* Station board information

Implementation Notes:

Fastest additional provider to implement.

Priority:

Provider #2

⸻

United Kingdom Rail Data Marketplace

Status: Active

Products:

* Darwin Real Time Train Information (Push)
* NWR Realtime Performance Data API

Rail Data Marketplace product URLs:

* Darwin Push: <https://raildata.org.uk/dashboard/dataProduct/P-3f10bf96-d8e8-4041-aa5e-d75d82c45c4e/overview>
* NWR Realtime Performance Data API: <https://raildata.org.uk/dashboard/dataProduct/P-80b653cd-bb2a-4897-a69a-4980e6e554da/overview>

Access:

* Darwin Push: Active, price 0, licence Open, expires 2027-06-17
* NWR Realtime Performance Data API: Active, price 0, licence Open Government Licence 3.0, expires 2027-06-17

Source Type:

* Darwin Push: Kafka Pub/Sub
* NWR Realtime Performance Data API: API

Credential Type:

Username
Password
Consumer Group

Environment Variables:

UK_DARWIN_KAFKA_BOOTSTRAP
UK_DARWIN_TOPIC
UK_DARWIN_USERNAME
UK_DARWIN_PASSWORD
UK_DARWIN_CONSUMER_GROUP

Capabilities:

* Realtime departures
* Realtime arrivals
* Delays
* Platform changes
* Cancellations
* Realtime performance metrics from NWR

Implementation Notes:

Backend worker required for Darwin Push. NWR Realtime Performance Data API can be evaluated as a secondary UK rail performance/status source, but rider-facing station-board implementation should still start from Darwin Push unless the NWR API exposes a simpler MVP surface.

Architecture:

Darwin Push
→ UK Ingest Worker
→ Normalized Rail Models
→ Trainy API
→ iOS App

Priority:

Provider #7

⸻

MTA LIRR / Metro-North

Status: Available

Credential:

To be verified

Capabilities:

* GTFS
* GTFS-RT
* Commuter rail realtime

Priority:

Provider #8

⸻

Germany

Status: Deferred

Reason:

Official DB APIs require paid access.

Potential Future Sources:

* GTFS.de
* DELFI
* OpenData ÖPNV

Priority:

Deferred until after core provider rollout.

⸻

South Korea

Status: Blocked

Attempted Sources:

* TAGO
* data.go.kr
* Seoul Open Data

Result:

Access restricted to South Korean citizens.

Official response received from provider support confirming foreign developers cannot obtain access.

Recommendation:

Move to partnership-required status.

Priority:

None.

⸻

Recommended Implementation Order

1. Provider Registry
2. Normalized Rail Models
3. Netherlands NS
4. Hong Kong MTR
5. Taiwan TDX
6. Transport for NSW
7. Switzerland
8. France
9. UK Darwin Push
10. MTA LIRR / Metro-North

Deferred:

* Germany
* South Korea

⸻

Current Upstream/Credential Coverage

Active Regions:

* Japan
* Taiwan
* Hong Kong
* Netherlands
* Switzerland
* France
* United Kingdom
* Australia (NSW)
* United States (planned via MTA)

Production rider-active regions remain narrower than this access list. Trainy's current rider-active experiences cover Japan Shinkansen and Netherlands NS.

Blocked Regions:

* South Korea

Deferred Regions:

* Germany

Overall Status:

Trainy has sufficient provider coverage to proceed with the multi-provider architecture and global rollout.
