import osmnx as ox
import numpy as np
from shapely.geometry import Polygon, LineString
from shapely import wkt
from toolz.curried import *
from typing import Tuple
from gcjwgs import wgs2gcj
import os, sys, re


## (min_lon, max_lon, min_lat, max_lat)
bounds = {
    "harbin": (126.506130, 126.771862, 45.657920, 45.830905),
    "chengdu": (104.038, 104.128, 30.654, 30.731),
    "porto": (-8.7015, -8.5302, 40.0990, 41.2082)
}

def wktlinestring2lonlat(gps_wkt: str) -> Tuple[np.array, np.array]:
    points = pipe(re.search(r"LINESTRING\s?\((.*?)\)", gps_wkt).group(1), 
                  lambda x: re.split(", | |,", x), 
                  map(float), list)
    return np.asarray(points[0::2]), np.asarray(points[1::2])

def lonlat2wktlinestring(lon: np.array, lat: np.array) -> str:
    gpsstr = pipe([f"{x} {y}" for x, y in zip(lon, lat)], lambda xs: ", ".join(xs))
    return "LINESTRING(" + gpsstr + ")"

def wktlinestring_wgs2gcj(gps_wkt: str) -> str:
    lon_wgs, lat_wgs = wktlinestring2lonlat(gps_wkt)
    lat_gcj, lon_gcj = list(zip(*map(wgs2gcj, lat_wgs, lon_wgs)))
    return lonlat2wktlinestring(np.asarray(lon_gcj), np.asarray(lat_gcj))


def shapelylinestring_wgs2gcj(linestr: LineString) -> LineString:
    wgs_wkt = linestr.to_wkt()
    lon_wgs, lat_wgs = wktlinestring2lonlat(wgs_wkt)
    lat_gcj, lon_gcj = list(zip(*map(wgs2gcj, lat_wgs, lon_wgs)))
    return LineString([[x, y] for (x, y) in zip(lon_gcj, lat_gcj)])

def save_shapefile(G, dirpath: str, to_gcj=False):
    nodes_file = os.path.join(dirpath, "nodes.shp")
    edges_file = os.path.join(dirpath, "edges.shp")

    gdf_nodes, gdf_edges = ox.utils_graph.graph_to_gdfs(G)
    gdf_nodes = ox.io._stringify_nonnumeric_cols(gdf_nodes)
    gdf_edges = ox.io._stringify_nonnumeric_cols(gdf_edges)
    ## Add edge id for fmm
    gdf_edges["fid"] = np.arange(0, gdf_edges.shape[0])
    if to_gcj: gdf_edges.geometry = gdf_edges.geometry.map(shapelylinestring_wgs2gcj)
    print(f"{gdf_edges.shape[0]} edges to be saved.")
    gdf_nodes.to_file(nodes_file, encoding="utf-8")
    gdf_edges.to_file(edges_file, encoding="utf-8")

if __name__ == '__main__':
    assert len(sys.argv) > 1, "Please provide the city name like, python osm_map.py harbin"
    city = sys.argv[1]
    assert city in bounds.keys(), f"Not found city {city} in bounds"
    datadir = f"../data/cities/{city}"
    if not os.path.exists(datadir):
        os.makedirs(datadir)
    # chengdu and xian datasets use gcj coordinate system but julia will transform gcj to 
    # wgs in the client side, so it is unnecessary to transform road geometry to gcj here
    # to_gcj = city in ['chengdu', 'xian']
    to_gcj = False 
    if to_gcj == True:
        print("The osm data will use gcj coordinate.")
    else:
        print("The osm data will use wgs coordinate.")

    x1, x2, y1, y2 = bounds[city]
    boundary_polygon = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])
    G = ox.graph_from_polygon(boundary_polygon, network_type='drive')
    save_shapefile(G, datadir, to_gcj)
    print(f"osm data is saved in {datadir}")
