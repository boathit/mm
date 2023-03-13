from bokeh.plotting import figure
import datashader, shapely
from bokeh.tile_providers import STAMEN_TERRAIN, STAMEN_TONER_BACKGROUND, get_provider
from bokeh.models import Range1d, WMTSTileSource, ColumnDataSource, HoverTool
from networkx import MultiDiGraph
from geopandas import GeoDataFrame
from typing import List, Optional
import numpy as np
import osmnx as ox


tile_provider = get_provider(STAMEN_TERRAIN)

def plot_gps(lon: np.array, lat: np.array, line_width=0.1):
    plot_width  = int(600)
    plot_height = int(plot_width//1.2)
    x, y = datashader.utils.lnglat_to_meters(lon, lat)
    x_range = Range1d(start=x.min()-200, end=x.max()+200, bounds=None)
    y_range = Range1d(start=y.min()-200, end=y.max()+200, bounds=None)
    p = figure(tools='wheel_zoom,pan,reset,hover,save', x_range=x_range, y_range=y_range,
               plot_width=plot_width, plot_height=plot_height)
    p.add_tile(tile_provider)
    
    p.line(x=x, y=y, line_width=line_width)
    p.circle(x=x, y=y, size=5, fill_color="#F46B42", line_color=None, line_width=1.5)
    return p

def wktlinestring2lonlat(wktstr: str):
    coords = np.array(shapely.wkt.loads(wktstr).coords)
    lon, lat = coords[:, 0], coords[:, 1]
    return lon, lat

def plot_wktlinestr(wktstr: str, line_width=0.1):
    lon, lat = wktlinestring2lonlat(wktstr)
    return plot_gps(lon, lat, line_width)

def plot_cpath_ox(G: MultiDiGraph, nodes: GeoDataFrame, edges: GeoDataFrame, cpath: List[int],
                  dist=300) -> None:
    """
    Assume edges is geodataframe indexed by multi-index (u, v, key).

    Example:
        plot_cpath_ox(G, nodes, edges, trip['cpath'], dist=5000)
    """
    route = get_route(edges, cpath)
    plot_route(G, nodes, route, dist=dist)

def plot_route(G: MultiDiGraph, nodes: GeoDataFrame, route: List[int],
               center_node: Optional[int]=None, dist=300) -> None:
    n = len(route)
    if center_node is None: center_node = route[n//2]
    y, x = nodes.loc[center_node, ['y', 'x']].values
    bbox = ox.utils_geo.bbox_from_point(point=(y, x), dist=dist)
    fig, ax = ox.plot_graph_route(G, route, bbox=bbox, route_linewidth=3, node_size=.5)
                                  
def get_route(edges: GeoDataFrame, cpath) -> List[int]:
    """
    Assume edges is geodataframe indexed by multi-index (u, v, key).
    """
    getuv = lambda fid: edges[edges.fid == fid].index[0][0]
    return list(map(getuv, cpath)) + [edges[edges.fid == cpath[-1]].index[0][1]]