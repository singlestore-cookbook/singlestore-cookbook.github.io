1. Top 10 Longest Connections (by distance)

SELECT
    from_station,
    to_station,
    tube_line,
    ROUND(distance, 2) AS distance_km
FROM london_tube_edges
ORDER BY distance DESC
LIMIT 10;

+----------------------+----------------------+--------------+-------------+
| from_station         | to_station           | tube_line    | distance_km |
+----------------------+----------------------+--------------+-------------+
| Finchley Road        | Wembley Park         | Metropolitan |        7.11 |
| Chalfont and Latimer | Chesham              | Metropolitan |        5.43 |
| East Finchley        | Mill Hill East       | Northern     |        3.90 |
| Rickmansworth        | Chorleywood          | Metropolitan |        3.46 |
| Chorleywood          | Chalfont and Latimer | Metropolitan |        3.32 |
| Theydon Bois         | Debden               | Central      |        3.29 |
| Chalfont and Latimer | Amersham             | Metropolitan |        3.22 |
| Seven Sisters        | Finsbury Park        | Victoria     |        3.12 |
| Baker Street         | Finchley Road        | Metropolitan |        3.11 |
| Moor Park            | Rickmansworth        | Metropolitan |        3.05 |
+----------------------+----------------------+--------------+-------------+

2. All stations served by a specific line

SELECT DISTINCT from_station AS station
FROM london_tube_edges
WHERE tube_line = 'Northern'
UNION
SELECT DISTINCT to_station
FROM london_tube_edges
WHERE tube_line = 'Northern'
ORDER BY 1;

+--------------------------+
| station                  |
+--------------------------+
| Angel                    |
| Borough                  |
| Kentish Town             |
| Belsize Park             |
| Hendon Central           |
| Highgate                 |
| Euston                   |
| Mornington Crescent      |
| Tottenham Court Road     |
| East Finchley            |
| Goodge Street            |
| Camden Town              |
| Embankment               |
| Woodside Park            |
| Waterloo                 |
| Colindale                |
| Oval                     |
| Clapham South            |
| Tufnell Park             |
| Tooting Bec              |
| Kennington               |
| London Bridge            |
| Bank                     |
| Clapham Common           |
| Chalk Farm               |
| South Wimbledon          |
| Tooting Broadway         |
| Kings Cross St. Pancras  |
| Hampstead                |
| Colliers Wood            |
| Leicester Square         |
| Stockwell                |
| Clapham North            |
| Finchley Central         |
| West Finchley            |
| Totteridge and Whetstone |
| Warren Street            |
| Burnt Oak                |
| Charing Cross            |
| Nine Elms                |
| Old Street               |
| Balham                   |
| Elephant and Castle      |
| Archway                  |
| Brent Cross              |
| Morden                   |
| Moorgate                 |
| Golders Green            |
| Battersea Power Station  |
| Edgware                  |
| High Barnet              |
| Mill Hill East           |
+--------------------------+

3. Count of stations per line

SELECT
    tube_line,
    COUNT(DISTINCT from_station) + COUNT(DISTINCT to_station) AS total_stations
FROM london_tube_edges
GROUP BY tube_line
ORDER BY total_stations DESC;

+----------------------+----------------+
| tube_line            | total_stations |
+----------------------+----------------+
| District             |            114 |
| Piccadilly           |            100 |
| Northern             |             99 |
| Central              |             94 |
| DLR                  |             84 |
| Tramlink             |             74 |
| Circle               |             69 |
| Metropolitan         |             61 |
| Hammersmith and City |             56 |
| Jubilee              |             52 |
| Bakerloo             |             48 |
| Victoria             |             30 |
| Waterloo and City    |              2 |
+----------------------+----------------+

4. Total distance covered by each tube line

SELECT
    tube_line,
    ROUND(SUM(distance), 2) AS total_distance_km
FROM london_tube_edges
GROUP BY tube_line
ORDER BY total_distance_km DESC;

+----------------------+-------------------+
| tube_line            | total_distance_km |
+----------------------+-------------------+
| Central              |             70.21 |
| Piccadilly           |             68.81 |
| Metropolitan         |             63.84 |
| Northern             |             62.14 |
| District             |             61.52 |
| Jubilee              |             34.57 |
| DLR                  |             33.67 |
| Tramlink             |             26.61 |
| Circle               |             26.01 |
| Hammersmith and City |             25.18 |
| Bakerloo             |             22.97 |
| Victoria             |             20.20 |
| Waterloo and City    |              2.03 |
+----------------------+-------------------+

5. All direct connections from a selected station

SELECT
    from_station,
    to_station,
    tube_line,
    ROUND(distance, 2) AS distance_km
FROM london_tube_edges
WHERE from_station = 'Oxford Circus'
UNION
SELECT
    to_station AS from_station,
    from_station AS to_station,
    tube_line,
    ROUND(distance, 2) AS distance_km
FROM london_tube_edges
WHERE to_station = 'Oxford Circus';

+---------------+----------------------+-----------+-------------+
| from_station  | to_station           | tube_line | distance_km |
+---------------+----------------------+-----------+-------------+
| Oxford Circus | Piccadilly Circus    | Bakerloo  |        0.79 |
| Oxford Circus | Bond Street          | Central   |        0.63 |
| Oxford Circus | Regents Park         | Bakerloo  |        1.01 |
| Oxford Circus | Warren Street        | Victoria  |        1.06 |
| Oxford Circus | Green Park           | Victoria  |        0.95 |
| Oxford Circus | Tottenham Court Road | Central   |        0.68 |
+---------------+----------------------+-----------+-------------+

6. Average distance per connection on each line

SELECT
    tube_line,
    ROUND(AVG(distance), 2) AS avg_distance_km,
    COUNT(*) AS connections
FROM london_tube_edges
GROUP BY tube_line
ORDER BY avg_distance_km DESC;

+----------------------+-----------------+-------------+
| tube_line            | avg_distance_km | connections |
+----------------------+-----------------+-------------+
| Waterloo and City    |            2.03 |           1 |
| Metropolitan         |            2.00 |          32 |
| Central              |            1.46 |          48 |
| Victoria             |            1.35 |          15 |
| Jubilee              |            1.33 |          26 |
| Piccadilly           |            1.30 |          53 |
| Northern             |            1.17 |          53 |
| District             |            1.04 |          59 |
| Bakerloo             |            0.96 |          24 |
| Hammersmith and City |            0.90 |          28 |
| DLR                  |            0.75 |          45 |
| Circle               |            0.74 |          35 |
| Tramlink             |            0.68 |          39 |
+----------------------+-----------------+-------------+

7. List of zone transitions (e.g., Zone 1 to Zone 2)

SELECT
    from_zone,
    to_zone,
    COUNT(*) AS num_connections
FROM london_tube_edges
GROUP BY from_zone, to_zone
ORDER BY num_connections DESC;

+-----------+---------+-----------------+
| from_zone | to_zone | num_connections |
+-----------+---------+-----------------+
| 1         | 1       |             116 |
| 2         | 2       |              75 |
| 3         | 3       |              48 |
| 4         | 4       |              30 |
| 3,4,5,6   | 3,4,5,6 |              27 |
| 6         | 6       |              17 |
| 2         | 1       |              12 |
| 5         | 5       |              12 |
| 1         | 1,2     |               7 |
| 2,3       | 3       |               7 |
| 2         | 2,3     |               7 |
| 1,2       | 2       |               6 |
| 3         | 4       |               6 |
| 5         | 4       |               6 |
| 4         | 5       |               5 |
| 1         | 2       |               5 |
| 2,3       | 2       |               5 |
| 3         | 2,3     |               5 |
| 5         | 6       |               4 |
| 3,4       | 3       |               4 |
| 3,4,5,6   | 4       |               4 |
| 2         | 3       |               4 |
| 4         | 3,4     |               4 |
| 1,2       | 1       |               4 |
| 3,4       | 4       |               4 |
| 2,3       | 2,3     |               3 |
| 3         | 3,4     |               3 |
| 5         | 3,4,5,6 |               3 |
| 3         | 2       |               3 |
| 4         | 3,4,5,6 |               2 |
| 6,7       | 7       |               2 |
| 6         | 5       |               2 |
| 4         | 3       |               2 |
| 7         | 7       |               2 |
| 3,4,5,6   | 5       |               2 |
| 8         | 9       |               2 |
| 5,6       | 6       |               2 |
| 7         | 8       |               1 |
| 3         | 3,4,5,6 |               1 |
| 2         | 4       |               1 |
| 5         | 5,6     |               1 |
| 2         | 1,2     |               1 |
| 6         | 6,7     |               1 |
+-----------+---------+-----------------+

8. Check for duplicate entries (e.g., both A→B and B→A)

SELECT
    a.from_station,
    a.to_station,
    a.tube_line
FROM london_tube_edges a
JOIN london_tube_edges b
  ON a.from_station = b.to_station 
  AND a.to_station = b.from_station 
  AND a.tube_line = b.tube_line
WHERE a.from_station < a.to_station;

Empty set

9. Find the Station with the Most Line Connections

SELECT station, COUNT(DISTINCT tube_line) AS line_count
FROM (
    SELECT from_station AS station, tube_line FROM london_tube_edges
    UNION ALL
    SELECT to_station AS station, tube_line FROM london_tube_edges
) AS all_stations
GROUP BY station
ORDER BY line_count DESC
LIMIT 10;

+-------------------------+------------+
| station                 | line_count |
+-------------------------+------------+
| Kings Cross St. Pancras |          6 |
| Baker Street            |          5 |
| Bank                    |          4 |
| Embankment              |          4 |
| West Ham                |          4 |
| Waterloo                |          4 |
| Liverpool Street        |          4 |
| Paddington              |          4 |
| Moorgate                |          4 |
| Green Park              |          3 |
+-------------------------+------------+

10. Longest Connections (by distance)

SELECT tube_line, from_station, to_station, distance
FROM london_tube_edges
ORDER BY distance DESC
LIMIT 10;

+--------------+----------------------+----------------------+--------------------+
| tube_line    | from_station         | to_station           | distance           |
+--------------+----------------------+----------------------+--------------------+
| Metropolitan | Finchley Road        | Wembley Park         |  7.112540176916028 |
| Metropolitan | Chalfont and Latimer | Chesham              |  5.432568164343399 |
| Northern     | East Finchley        | Mill Hill East       | 3.9037364949623092 |
| Metropolitan | Rickmansworth        | Chorleywood          | 3.4579609486264244 |
| Metropolitan | Chorleywood          | Chalfont and Latimer |  3.323760083821705 |
| Central      | Theydon Bois         | Debden               | 3.2877671535869935 |
| Metropolitan | Chalfont and Latimer | Amersham             | 3.2192760159993528 |
| Victoria     | Seven Sisters        | Finsbury Park        | 3.1156999766523867 |
| Metropolitan | Baker Street         | Finchley Road        | 3.1128045618557203 |
| Metropolitan | Moor Park            | Rickmansworth        | 3.0504444569429605 |
+--------------+----------------------+----------------------+--------------------+

11. Count of Connections Per Line

SELECT tube_line, COUNT(*) AS connection_count
FROM london_tube_edges
GROUP BY tube_line
ORDER BY connection_count DESC;

+----------------------+------------------+
| tube_line            | connection_count |
+----------------------+------------------+
| District             |               59 |
| Northern             |               53 |
| Piccadilly           |               53 |
| Central              |               48 |
| DLR                  |               45 |
| Tramlink             |               39 |
| Circle               |               35 |
| Metropolitan         |               32 |
| Hammersmith and City |               28 |
| Jubilee              |               26 |
| Bakerloo             |               24 |
| Victoria             |               15 |
| Waterloo and City    |                1 |
+----------------------+------------------+

12. Zone-wise Station Count

SELECT zone, COUNT(*) AS station_count
FROM (
    SELECT from_zone AS zone FROM london_tube_edges
    UNION ALL
    SELECT to_zone AS zone FROM london_tube_edges
) AS all_zones
GROUP BY zone
ORDER BY station_count DESC;

+---------+---------------+
| zone    | station_count |
+---------+---------------+
| 1       |           260 |
| 2       |           194 |
| 3       |           131 |
| 4       |            94 |
| 3,4,5,6 |            66 |
| 5       |            47 |
| 6       |            43 |
| 2,3     |            30 |
| 1,2     |            18 |
| 3,4     |            15 |
| 7       |             7 |
| 6,7     |             3 |
| 8       |             3 |
| 5,6     |             3 |
| 9       |             2 |
+---------+---------------+

13. List All Stations Served by Multiple Lines

SELECT station
FROM (
    SELECT from_station AS station, tube_line FROM london_tube_edges
    UNION ALL
    SELECT to_station AS station, tube_line FROM london_tube_edges
) AS all_data
GROUP BY station
HAVING COUNT(DISTINCT tube_line) > 1
ORDER BY COUNT(DISTINCT tube_line) DESC;


+-----------------------------------------------------+
| station                                             |
+-----------------------------------------------------+
| Kings Cross St. Pancras                             |
| Baker Street                                        |
| Bank                                                |
| Paddington                                          |
| Embankment                                          |
| Liverpool Street                                    |
| Waterloo                                            |
| West Ham                                            |
| Moorgate                                            |
| Victoria                                            |
| Westminster                                         |
| Farringdon                                          |
| Edgware Road (Circle/District/Hammersmith and City) |
| Green Park                                          |
| Stratford                                           |
| Great Portland Street                               |
| Barbican                                            |
| Euston Square                                       |
| Notting Hill Gate                                   |
| Oxford Circus                                       |
| Gloucester Road                                     |
| South Kensington                                    |
| Elephant and Castle                                 |
| Ealing Broadway                                     |
| Ruislip                                             |
| Canary Wharf                                        |
| Piccadilly Circus                                   |
| St. James's Park                                    |
| Ladbroke Grove                                      |
| London Bridge                                       |
| Mansion House                                       |
| Barons Court                                        |
| Aldgate East                                        |
| Temple                                              |
| Bayswater                                           |
| Bond Street                                         |
| Tower Hill                                          |
| Ealing Common                                       |
| Hillingdon                                          |
| Eastcote                                            |
| Aldgate                                             |
| Holborn                                             |
| Royal Oak                                           |
| Finsbury Park                                       |
| Blackfriars                                         |
| Stepney Green                                       |
| Acton Town                                          |
| Hammersmith (Met.)                                  |
| Barking                                             |
| Canning Town                                        |
| Wembley Park                                        |
| Wood Lane                                           |
| Euston                                              |
| Earls Court                                         |
| East Ham                                            |
| Hammersmith (District)                              |
| Turnham Green                                       |
| Mile End                                            |
| Ruislip Manor                                       |
| Bow Church                                          |
| Stockwell                                           |
| Leicester Square                                    |
| Wimbledon                                           |
| Latimer Road                                        |
| Monument                                            |
| Finchley Road                                       |
| High Street Kensington                              |
| Cannon Street                                       |
| Charing Cross                                       |
| Westbourne Park                                     |
| Bromley-by-Bow                                      |
| Shepherds Bush Market                               |
| Whitechapel                                         |
| Ickenham                                            |
| Tottenham Court Road                                |
| Sloane Square                                       |
| Bow Road                                            |
| Plaistow                                            |
| Warren Street                                       |
| Goldhawk Road                                       |
| Uxbridge                                            |
| Upton Park                                          |
+-----------------------------------------------------+
