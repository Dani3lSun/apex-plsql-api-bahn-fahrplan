CREATE OR REPLACE PACKAGE bahn_fahrplan_api IS
  --
  -- API Package Spec for Deutsche Bahn Fahrplan REST API
  -- Source: http://data.deutschebahn.com/apis/fahrplan/
  --

  --
  -- Fahrplan REST API defaults
  --
  pub_fahrplan_host       VARCHAR2(50) := 'open-api.bahn.de';
  pub_fahrplan_rest_path  VARCHAR2(100) := '/bin/rest.exe';
  pub_fahrplan_rest_proto VARCHAR2(50) := 'https'; -- http or https
  pub_fahrplan_base_url   VARCHAR2(200) := bahn_fahrplan_api.pub_fahrplan_rest_proto ||
                                           '://' ||
                                           bahn_fahrplan_api.pub_fahrplan_host ||
                                           bahn_fahrplan_api.pub_fahrplan_rest_path;
  pub_ssl_wallet_path     VARCHAR2(200) := 'file:/home/oracle/bahn_openapi_wallet'; -- set your local wallet path
  pub_ssl_wallet_pwd      VARCHAR2(100) := 'bahn2016'; -- set your wallet password
  --
  -- Exceptions Error Codes
  --
  error_http_status_code CONSTANT NUMBER := -20002;
  error_db_fahrplan_code CONSTANT NUMBER := -20003;
  --
  -- Types and Records
  -- location stations
  TYPE t_location_stations_rec IS RECORD(
    station_name VARCHAR2(500),
    station_id   VARCHAR2(100),
    longitude    VARCHAR2(100),
    latitude     VARCHAR2(100));
  TYPE t_location_stations_tab IS TABLE OF t_location_stations_rec;
  -- locations other locations
  TYPE t_location_otherloc_rec IS RECORD(
    loc_name  VARCHAR2(500),
    loc_type  VARCHAR2(100),
    longitude VARCHAR2(100),
    latitude  VARCHAR2(100));
  TYPE t_location_otherloc_tab IS TABLE OF t_location_otherloc_rec;
  -- departure board
  TYPE t_departure_rec IS RECORD(
    train_name       VARCHAR2(100),
    train_type       VARCHAR2(100),
    stop_id          VARCHAR2(100),
    stop_name        VARCHAR2(500),
    stop_time        VARCHAR2(100),
    stop_date        VARCHAR2(100),
    direction        VARCHAR2(500),
    track            VARCHAR2(100),
    journeydetailref VARCHAR2(500));
  TYPE t_departure_tab IS TABLE OF t_departure_rec;
  -- arrival board
  TYPE t_arrival_rec IS RECORD(
    train_name       VARCHAR2(100),
    train_type       VARCHAR2(100),
    stop_id          VARCHAR2(100),
    stop_name        VARCHAR2(500),
    stop_time        VARCHAR2(100),
    stop_date        VARCHAR2(100),
    direction        VARCHAR2(500),
    track            VARCHAR2(100),
    journeydetailref VARCHAR2(500));
  TYPE t_arrival_tab IS TABLE OF t_arrival_rec;
  -- journey detail
  TYPE t_journey_rec IS RECORD(
    station_name VARCHAR2(500),
    station_id   VARCHAR2(100),
    longitude    VARCHAR2(100),
    latitude     VARCHAR2(100),
    arr_time     VARCHAR2(100),
    arr_date     VARCHAR2(100),
    dep_time     VARCHAR2(100),
    dep_date     VARCHAR2(100),
    track        VARCHAR2(100));
  TYPE t_journey_tab IS TABLE OF t_journey_rec;
  --
  -- Public Functions and Procedures
  --
  -- Check Server response HTTP error (2XX Status codes)
  PROCEDURE check_error_http_status;
  --
  -- Check DB Fahrplan API Server response for error
  -- #param i_response_clob
  PROCEDURE check_error_fahrplan_api(i_response_clob IN CLOB);
  --
  -- Fahrplan Location.name Service REST Call - Search for location and stations
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_search_string
  -- #return CLOB from REST response
  FUNCTION get_location_name_json(i_api_auth_key  IN VARCHAR2,
                                  i_language      IN VARCHAR2 := 'en',
                                  i_search_string IN VARCHAR2) RETURN CLOB;
  --
  -- Fahrplan departureBoard Service REST Call - departure board for a given station (id) and date/time
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_station_id
  -- #param i_date_time
  -- #return CLOB from REST response
  FUNCTION get_departure_board_json(i_api_auth_key IN VARCHAR2,
                                    i_language     IN VARCHAR2 := 'en',
                                    i_station_id   IN NUMBER,
                                    i_date_time    IN DATE := NULL)
    RETURN CLOB;
  --
  -- Fahrplan departureBoard Service REST Call - arrival board for a given station (id) and date/time
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_station_id
  -- #param i_date_time
  -- #return CLOB from REST response
  FUNCTION get_arrival_board_json(i_api_auth_key IN VARCHAR2,
                                  i_language     IN VARCHAR2 := 'en',
                                  i_station_id   IN NUMBER,
                                  i_date_time    IN DATE := NULL) RETURN CLOB;
  -- Fahrplan journeyDetail Service REST Call - information about the complete route of a vehicle
  -- Gets journeydetailref URL from departure or arrival board
  -- #param i_journeydetailref_url
  -- #return CLOB from REST response
  FUNCTION get_journey_detail_json(i_journeydetailref_url IN VARCHAR2)
    RETURN CLOB;
  --
  -- Fahrplan Location.name stations (StopLocation) inserted in APEX Collection
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_search_string
  -- #param i_apex_coll_name - default "STATIONS"
  PROCEDURE get_location_stations_apex(i_api_auth_key   IN VARCHAR2,
                                       i_language       IN VARCHAR2 := 'en',
                                       i_search_string  IN VARCHAR2,
                                       i_apex_coll_name IN VARCHAR2 := 'STATIONS');
  --
  -- Fahrplan Location.name other locations (CoordLocation) inserted in APEX Collection
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_search_string
  -- #param i_apex_coll_name - default "LOCATIONS"
  PROCEDURE get_location_otherloc_apex(i_api_auth_key   IN VARCHAR2,
                                       i_language       IN VARCHAR2 := 'en',
                                       i_search_string  IN VARCHAR2,
                                       i_apex_coll_name IN VARCHAR2 := 'LOCATIONS');
  --
  -- Fahrplan departureBoard inserted in APEX Collection
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_station_id
  -- #param i_date_time
  -- #param i_apex_coll_name - default "DEPARTURE_BOARD"
  PROCEDURE get_departure_board_apex(i_api_auth_key   IN VARCHAR2,
                                     i_language       IN VARCHAR2 := 'en',
                                     i_station_id     IN NUMBER,
                                     i_date_time      IN DATE := NULL,
                                     i_apex_coll_name IN VARCHAR2 := 'DEPARTURE_BOARD');
  --
  -- Fahrplan ArrivalBoard inserted in APEX Collection
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_station_id
  -- #param i_date_time
  -- #param i_apex_coll_name - default "ARRIVAL_BOARD"
  PROCEDURE get_arrival_board_apex(i_api_auth_key   IN VARCHAR2,
                                   i_language       IN VARCHAR2 := 'en',
                                   i_station_id     IN NUMBER,
                                   i_date_time      IN DATE := NULL,
                                   i_apex_coll_name IN VARCHAR2 := 'ARRIVAL_BOARD');
  --
  -- Fahrplan journeyDetail Service inserted in APEX Collection
  -- #param i_journeydetailref_url
  -- #param i_apex_coll_name - default "JOURNEY_DETAIL"
  PROCEDURE get_journey_detail_apex(i_journeydetailref_url IN VARCHAR2,
                                    i_apex_coll_name       IN VARCHAR2 := 'JOURNEY_DETAIL');
  --
  -- Fahrplan Location.name stations (StopLocation) as pipelined function
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_search_string
  -- #return PIPELINED
  FUNCTION get_location_stations_pipe(i_api_auth_key  IN VARCHAR2,
                                      i_language      IN VARCHAR2 := 'en',
                                      i_search_string IN VARCHAR2)
    RETURN bahn_fahrplan_api.t_location_stations_tab
    PIPELINED;
  --
  -- Fahrplan Location.name other locations (CoordLocation) as pipelined function
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_search_string
  -- #return PIPELINED
  FUNCTION get_location_otherloc_pipe(i_api_auth_key  IN VARCHAR2,
                                      i_language      IN VARCHAR2 := 'en',
                                      i_search_string IN VARCHAR2)
    RETURN bahn_fahrplan_api.t_location_otherloc_tab
    PIPELINED;
  --
  -- Fahrplan departureBoard as pipelined function
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_station_id
  -- #param i_date_time
  -- #return PIPELINED
  FUNCTION get_departure_board_pipe(i_api_auth_key IN VARCHAR2,
                                    i_language     IN VARCHAR2 := 'en',
                                    i_station_id   IN NUMBER,
                                    i_date_time    IN DATE := NULL)
    RETURN bahn_fahrplan_api.t_departure_tab
    PIPELINED;
  --
  -- Fahrplan ArrivalBoard as pipelined function
  -- #param i_api_auth_key
  -- #param i_language - default "en"
  -- #param i_station_id
  -- #param i_date_time
  -- #return PIPELINED
  FUNCTION get_arrival_board_pipe(i_api_auth_key IN VARCHAR2,
                                  i_language     IN VARCHAR2 := 'en',
                                  i_station_id   IN NUMBER,
                                  i_date_time    IN DATE := NULL)
    RETURN bahn_fahrplan_api.t_arrival_tab
    PIPELINED;
  --
  -- Fahrplan journeyDetail Service as pipelined function
  -- #param i_journeydetailref_url
  -- #return PIPELINED
  FUNCTION get_journey_detail_pipe(i_journeydetailref_url IN VARCHAR2)
    RETURN bahn_fahrplan_api.t_journey_tab
    PIPELINED;
  --
END bahn_fahrplan_api;
/
