import json
from fmm import (Network, NetworkGraph, FastMapMatch, FastMapMatchConfig, 
                 UBODT, STMATCH, STMATCHConfig)

# def get_mapmatcher(config_file: str):
#     with open(config_file, "r") as f:
#         params = json.load(f)
    
#     network_file = params["input"]["network"]["file"]
#     network_id   = params["input"]["network"]["id"]
#     network_src  = params["input"]["network"]["source"]
#     network_trg  = params["input"]["network"]["target"]
    
#     network = Network(network_file, network_id, network_src, network_trg)
#     graph   = NetworkGraph(network)
    
#     if params["model"] == "stmatch":
#         mm_config = STMATCHConfig()
#         mm_config.k = params["parameters"]["k"]
#         mm_config.radius = params["parameters"]["r"]
#         mm_config.gps_error = params["parameters"]["e"]
#         mm_config.factor = params["parameters"]["f"]
#         mm_config.vmax = params["parameters"]["vmax"]
        
#         model = STMATCH(network, graph)
#     elif params["model"] == "fmm":
#         mm_config = FastMapMatchConfig()
#         mm_config.k = params["parameters"]["k"]
#         mm_config.radius = params["parameters"]["r"]
#         mm_config.gps_error = params["parameters"]["e"]
        
#         ubodt_file = params["input"]["ubodt"]["file"]
#         ubodt = UBODT.read_ubodt_file(ubodt_file)
#         model = FastMapMatch(network, graph, ubodt)
#     else:
#         raise Exception("Unkown model.")
    
#     return lambda gps_wkt: model.match_wkt(gps_wkt, mm_config)

class MapMatcher(object):
    def __init__(self, config_file) -> None:
        with open(config_file, "r") as f:
            params = json.load(f)
        
        network_file = params["input"]["network"]["file"]
        network_id   = params["input"]["network"]["id"]
        network_src  = params["input"]["network"]["source"]
        network_trg  = params["input"]["network"]["target"]
        
        ## It seems a bug for fmm and we have to use `self.network` and `self.graph` 
        ## here to guarantee that they are alive even when `__init__()` ends.
        ## It also explains why using function closure as `get_mapmatcher()` does
        ## not work, becasue once `get_mapmatcher()` ends, `network` and `graph`
        ## are no longer valid and it throws segment fault.
        self.network = Network(network_file, network_id, network_src, network_trg)
        self.graph   = NetworkGraph(self.network)
        
        if params["model"] == "stmatch":
            self.mm_config = STMATCHConfig()
            self.mm_config.k = params["parameters"]["k"]
            self.mm_config.radius = params["parameters"]["r"]
            self.mm_config.gps_error = params["parameters"]["e"]
            self.mm_config.factor = params["parameters"]["f"]
            self.mm_config.vmax = params["parameters"]["vmax"]
            
            self.model = STMATCH(self.network, self.graph)
        elif params["model"] == "fmm":
            self.mm_config = FastMapMatchConfig()
            self.mm_config.k = params["parameters"]["k"]
            self.mm_config.radius = params["parameters"]["r"]
            self.mm_config.gps_error = params["parameters"]["e"]
            
            ubodt_file = params["input"]["ubodt"]["file"]
            ubodt = UBODT.read_ubodt_file(ubodt_file)
            self.model = FastMapMatch(self.network, self.graph, ubodt)
        else:
            raise Exception("Unkown model.")
    
    def match_wkt(self, gps_wkt: str):
        return self.model.match_wkt(gps_wkt, self.mm_config)


def parse_match(result) -> dict:
    mgeom_wkt = result.mgeom.export_wkt() if result.mgeom.get_num_points() > 0 else ""
    pgeom_wkt = result.pgeom.export_wkt() if result.pgeom.get_num_points() > 0 else ""
    
    length = [c.length for c in result.candidates]
    offset = [c.offset for c in result.candidates]
    spdist = [c.spdist for c in result.candidates]

    response = {"mgeom_wkt": mgeom_wkt, 
                "pgeom_wkt": pgeom_wkt, 
                "opath": list(result.opath), # matched edge for each point
                "cpath": list(result.cpath), # matched path (has completed edges)
                "indices": list(result.indices),
                "offset": offset, 
                "length": length,
                "spdist": spdist, 
                "state": 1} if mgeom_wkt != "" else {"state": 0}
    return response

if __name__ == "__main__":
    #match_wkt = get_mapmatcher("fmm_config.json")
    gps_wkt = "LINESTRING(126.60311000000002 45.742172,126.60328 45.742348,126.60574 45.744152,126.60761 45.746216,126.60878999999998 45.74774,126.60878 45.74777,126.60883 45.747696000000005,126.60884 45.7477,126.60725 45.74565,126.60481 45.74328,126.60404 45.74251,126.60352 45.742764,126.60663 45.740715,126.61026 45.73876,126.61136 45.738293,126.614 45.736755,126.617516 45.73877,126.619125 45.739956,126.62125 45.739075,126.622284 45.73876,126.62337 45.738537,126.62215 45.736294,126.620705 45.73475,126.61933 45.733807,126.614494 45.73659,126.61197 45.738026,126.60894 45.73976,126.6061 45.741264,126.607025 45.74259,126.60714 45.742744,126.60595 45.7412,126.61218999999998 45.73778,126.6141 45.736694)"
    mapmatcher = MapMatcher("fmm_config.json")
    result = mapmatcher.match_wkt(gps_wkt)
    print(type(result))
    print(parse_match(result))