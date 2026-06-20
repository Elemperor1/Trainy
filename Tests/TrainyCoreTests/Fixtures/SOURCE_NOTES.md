# Trainy Provider Fixtures

These fixtures are intentionally reduced samples for offline tests. They preserve provider field shapes without storing complete upstream pages or private configuration.

## Current Provider Fixtures

- `odpt_train_timetable_tokaido.json`: Synthetic ODPT TrainTimetable-shaped sample for a Tokaido Shinkansen Nozomi trip. The stop sequence, service labels, and public identifier shapes mirror Trainy's supported ODPT mapping.
- `odpt_train_information_tokaido.json`: Synthetic ODPT TrainInformation-shaped service notice used to verify localized text decoding for Shinkansen alerts.
- `jr_east_train_timetable_tohoku.html`: Minimal JR East timetable-shaped train-detail page that keeps only the selectors used by `JREastTimetableClient`.
- `starter_catalog_expectations.json`: Expected offline starter-catalog behavior derived from the in-repo Shinkansen starter catalog.

## Future Provider Fixture Backlog

- `future_providers/future_provider_fixture_backlog.json`: Structured backlog that separates active, public, verification-needed, deferred, and blocked providers as of `docs/Provider_Status.md` dated 2026-06-17.

## Future Provider Fixtures

- `future_providers/ns_departures_utrecht_centraal.json`: Reduced Netherlands NS departures response for Utrecht Centraal, captured from the NS travel information departures endpoint on 2026-06-17.
- `future_providers/ns_active_disruptions.json`: Reduced Netherlands NS active disruptions response, captured from the NS travel information disruptions endpoint on 2026-06-17.
- `future_providers/mtr_next_train_tuen_ma_tai_wai.json`: Hong Kong MTR next-train response for Tuen Ma Line at Tai Wai, captured from DATA.GOV.HK/MTR on 2026-06-17. Public source attribution: data provider and intellectual property owner are MTR Corporation Limited; DATA.GOV.HK lists a 10-second update frequency for this dataset.
- `future_providers/tdx_thsr_general_timetable.json`: Reduced Taiwan TDX THSR general timetable response, captured on 2026-06-17 after local OAuth exchange.
- `future_providers/tdx_tra_liveboard_taipei.json`: Reduced Taiwan TDX Taiwan Railway Taipei live-board response, captured on 2026-06-17 after local OAuth exchange.
- `future_providers/tfnsw_gtfs_static_sydneytrains_mini/`: Mini Transport for NSW Sydney Trains GTFS static feed for one trip, reduced from the official schedule ZIP on 2026-06-17.
- `future_providers/tfnsw_gtfs_rt_sydneytrains_trip_update.textproto`: First useful Transport for NSW Sydney Trains GTFS-RT v2 trip-update entity with a stop-time update, captured through the documented debug response on 2026-06-17. Public licence note: the TfNSW Open Data Hub page links this dataset to Creative Commons Attribution and TfNSW terms/acceptable-use pages.
- `future_providers/france_sncf_transport_dataset_metadata.json`: Reduced transport.data.gouv.fr metadata for the SNCF national rail dataset covering TGV, Intercites, and TER resources. Public licence in the metadata is `odc-odbl`.
- `future_providers/mta_lirr_gtfs_rt_trip_update.textproto`: Reduced public MTA Long Island Rail Road GTFS-RT trip-update sample, decoded from the no-key public feed on 2026-06-17. Production use should verify current MTA attribution and terms before launch.
- `future_providers/mta_metro_north_gtfs_rt_trip_update.textproto`: Reduced public MTA Metro-North GTFS-RT trip-update sample, decoded from the no-key public feed on 2026-06-17. Production use should verify current MTA attribution and terms before launch.
- `future_providers/swiss_gtfsrt_access_disallowed.json`: Evidence response showing a generic Swiss key was not enabled for the selected GTFS-RT endpoint. This is not a provider data sample; Swiss API Manager uses separate auth credentials per product.
- `future_providers/swiss_gtfs_rt_trip_updates.json`: Reduced Swiss Open Transport Data GTFS-RT trip-updates sample captured with the GTFS-RT product credential on 2026-06-18. The script stores only a reduced JSON test-format response and omits auth values and request headers.

## UK Rail Data Marketplace Fixture Status

UK Rail Data Marketplace access is active for Darwin Real Time Train Information (Push), price 0, licence Open, expires 2027-06-17, and NWR Realtime Performance Data API, price 0, licence OGL3, expires 2027-06-17. No UK fixture is stored yet because Darwin Push still needs a backend worker/Kafka consumer capture path, and NWR performance data needs API shape review before it is treated as a rider-facing source fixture.

No access tokens, API keys, auth headers, private request URLs, or local environment values are included.
