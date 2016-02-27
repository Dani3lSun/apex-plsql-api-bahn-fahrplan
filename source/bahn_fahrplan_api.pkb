CREATE OR REPLACE PACKAGE BODY bahn_fahrplan_api IS
  --
  -- API Package Body for Deutsche Bahn Fahrplan REST API
  -- Source: http://data.deutschebahn.com/apis/fahrplan/
  --

  --
  --
  -- GENERAL HELPER FUNCTIONS
  --
  --
  /****************************************************************************
  * Purpose: Check Server response HTTP error (2XX Status codes)
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE check_error_http_status IS
    --
    l_status_code VARCHAR2(100);
    l_name        VARCHAR2(200);
    l_value       VARCHAR2(200);
    l_error_msg   CLOB;
    --
  BEGIN
    --
    -- get http headers from response
    FOR i IN 1 .. apex_web_service.g_headers.count LOOP
      l_status_code := apex_web_service.g_status_code;
      l_name        := apex_web_service.g_headers(i).name;
      l_value       := apex_web_service.g_headers(i).value;
      -- If not successful throw error
      IF l_status_code NOT LIKE '2%' THEN
        l_error_msg := 'Response HTTP Status NOT OK' || chr(10) || 'Name: ' ||
                       l_name || chr(10) || 'Value: ' || l_value || chr(10) ||
                       'Status Code: ' || l_status_code;
        raise_application_error(error_http_status_code,
                                l_error_msg);
      END IF;
    END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END check_error_http_status;
  --
  /****************************************************************************
  * Purpose: Check DB Fahrplan API Server response for error
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE check_error_fahrplan_api(i_response_clob IN CLOB) IS
    --
    l_fahrplan_err_text VARCHAR2(500);
    l_error_msg         VARCHAR2(1000);
    l_response_xml      xmltype;
    -- cursor xmltable auf json
    CURSOR l_cur_error IS
      SELECT err_code
        FROM xmltable('/json/Error' passing l_response_xml columns err_code path
                      'code');
    --
    l_rec_error l_cur_error%ROWTYPE;
    --
  BEGIN
    -- check response clob for error and code string
    IF i_response_clob LIKE '%Error%' AND i_response_clob LIKE '%code%' THEN
      -- json to xml
      l_response_xml := apex_json.to_xmltype(i_response_clob);
      -- open xml cursor
      OPEN l_cur_error;
      FETCH l_cur_error
        INTO l_rec_error;
      CLOSE l_cur_error;
      -- build error message (from Fahrplan Docs PDF)
      -- REST Request Errors
      IF l_rec_error.err_code = 'R0001' THEN
        l_fahrplan_err_text := 'Unknown service method';
      ELSIF l_rec_error.err_code = 'R0002' THEN
        l_fahrplan_err_text := 'Invalid or missing request parameters';
      ELSIF l_rec_error.err_code = 'R0007' THEN
        l_fahrplan_err_text := 'Internal communication error';
        -- Backend Server Errors
      ELSIF l_rec_error.err_code = 'S1' THEN
        l_fahrplan_err_text := 'The desired connection to the server could not be established or was not stable';
        -- Trip Search Errors
      ELSIF l_rec_error.err_code = 'H9380' THEN
        l_fahrplan_err_text := 'Dep./Arr./Intermed. or equivalent stations defined more than once';
      ELSIF l_rec_error.err_code = 'H9360' THEN
        l_fahrplan_err_text := 'Error in data field';
      ELSIF l_rec_error.err_code = 'H9320' THEN
        l_fahrplan_err_text := 'The input is incorrect or incomplete';
      ELSIF l_rec_error.err_code = 'H9300' THEN
        l_fahrplan_err_text := 'Unknown arrival station';
      ELSIF l_rec_error.err_code = 'H9280' THEN
        l_fahrplan_err_text := 'Unknown intermediate station';
      ELSIF l_rec_error.err_code = 'H9260' THEN
        l_fahrplan_err_text := 'Unknown departure station';
      ELSIF l_rec_error.err_code = 'H9250' THEN
        l_fahrplan_err_text := 'Part inquiry interrupted';
      ELSIF l_rec_error.err_code = 'H9240' THEN
        l_fahrplan_err_text := 'Unsuccessful search';
      ELSIF l_rec_error.err_code = 'H9230' THEN
        l_fahrplan_err_text := 'An internal error occurred';
      ELSIF l_rec_error.err_code = 'H9220' THEN
        l_fahrplan_err_text := 'Nearby to the given address stations could not be found';
      ELSIF l_rec_error.err_code = 'H900' THEN
        l_fahrplan_err_text := 'Unsuccessful or incomplete search (timetable change)';
      ELSIF l_rec_error.err_code = 'H892' THEN
        l_fahrplan_err_text := 'Inquiry too complex (try entering less intermediate stations)';
      ELSIF l_rec_error.err_code = 'H891' THEN
        l_fahrplan_err_text := 'No route found (try entering an intermediate station)';
      ELSIF l_rec_error.err_code = 'H890' THEN
        l_fahrplan_err_text := 'Unsuccessful search';
      ELSIF l_rec_error.err_code = 'H500' THEN
        l_fahrplan_err_text := 'Because of too many trains the connection is not complete';
      ELSIF l_rec_error.err_code = 'H460' THEN
        l_fahrplan_err_text := 'One or more stops are passed through multiple times';
      ELSIF l_rec_error.err_code = 'H455' THEN
        l_fahrplan_err_text := 'Prolonged stop';
      ELSIF l_rec_error.err_code = 'H410' THEN
        l_fahrplan_err_text := 'Display may be incomplete due to change of timetable';
      ELSIF l_rec_error.err_code = 'H390' THEN
        l_fahrplan_err_text := 'Departure/Arrival replaced by an equivalent station';
      ELSIF l_rec_error.err_code = 'H895' THEN
        l_fahrplan_err_text := 'Departure/Arrival are too near';
      ELSIF l_rec_error.err_code = 'H899' THEN
        l_fahrplan_err_text := 'Unsuccessful or incomplete search (timetable change)';
        -- Departure and Arrival Board Errors
      ELSIF l_rec_error.err_code = 'SQ001' THEN
        l_fahrplan_err_text := 'No station board available';
      ELSIF l_rec_error.err_code = 'SQ002' THEN
        l_fahrplan_err_text := 'There was no journey found for the requested board or time';
        -- Journey Details Errors
      ELSIF l_rec_error.err_code = 'TI001' THEN
        l_fahrplan_err_text := 'No trip journey information available';
        -- Unknown error
      ELSE
        l_fahrplan_err_text := 'Unknown Fahrplan API error';
      END IF;
      --
      l_error_msg := 'Error-Code: ' || l_rec_error.err_code || chr(10) ||
                     'Error-Description: ' || l_fahrplan_err_text;
      -- Throw error
      IF l_rec_error.err_code IS NOT NULL THEN
        raise_application_error(error_db_fahrplan_code,
                                l_error_msg);
      END IF;
    END IF;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END check_error_fahrplan_api;
  --
  /****************************************************************************
  * Purpose: Set HTTP headers for REST calls
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE set_http_headers IS
    --
    l_user_agent VARCHAR2(100);
    l_server     bahn_fahrplan_api.pub_fahrplan_host%TYPE;
    --
  BEGIN
    -- Clients Envs
    l_user_agent := 'Mozilla/5.0';
    l_server     := bahn_fahrplan_api.pub_fahrplan_host;
    --
    -- set http headers
    -- Host
    apex_web_service.g_request_headers(1).name := 'Host';
    apex_web_service.g_request_headers(1).value := l_server;
    -- User-Agent
    apex_web_service.g_request_headers(2).name := 'User-Agent';
    apex_web_service.g_request_headers(2).value := l_user_agent;
    -- Accept
    apex_web_service.g_request_headers(3).name := 'Accept';
    apex_web_service.g_request_headers(3).value := '*/*';
    -- Accept-Charset
    apex_web_service.g_request_headers(4).name := 'Accept-Charset';
    apex_web_service.g_request_headers(4).value := 'UTF-8';
    -- Accept-Encoding
    apex_web_service.g_request_headers(5).name := 'Accept-Encoding';
    apex_web_service.g_request_headers(5).value := 'gzip,deflate';
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END set_http_headers;
  --
  --
  -- REST CALL FUNCTIONS RETURNING JSON
  --
  --
  /****************************************************************************
  * Purpose: Fahrplan Location.name Service REST Call - Search for location and stations
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_location_name_json(i_api_auth_key  IN VARCHAR2,
                                  i_language      IN VARCHAR2 := 'en',
                                  i_search_string IN VARCHAR2) RETURN CLOB IS
    --
    l_response_json CLOB;
    l_url           VARCHAR2(500);
    l_base_url      bahn_fahrplan_api.pub_fahrplan_base_url%TYPE;
    --
  BEGIN
    -- vars
    l_base_url := bahn_fahrplan_api.pub_fahrplan_base_url;
    --
    -- set HTTP header
    bahn_fahrplan_api.set_http_headers;
    --
    -- REST HTTP Request
    -- Build URL
    l_url := l_base_url || '/location.name';
    -- REST call
    -- http
    IF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'http' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET',
                                                            p_parm_name   => apex_util.string_to_table('authKey:lang:input:format'),
                                                            p_parm_value  => apex_util.string_to_table(i_api_auth_key || ':' ||
                                                                                                       i_language || ':' ||
                                                                                                       i_search_string ||
                                                                                                       ':json'));
      -- https
    ELSIF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'https' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET',
                                                            p_parm_name   => apex_util.string_to_table('authKey:lang:input:format'),
                                                            p_parm_value  => apex_util.string_to_table(i_api_auth_key || ':' ||
                                                                                                       i_language || ':' ||
                                                                                                       i_search_string ||
                                                                                                       ':json'),
                                                            p_wallet_path => bahn_fahrplan_api.pub_ssl_wallet_path,
                                                            p_wallet_pwd  => bahn_fahrplan_api.pub_ssl_wallet_pwd);
    END IF;
    --
    -- check for HTTP errors
    bahn_fahrplan_api.check_error_http_status;
    --
    -- check for fahrplan API errors
    bahn_fahrplan_api.check_error_fahrplan_api(i_response_clob => l_response_json);
    --
    -- return CLOB
    RETURN l_response_json;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_location_name_json;
  --
  /****************************************************************************
  * Purpose: Fahrplan departureBoard Service REST Call - departure board for a
  *          given station (id) and date/time
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_departure_board_json(i_api_auth_key IN VARCHAR2,
                                    i_language     IN VARCHAR2 := 'en',
                                    i_station_id   IN NUMBER,
                                    i_date_time    IN DATE := NULL)
    RETURN CLOB IS
    --
    l_response_json CLOB;
    l_url           VARCHAR2(500);
    l_base_url      bahn_fahrplan_api.pub_fahrplan_base_url%TYPE;
    l_date          VARCHAR2(50);
    l_time          VARCHAR2(50);
    l_param_name    VARCHAR2(500);
    l_param_value   VARCHAR2(500);
    --
  BEGIN
    -- vars
    l_base_url := bahn_fahrplan_api.pub_fahrplan_base_url;
    -- build date/time strings
    IF i_date_time IS NOT NULL THEN
      l_date := to_char(i_date_time,
                        'YYYY-MM-DD');
      l_time := to_char(i_date_time,
                        'HH24:MI');
      -- if time is 00:00 without time only date
      IF l_time = '00:00' THEN
        l_param_name  := 'authKey:lang:id:date:format';
        l_param_value := i_api_auth_key || ':' || i_language || ':' ||
                         i_station_id || ':' || l_date || ':json';
        -- with date and time
      ELSE
        l_param_name  := 'authKey:lang:id:date:time:format';
        l_param_value := i_api_auth_key || ':' || i_language || ':' ||
                         i_station_id || ':' || l_date || ':' ||
                         apex_util.url_encode(l_time) || ':json';
      END IF;
      -- without date and time
    ELSE
      l_param_name  := 'authKey:lang:id:format';
      l_param_value := i_api_auth_key || ':' || i_language || ':' ||
                       i_station_id || ':json';
    END IF;
    --
    -- set HTTP header
    bahn_fahrplan_api.set_http_headers;
    --
    -- REST HTTP Request
    -- Build URL
    l_url := l_base_url || '/departureBoard';
    -- REST call
    -- http
    IF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'http' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET',
                                                            p_parm_name   => apex_util.string_to_table(l_param_name),
                                                            p_parm_value  => apex_util.string_to_table(l_param_value));
      -- https
    ELSIF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'https' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET',
                                                            p_parm_name   => apex_util.string_to_table(l_param_name),
                                                            p_parm_value  => apex_util.string_to_table(l_param_value),
                                                            p_wallet_path => bahn_fahrplan_api.pub_ssl_wallet_path,
                                                            p_wallet_pwd  => bahn_fahrplan_api.pub_ssl_wallet_pwd);
    END IF;
    --
    -- check for HTTP errors
    bahn_fahrplan_api.check_error_http_status;
    --
    -- check for fahrplan API errors
    bahn_fahrplan_api.check_error_fahrplan_api(i_response_clob => l_response_json);
    --
    -- return CLOB
    RETURN l_response_json;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_departure_board_json;
  --
  /****************************************************************************
  * Purpose: Fahrplan arrivalBoard Service REST Call - arrival board for a
  *          given station (id) and date/time
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_arrival_board_json(i_api_auth_key IN VARCHAR2,
                                  i_language     IN VARCHAR2 := 'en',
                                  i_station_id   IN NUMBER,
                                  i_date_time    IN DATE := NULL) RETURN CLOB IS
    --
    l_response_json CLOB;
    l_url           VARCHAR2(500);
    l_base_url      bahn_fahrplan_api.pub_fahrplan_base_url%TYPE;
    l_date          VARCHAR2(50);
    l_time          VARCHAR2(50);
    l_param_name    VARCHAR2(500);
    l_param_value   VARCHAR2(500);
    --
  BEGIN
    -- vars
    l_base_url := bahn_fahrplan_api.pub_fahrplan_base_url;
    -- build date/time strings
    IF i_date_time IS NOT NULL THEN
      l_date := to_char(i_date_time,
                        'YYYY-MM-DD');
      l_time := to_char(i_date_time,
                        'HH24:MI');
      -- if time is 00:00 without time only date
      IF l_time = '00:00' THEN
        l_param_name  := 'authKey:lang:id:date:format';
        l_param_value := i_api_auth_key || ':' || i_language || ':' ||
                         i_station_id || ':' || l_date || ':json';
        -- with date and time
      ELSE
        l_param_name  := 'authKey:lang:id:date:time:format';
        l_param_value := i_api_auth_key || ':' || i_language || ':' ||
                         i_station_id || ':' || l_date || ':' ||
                         apex_util.url_encode(l_time) || ':json';
      END IF;
      -- without date and time
    ELSE
      l_param_name  := 'authKey:lang:id:format';
      l_param_value := i_api_auth_key || ':' || i_language || ':' ||
                       i_station_id || ':json';
    END IF;
    --
    -- set HTTP header
    bahn_fahrplan_api.set_http_headers;
    --
    -- REST HTTP Request
    -- Build URL
    l_url := l_base_url || '/arrivalBoard';
    -- REST call
    -- http
    IF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'http' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET',
                                                            p_parm_name   => apex_util.string_to_table(l_param_name),
                                                            p_parm_value  => apex_util.string_to_table(l_param_value));
      -- https
    ELSIF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'https' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET',
                                                            p_parm_name   => apex_util.string_to_table(l_param_name),
                                                            p_parm_value  => apex_util.string_to_table(l_param_value),
                                                            p_wallet_path => bahn_fahrplan_api.pub_ssl_wallet_path,
                                                            p_wallet_pwd  => bahn_fahrplan_api.pub_ssl_wallet_pwd);
    END IF;
    --
    -- check for HTTP errors
    bahn_fahrplan_api.check_error_http_status;
    --
    -- check for fahrplan API errors
    bahn_fahrplan_api.check_error_fahrplan_api(i_response_clob => l_response_json);
    --
    -- return CLOB
    RETURN l_response_json;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_arrival_board_json;
  /****************************************************************************
  * Purpose: Fahrplan journeyDetail Service REST Call - information about the complete route of a vehicle
  *          Gets journeydetailref URL from departure or arrival board
  * Author:  Daniel Hochleitner
  * Created: 27.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_journey_detail_json(i_journeydetailref_url IN VARCHAR2)
    RETURN CLOB IS
    --
    l_response_json CLOB;
    l_url           VARCHAR2(500);
    --
  BEGIN
    --
    -- set HTTP header
    bahn_fahrplan_api.set_http_headers;
    --
    -- REST HTTP Request
    -- Build URL
    l_url := i_journeydetailref_url;
    -- REST call
    -- http
    IF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'http' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET');
      -- https
    ELSIF bahn_fahrplan_api.pub_fahrplan_rest_proto = 'https' THEN
      l_response_json := apex_web_service.make_rest_request(p_url         => l_url,
                                                            p_http_method => 'GET',
                                                            p_wallet_path => bahn_fahrplan_api.pub_ssl_wallet_path,
                                                            p_wallet_pwd  => bahn_fahrplan_api.pub_ssl_wallet_pwd);
    END IF;
    --
    -- check for HTTP errors
    bahn_fahrplan_api.check_error_http_status;
    --
    -- check for fahrplan API errors
    bahn_fahrplan_api.check_error_fahrplan_api(i_response_clob => l_response_json);
    --
    -- return CLOB
    RETURN l_response_json;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_journey_detail_json;
  --
  --
  -- APEX COLLECTION FUNCTIONS
  --
  --
  /****************************************************************************
  * Purpose: Fahrplan Location.name stations (StopLocation) inserted in APEX Collection
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE get_location_stations_apex(i_api_auth_key   IN VARCHAR2,
                                       i_language       IN VARCHAR2 := 'en',
                                       i_search_string  IN VARCHAR2,
                                       i_apex_coll_name IN VARCHAR2 := 'STATIONS') IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    -- cursor xmltable auf json
    CURSOR l_cur_stations IS
      SELECT station_name,
             station_id,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/StopLocation/row' passing
                      l_response_xml columns station_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      station_id path 'id')
       WHERE station_name IS NOT NULL
      UNION ALL
      SELECT station_name,
             station_id,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/StopLocation' passing
                      l_response_xml columns station_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      station_id path 'id')
       WHERE station_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_location_name_json(i_api_auth_key  => i_api_auth_key,
                                                                i_language      => i_language,
                                                                i_search_string => i_search_string);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- create collection
    apex_collection.create_or_truncate_collection(p_collection_name => i_apex_coll_name);
    --
    -- loop over cursor and create apex collection
    FOR l_rec_stations IN l_cur_stations LOOP
      -- add collection members
      apex_collection.add_member(p_collection_name => i_apex_coll_name,
                                 p_c001            => l_rec_stations.station_name,
                                 p_c002            => l_rec_stations.station_id,
                                 p_c003            => l_rec_stations.longitude,
                                 p_c004            => l_rec_stations.latitude);
    END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_location_stations_apex;
  --
  /****************************************************************************
  * Purpose: Fahrplan Location.name other locations (CoordLocation) inserted in APEX Collection
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE get_location_otherloc_apex(i_api_auth_key   IN VARCHAR2,
                                       i_language       IN VARCHAR2 := 'en',
                                       i_search_string  IN VARCHAR2,
                                       i_apex_coll_name IN VARCHAR2 := 'LOCATIONS') IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    -- cursor xmltable auf json
    CURSOR l_cur_locations IS
      SELECT loc_name,
             loc_type,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/CoordLocation/row' passing
                      l_response_xml columns loc_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      loc_type path 'type')
       WHERE loc_name IS NOT NULL
      UNION ALL
      SELECT loc_name,
             loc_type,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/CoordLocation' passing
                      l_response_xml columns loc_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      loc_type path 'type')
       WHERE loc_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_location_name_json(i_api_auth_key  => i_api_auth_key,
                                                                i_language      => i_language,
                                                                i_search_string => i_search_string);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- create collection
    apex_collection.create_or_truncate_collection(p_collection_name => i_apex_coll_name);
    --
    -- loop over cursor and create apex collection
    FOR l_rec_locations IN l_cur_locations LOOP
      -- add collection members
      apex_collection.add_member(p_collection_name => i_apex_coll_name,
                                 p_c001            => l_rec_locations.loc_name,
                                 p_c002            => l_rec_locations.loc_type,
                                 p_c003            => l_rec_locations.longitude,
                                 p_c004            => l_rec_locations.latitude);
    END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_location_otherloc_apex;
  --
  /****************************************************************************
  * Purpose: Fahrplan departureBoard inserted in APEX Collection
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE get_departure_board_apex(i_api_auth_key   IN VARCHAR2,
                                     i_language       IN VARCHAR2 := 'en',
                                     i_station_id     IN NUMBER,
                                     i_date_time      IN DATE := NULL,
                                     i_apex_coll_name IN VARCHAR2 := 'DEPARTURE_BOARD') IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    -- cursor xmltable auf json
    CURSOR l_cur_departure IS
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/DepartureBoard/Departure/row' passing
                      l_response_xml columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL
      UNION ALL
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/DepartureBoard/Departure' passing
                      l_response_xml columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_departure_board_json(i_api_auth_key => i_api_auth_key,
                                                                  i_language     => i_language,
                                                                  i_station_id   => i_station_id,
                                                                  i_date_time    => i_date_time);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- create collection
    apex_collection.create_or_truncate_collection(p_collection_name => i_apex_coll_name);
    --
    -- loop over cursor and create apex collection
    FOR l_rec_departure IN l_cur_departure LOOP
      -- add collection members
      apex_collection.add_member(p_collection_name => i_apex_coll_name,
                                 p_c001            => l_rec_departure.train_name,
                                 p_c002            => l_rec_departure.train_type,
                                 p_c003            => l_rec_departure.stop_id,
                                 p_c004            => l_rec_departure.stop_name,
                                 p_c005            => l_rec_departure.direction,
                                 p_c006            => l_rec_departure.stop_date,
                                 p_c007            => l_rec_departure.stop_time,
                                 p_c008            => l_rec_departure.track,
                                 p_c009            => l_rec_departure.journeydetailref);
    END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_departure_board_apex;
  --
  /****************************************************************************
  * Purpose: Fahrplan ArrivalBoard inserted in APEX Collection
  * Author:  Daniel Hochleitner
  * Created: 26.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE get_arrival_board_apex(i_api_auth_key   IN VARCHAR2,
                                   i_language       IN VARCHAR2 := 'en',
                                   i_station_id     IN NUMBER,
                                   i_date_time      IN DATE := NULL,
                                   i_apex_coll_name IN VARCHAR2 := 'ARRIVAL_BOARD') IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    -- cursor xmltable auf json
    CURSOR l_cur_arrival IS
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/ArrivalBoard/Arrival/row' passing
                      l_response_xml columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL
      UNION ALL
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/ArrivalBoard/Arrival' passing l_response_xml
                      columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_arrival_board_json(i_api_auth_key => i_api_auth_key,
                                                                i_language     => i_language,
                                                                i_station_id   => i_station_id,
                                                                i_date_time    => i_date_time);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- create collection
    apex_collection.create_or_truncate_collection(p_collection_name => i_apex_coll_name);
    --
    -- loop over cursor and create apex collection
    FOR l_rec_arrival IN l_cur_arrival LOOP
      -- add collection members
      apex_collection.add_member(p_collection_name => i_apex_coll_name,
                                 p_c001            => l_rec_arrival.train_name,
                                 p_c002            => l_rec_arrival.train_type,
                                 p_c003            => l_rec_arrival.stop_id,
                                 p_c004            => l_rec_arrival.stop_name,
                                 p_c005            => l_rec_arrival.direction,
                                 p_c006            => l_rec_arrival.stop_date,
                                 p_c007            => l_rec_arrival.stop_time,
                                 p_c008            => l_rec_arrival.track,
                                 p_c009            => l_rec_arrival.journeydetailref);
    END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_arrival_board_apex;
  --
  /****************************************************************************
  * Purpose: Fahrplan journeyDetail Service inserted in APEX Collection
  * Author:  Daniel Hochleitner
  * Created: 27.02.2016
  * Changed:
  ****************************************************************************/
  PROCEDURE get_journey_detail_apex(i_journeydetailref_url IN VARCHAR2,
                                    i_apex_coll_name       IN VARCHAR2 := 'JOURNEY_DETAIL') IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    -- cursor xmltable auf json
    CURSOR l_cur_journey IS
      SELECT station_name,
             station_id,
             longitude,
             latitude,
             nvl(arr_time,
                 dep_time) AS arr_time,
             nvl(arr_date,
                 dep_date) AS arr_date,
             dep_time,
             dep_date,
             track
        FROM xmltable('/json/JourneyDetail/Stops/Stop/row' passing
                      l_response_xml columns station_name path 'name',
                      station_id path 'id',
                      longitude path 'lon',
                      latitude path 'lat',
                      arr_time path 'arrTime',
                      arr_date path 'arrDate',
                      dep_time path 'depTime',
                      dep_date path 'depDate',
                      track path 'track')
       WHERE station_name IS NOT NULL
      UNION ALL
      SELECT station_name,
             station_id,
             longitude,
             latitude,
             nvl(arr_time,
                 dep_time) AS arr_time,
             nvl(arr_date,
                 dep_date) AS arr_date,
             nvl(dep_time,
                 arr_time) AS dep_time,
             nvl(dep_date,
                 arr_date) AS dep_time,
             track
        FROM xmltable('/json/JourneyDetail/Stops/Stop' passing
                      l_response_xml columns station_name path 'name',
                      station_id path 'id',
                      longitude path 'lon',
                      latitude path 'lat',
                      arr_time path 'arrTime',
                      arr_date path 'arrDate',
                      dep_time path 'depTime',
                      dep_date path 'depDate',
                      track path 'track')
       WHERE station_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_journey_detail_json(i_journeydetailref_url => i_journeydetailref_url);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- create collection
    apex_collection.create_or_truncate_collection(p_collection_name => i_apex_coll_name);
    --
    -- loop over cursor and create apex collection
    FOR l_rec_journey IN l_cur_journey LOOP
      -- add collection members
      apex_collection.add_member(p_collection_name => i_apex_coll_name,
                                 p_c001            => l_rec_journey.station_name,
                                 p_c002            => l_rec_journey.station_id,
                                 p_c003            => l_rec_journey.longitude,
                                 p_c004            => l_rec_journey.latitude,
                                 p_c005            => l_rec_journey.arr_time,
                                 p_c006            => l_rec_journey.arr_date,
                                 p_c007            => l_rec_journey.dep_time,
                                 p_c008            => l_rec_journey.dep_date,
                                 p_c009            => l_rec_journey.track);
    END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_journey_detail_apex;
  --
  --
  -- PIPELINED FUNCTIONS
  --
  --
  /****************************************************************************
  * Purpose: Fahrplan Location.name stations (StopLocation) as pipelined function
  * Author:  Daniel Hochleitner
  * Created: 27.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_location_stations_pipe(i_api_auth_key  IN VARCHAR2,
                                      i_language      IN VARCHAR2 := 'en',
                                      i_search_string IN VARCHAR2)
    RETURN bahn_fahrplan_api.t_location_stations_tab
    PIPELINED IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    l_dataset       bahn_fahrplan_api.t_location_stations_tab;
    l_onerow        bahn_fahrplan_api.t_location_stations_rec;
    -- cursor xmltable auf json
    CURSOR l_cur_stations IS
      SELECT station_name,
             station_id,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/StopLocation/row' passing
                      l_response_xml columns station_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      station_id path 'id')
       WHERE station_name IS NOT NULL
      UNION ALL
      SELECT station_name,
             station_id,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/StopLocation' passing
                      l_response_xml columns station_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      station_id path 'id')
       WHERE station_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_location_name_json(i_api_auth_key  => i_api_auth_key,
                                                                i_language      => i_language,
                                                                i_search_string => i_search_string);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- loop over cursor and pipe row
    OPEN l_cur_stations;
    LOOP
      FETCH l_cur_stations BULK COLLECT
        INTO l_dataset;
      EXIT WHEN l_dataset.count = 0;
      -- pipe row
      FOR l_row IN 1 .. l_dataset.count LOOP
        l_onerow := l_dataset(l_row);
        PIPE ROW(l_onerow);
      END LOOP;
      --
    END LOOP;
    CLOSE l_cur_stations;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_location_stations_pipe;
  --
  /****************************************************************************
  * Purpose: Fahrplan Location.name other locations (CoordLocation) as pipelined function
  * Author:  Daniel Hochleitner
  * Created: 27.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_location_otherloc_pipe(i_api_auth_key  IN VARCHAR2,
                                      i_language      IN VARCHAR2 := 'en',
                                      i_search_string IN VARCHAR2)
    RETURN bahn_fahrplan_api.t_location_otherloc_tab
    PIPELINED IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    l_dataset       bahn_fahrplan_api.t_location_otherloc_tab;
    l_onerow        bahn_fahrplan_api.t_location_otherloc_rec;
    -- cursor xmltable auf json
    CURSOR l_cur_locations IS
      SELECT loc_name,
             loc_type,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/CoordLocation/row' passing
                      l_response_xml columns loc_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      loc_type path 'type')
       WHERE loc_name IS NOT NULL
      UNION ALL
      SELECT loc_name,
             loc_type,
             longitude,
             latitude
        FROM xmltable('/json/LocationList/CoordLocation' passing
                      l_response_xml columns loc_name path 'name',
                      longitude path 'lon',
                      latitude path 'lat',
                      loc_type path 'type')
       WHERE loc_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_location_name_json(i_api_auth_key  => i_api_auth_key,
                                                                i_language      => i_language,
                                                                i_search_string => i_search_string);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- loop over cursor and pipe row
    OPEN l_cur_locations;
    LOOP
      FETCH l_cur_locations BULK COLLECT
        INTO l_dataset;
      EXIT WHEN l_dataset.count = 0;
      -- pipe row
      FOR l_row IN 1 .. l_dataset.count LOOP
        l_onerow := l_dataset(l_row);
        PIPE ROW(l_onerow);
      END LOOP;
      --
    END LOOP;
    CLOSE l_cur_locations;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_location_otherloc_pipe;
  --
  /****************************************************************************
  * Purpose: Fahrplan departureBoard as pipelined function
  * Author:  Daniel Hochleitner
  * Created: 27.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_departure_board_pipe(i_api_auth_key IN VARCHAR2,
                                    i_language     IN VARCHAR2 := 'en',
                                    i_station_id   IN NUMBER,
                                    i_date_time    IN DATE := NULL)
    RETURN bahn_fahrplan_api.t_departure_tab
    PIPELINED IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    l_dataset       bahn_fahrplan_api.t_departure_tab;
    l_onerow        bahn_fahrplan_api.t_departure_rec;
    -- cursor xmltable auf json
    CURSOR l_cur_departure IS
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/DepartureBoard/Departure/row' passing
                      l_response_xml columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL
      UNION ALL
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/DepartureBoard/Departure' passing
                      l_response_xml columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_departure_board_json(i_api_auth_key => i_api_auth_key,
                                                                  i_language     => i_language,
                                                                  i_station_id   => i_station_id,
                                                                  i_date_time    => i_date_time);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- loop over cursor and pipe row
    OPEN l_cur_departure;
    LOOP
      FETCH l_cur_departure BULK COLLECT
        INTO l_dataset;
      EXIT WHEN l_dataset.count = 0;
      -- pipe row
      FOR l_row IN 1 .. l_dataset.count LOOP
        l_onerow := l_dataset(l_row);
        PIPE ROW(l_onerow);
      END LOOP;
      --
    END LOOP;
    CLOSE l_cur_departure;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_departure_board_pipe;
  --
  /****************************************************************************
  * Purpose: Fahrplan ArrivalBoard as pipelined function
  * Author:  Daniel Hochleitner
  * Created: 27.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_arrival_board_pipe(i_api_auth_key IN VARCHAR2,
                                  i_language     IN VARCHAR2 := 'en',
                                  i_station_id   IN NUMBER,
                                  i_date_time    IN DATE := NULL)
    RETURN bahn_fahrplan_api.t_arrival_tab
    PIPELINED IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    l_dataset       bahn_fahrplan_api.t_arrival_tab;
    l_onerow        bahn_fahrplan_api.t_arrival_rec;
    -- cursor xmltable auf json
    CURSOR l_cur_arrival IS
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/ArrivalBoard/Arrival/row' passing
                      l_response_xml columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL
      UNION ALL
      SELECT train_name,
             train_type,
             stop_id,
             stop_name,
             stop_time,
             stop_date,
             direction,
             track,
             journeydetailref
        FROM xmltable('/json/ArrivalBoard/Arrival' passing l_response_xml
                      columns train_name path 'name',
                      train_type path 'type',
                      stop_id path 'stopid',
                      stop_name path 'stop',
                      stop_time path 'time',
                      stop_date path 'date',
                      direction path 'direction',
                      track path 'track',
                      journeydetailref path 'JourneyDetailRef/ref')
       WHERE train_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_arrival_board_json(i_api_auth_key => i_api_auth_key,
                                                                i_language     => i_language,
                                                                i_station_id   => i_station_id,
                                                                i_date_time    => i_date_time);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- loop over cursor and pipe row
    OPEN l_cur_arrival;
    LOOP
      FETCH l_cur_arrival BULK COLLECT
        INTO l_dataset;
      EXIT WHEN l_dataset.count = 0;
      -- pipe row
      FOR l_row IN 1 .. l_dataset.count LOOP
        l_onerow := l_dataset(l_row);
        PIPE ROW(l_onerow);
      END LOOP;
      --
    END LOOP;
    CLOSE l_cur_arrival;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_arrival_board_pipe;
  --
  /****************************************************************************
  * Purpose: Fahrplan journeyDetail Service as pipelined function
  * Author:  Daniel Hochleitner
  * Created: 27.02.2016
  * Changed:
  ****************************************************************************/
  FUNCTION get_journey_detail_pipe(i_journeydetailref_url IN VARCHAR2)
    RETURN bahn_fahrplan_api.t_journey_tab
    PIPELINED IS
    --
    l_response_json CLOB;
    l_response_xml  xmltype;
    l_dataset       bahn_fahrplan_api.t_journey_tab;
    l_onerow        bahn_fahrplan_api.t_journey_rec;
    -- cursor xmltable auf json
    CURSOR l_cur_journey IS
      SELECT station_name,
             station_id,
             longitude,
             latitude,
             nvl(arr_time,
                 dep_time) AS arr_time,
             nvl(arr_date,
                 dep_date) AS arr_date,
             nvl(dep_time,
                 arr_time) AS dep_time,
             nvl(dep_date,
                 arr_date) AS dep_time,
             track
        FROM xmltable('/json/JourneyDetail/Stops/Stop/row' passing
                      l_response_xml columns station_name path 'name',
                      station_id path 'id',
                      longitude path 'lon',
                      latitude path 'lat',
                      arr_time path 'arrTime',
                      arr_date path 'arrDate',
                      dep_time path 'depTime',
                      dep_date path 'depDate',
                      track path 'track')
       WHERE station_name IS NOT NULL
      UNION ALL
      SELECT station_name,
             station_id,
             longitude,
             latitude,
             nvl(arr_time,
                 dep_time) AS arr_time,
             nvl(arr_date,
                 dep_date) AS arr_date,
             dep_time,
             dep_date,
             track
        FROM xmltable('/json/JourneyDetail/Stops/Stop' passing
                      l_response_xml columns station_name path 'name',
                      station_id path 'id',
                      longitude path 'lon',
                      latitude path 'lat',
                      arr_time path 'arrTime',
                      arr_date path 'arrDate',
                      dep_time path 'depTime',
                      dep_date path 'depDate',
                      track path 'track')
       WHERE station_name IS NOT NULL;
    --
  BEGIN
    -- get json from rest call
    l_response_json := bahn_fahrplan_api.get_journey_detail_json(i_journeydetailref_url => i_journeydetailref_url);
    -- json to xml
    l_response_xml := apex_json.to_xmltype(l_response_json);
    --
    -- loop over cursor and pipe row
    OPEN l_cur_journey;
    LOOP
      FETCH l_cur_journey BULK COLLECT
        INTO l_dataset;
      EXIT WHEN l_dataset.count = 0;
      -- pipe row
      FOR l_row IN 1 .. l_dataset.count LOOP
        l_onerow := l_dataset(l_row);
        PIPE ROW(l_onerow);
      END LOOP;
      --
    END LOOP;
    CLOSE l_cur_journey;
    --
  EXCEPTION
    WHEN OTHERS THEN
      -- Insert your own exception handling here
      NULL;
      RAISE;
  END get_journey_detail_pipe;
  --
--
END bahn_fahrplan_api;
/
