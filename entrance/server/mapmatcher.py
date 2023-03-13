import os, json
from fmm import Network, NetworkGraph
from fmm import FastMapMatch, FastMapMatchConfig, UBODT
from fmm import STMATCH, STMATCHConfig

class MapMatcherConfig(object):
    def __init__(self, config_json_file):
        if not os.path.exists(config_json_file):
            raise Exception(
                "File for {} is missing.".format(config_json_file))
        with open(config_json_file) as f:
            data = json.load(f)

        self.network_file = str(data["input"]["network"]["file"])
        self.network_id = str(data["input"]["network"]["id"]) if "id" in data["input"]["network"] else "id"
        self.network_source = str(data["input"]["network"]["source"]) if "source" in data["input"]["network"] else "source"
        self.network_target = str(data["input"]["network"]["target"]) if "target" in data["input"]["network"] else "target"
        
        if str(data["model"]) == "stmatch":
            self.model_tag = "stmatch"
            self.mm_config = STMATCHConfig()
            if "parameters" in data:
                if "k" in data["parameters"]:
                    self.mm_config.k = data["parameters"]["k"]
                if "r" in data["parameters"]:
                    self.mm_config.radius = data["parameters"]["r"]
                if "e" in data["parameters"]:
                    self.mm_config.gps_error = data["parameters"]["e"]
                if "f" in data["parameters"]:
                    self.mm_config.factor = data["parameters"]["f"]
                if "vmax" in data["parameters"]:
                    self.mm_config.vmax = data["parameters"]["vmax"]
        elif str(data["model"]) == "fmm":
            self.model_tag = "fmm"
            self.ubodt_file = str(data["input"]["ubodt"]["file"])
            self.mm_config = FastMapMatchConfig()
            if "parameters" in data:
                if "k" in data["parameters"]:
                    self.mm_config.k = data["parameters"]["k"]
                if "r" in data["parameters"]:
                    self.mm_config.radius = data["parameters"]["r"]
                if "e" in data["parameters"]:
                    self.mm_config.gps_error = data["parameters"]["e"]
        else:
            raise Exception("Unkown model.")

class MapMatcher(object):
    def __init__(self, config_json_file):
        if not os.path.exists(config_json_file):
            raise Exception(
                "File for {} is missing.".format(config_json_file))
        config = MapMatcherConfig(config_json_file)
        print("loading network")
        print(config.network_id)
        print(config.network_source)
        print(config.network_target)
        self.network = Network(
            config.network_file, 
            config.network_id,
            config.network_source, 
            config.network_target
        )
                
        self.graph = NetworkGraph(self.network)
        if config.model_tag == "stmatch":
            self.model = STMATCH(self.network,self.graph)
            self.mm_config = config.mm_config
        elif config.model_tag == "fmm":
            self.ubodt = UBODT.read_ubodt_file(config.ubodt_file)
            self.model = FastMapMatch(self.network, self.graph, self.ubodt)
            self.mm_config = config.mm_config
        else:
            raise Exception("Unknown model.")

    def match_wkt(self, wkt):
        return self.model.match_wkt(wkt, self.mm_config)

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
    mapmatcher = MapMatcher("fmm_config.json")
    gps_wkt = "LINESTRING(126.60311000000002 45.742172,126.60328 45.742348,126.60574 45.744152,126.60761 45.746216,126.60878999999998 45.74774,126.60878 45.74777,126.60883 45.747696000000005,126.60884 45.7477,126.60725 45.74565,126.60481 45.74328,126.60404 45.74251,126.60352 45.742764,126.60663 45.740715,126.61026 45.73876,126.61136 45.738293,126.614 45.736755,126.617516 45.73877,126.619125 45.739956,126.62125 45.739075,126.622284 45.73876,126.62337 45.738537,126.62215 45.736294,126.620705 45.73475,126.61933 45.733807,126.614494 45.73659,126.61197 45.738026,126.60894 45.73976,126.6061 45.741264,126.607025 45.74259,126.60714 45.742744,126.60595 45.7412,126.61218999999998 45.73778,126.6141 45.736694)"
    result = mapmatcher.match_wkt(gps_wkt)
    print(type(result))
    print(parse_match(result))