# Document Heading

Trainy Global Rail Provider Status

Date: 2026-06-17

Summary

Trainy has successfully obtained access to most of the target provider ecosystem.

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

Status: Active

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

Recommended MVP:

* Station search
* Departure boards
* Service alerts

Priority:

Provider #1 after architecture refactor.

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

SWISS_OPEN_TRANSPORT_API_KEY

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

United Kingdom Darwin

Status: Active

Product:

Darwin Real Time Train Information (Push)

Source Type:

Kafka Pub/Sub

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

Implementation Notes:

Backend worker required.

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

Current Global Coverage

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

Blocked Regions:

* South Korea

Deferred Regions:

* Germany

Overall Status:

Trainy has sufficient provider coverage to proceed with the multi-provider architecture and global rollout.
