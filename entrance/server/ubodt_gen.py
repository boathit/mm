import os, sys
from fmm import Network, NetworkGraph, UBODTGenAlgorithm

#for city in os.listdir("../data/cities/"):

assert len(sys.argv) > 1, "Please provide the city name like, python ubodt_gen.py harbin"
city = sys.argv[1]
assert os.path.exists(f"../data/cities/{city}"), f"{city} is not found in ../data/cities"

print(f"Generating ubodt for city {city}...")
network = Network(f"../data/cities/{city}/edges.shp", "fid", "u", "v")
print(network.get_node_count())
print(network.get_edge_count())
graph = NetworkGraph(network)

# Can be skipped if you already generated an ubodt file
ubodt_gen = UBODTGenAlgorithm(network, graph)
# The delta is defined as 3 km approximately. 0.03 degrees. 
status = ubodt_gen.generate_ubodt(f"../data/cities/{city}/ubodt.bin", 0.03, binary=True, use_omp=True)
# Binary is faster for both IO and precomputation
print(status)