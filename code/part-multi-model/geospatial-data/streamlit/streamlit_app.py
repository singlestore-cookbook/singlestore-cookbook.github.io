# streamlit_app.py

import streamlit as st
import folium
import networkx as nx
import pandas as pd
from streamlit_folium import st_folium

# Initialize SingleStore connection.
conn = st.connection("singlestore", type = "sql")

# Load london_tube_edges
query = "SELECT * FROM london_tube_edges"
edges_df = conn.query(query)

# Combine all stations from from_station and to_station
stations = sorted(set(edges_df["from_station"]) | set(edges_df["to_station"]))

# Sidebar station selectors
st.sidebar.subheader("Select your journey")
from_station = st.sidebar.selectbox("From", stations)
to_station = st.sidebar.selectbox("To", stations)

st.subheader("Shortest Path Between Stations")

# Build the graph using networkx
G = nx.Graph()
for _, row in edges_df.iterrows():
    G.add_edge(
        row["from_station"],
        row["to_station"],
        weight = row["distance"],
        tube_line = row["tube_line"],
        color = row["color"]
    )

# Build station coordinates lookup
station_coords = {}
for _, row in edges_df.iterrows():
    station_coords[row["from_station"]] = (row["from_latitude"], row["from_longitude"])
    station_coords[row["to_station"]] = (row["to_latitude"], row["to_longitude"])

# Calculate and display the shortest path
try:
    shortest_path = nx.shortest_path(G, source = from_station, target = to_station, weight = "weight")
    
    # Prepare for path
    path_coords = []
    for station in shortest_path:
        lat, lon = station_coords[station]
        path_coords.append({"station": station, "latitude": lat, "longitude": lon})
    path_df = pd.DataFrame(path_coords)

    # Initialize folium map
    m = folium.Map(location = station_coords[from_station], zoom_start = 13)

    # Adjust zoom to fit all points
    sw = path_df[["latitude", "longitude"]].min().values.tolist()
    ne = path_df[["latitude", "longitude"]].max().values.tolist()
    m.fit_bounds([sw, ne])

    # Plot edges between path stations
    for i in range(len(shortest_path) - 1):
        s1 = shortest_path[i]
        s2 = shortest_path[i + 1]
        coord1 = station_coords[s1]
        coord2 = station_coords[s2]

        edge_data = G.get_edge_data(s1, s2)
        color = edge_data.get("color", "blue") if edge_data else "blue"

        folium.PolyLine(
            locations = [coord1, coord2],
            color = color,
            weight = 5,
            opacity = 0.8
        ).add_to(m)

    # Add markers
    for i, row in path_df.iterrows():
        if row["station"] == from_station:
            folium.Marker(
                location = [row["latitude"], row["longitude"]],
                popup = f"Start: {row['station']}",
                icon = folium.Icon(color = "green")
            ).add_to(m)
        elif row["station"] == to_station:
            folium.Marker(
                location = [row["latitude"], row["longitude"]],
                popup = f"End: {row['station']}",
                icon = folium.Icon(color = "red")
            ).add_to(m)
        else:
            folium.Marker(
                location = [row["latitude"], row["longitude"]],
                popup = row["station"],
                icon = folium.Icon(icon = "train", prefix = "fa", color = "gray")
            ).add_to(m)

    # Display the map
    st_folium(m, width = 725)

    # Show journey steps
    st.sidebar.write("Your Journey", path_df["station"])

except nx.NetworkXNoPath:
    st.error("No path found between the selected stations.")
