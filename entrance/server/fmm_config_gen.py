import os, sys, json

assert len(sys.argv) > 1, "Please provide the city name like, python fmm_config_gen.py harbin"
city = sys.argv[1]
assert os.path.exists(f"../data/cities/{city}"), f"{city} is not found in ../data/cities"

config = {
    "harbin": {
        "input": {
            "network": {
                "file": f"../data/cities/{city}/edges.shp",
                "id": "fid",
                "source": "u",
                "target": "v"
            },
            "ubodt": {
                "file": f"../data/cities/{city}/ubodt.bin"
            }
        },
        "model": "fmm",
        "parameters": {
            "k": 32,
            "r": 0.01, # 1000m
            "e": 0.002 # 200m
        }
    },
    "chengdu": {
        "input": {
            "network": {
                "file": f"../data/cities/{city}/edges.shp",
                "id": "fid",
                "source": "u",
                "target": "v"
            },
            "ubodt": {
                "file": f"../data/cities/{city}/ubodt.bin"
            }
        },
        "model": "fmm",
        "parameters": {
            "k": 16,
            "r": 0.003, #300m
            "e": 0.003  #300m
        }
    },
    "porto": {
        "input": {
            "network": {
                "file": f"../data/cities/{city}/edges.shp",
                "id": "fid",
                "source": "u",
                "target": "v"
            },
            "ubodt": {
                "file": f"../data/cities/{city}/ubodt.bin"
            }
        },
        "model": "fmm",
        "parameters": {
            "k": 16,
            "r": 0.003, #300m
            "e": 0.003  #300m
        }
    }
}
assert city in config.keys(), f"Not found config for city {city}"
print("fmm will be running with the following configuration:")
print(json.dumps(config[city], indent=2))

with open("fmm_config.json", "w") as f:
    json.dump(config[city], f, indent=2)