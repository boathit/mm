import socketserver
from mapmatcher import MapMatcher
import optparse
import json

class MyTCPHandler(socketserver.StreamRequestHandler):
    """
    The request handler class for our server.

    It is instantiated once per connection to the server, and must
    override the handle() method to implement communication to the
    client.
    """

    def handle(self):
        # self.request is the TCP socket connected to the client
        wkt = self.rfile.readline().strip().decode("utf-8")
        result = self.server.mapmatcher.match_wkt(wkt)
        if result.mgeom.get_num_points() > 0:
            mgeom_wkt = result.mgeom.export_wkt()
        else:
            mgeom_wkt = ""
        if result.pgeom.get_num_points() > 0:
            pgeom_wkt = result.pgeom.export_wkt()
        else:
            pgeom_wkt = ""

        length = [c.length for c in result.candidates]
        offset = [c.offset for c in result.candidates]
        spdist = [c.spdist for c in result.candidates]

        if mgeom_wkt != "":
            response_json = {"mgeom_wkt": mgeom_wkt, 
                             "pgeom_wkt": pgeom_wkt, 
                             "opath": list(result.opath), 
                             "cpath": list(result.cpath),
                             "indices": list(result.indices),
                             "offset": offset, 
                             "length": length,
                             "spdist": spdist, 
                             "state": 1}
            self.request.sendall(json.dumps(response_json).encode("utf-8"))
        else:
            self.request.sendall(json.dumps({"state": 0}).encode("utf-8"))

if __name__ == "__main__":

    parser = optparse.OptionParser()
    parser.add_option(
        '-d', '--debug',
        help="enable debug mode",
        action="store_true", default=False)
    parser.add_option(
        '-p', '--port',
        help="which port to serve content on", action="store", dest="port", type='int', default=1235)
    parser.add_option(
        '-c', '--config',
        help="the model configuration file", action="store", dest="config_file",
        type='string', default="fmm_config.json")
    opts, args = parser.parse_args()

    HOST, PORT = "0.0.0.0", opts.port
    
    server = socketserver.TCPServer((HOST, PORT), MyTCPHandler)
    server.mapmatcher = MapMatcher(opts.config_file)


    # Activate the server; this will keep running until you
    # interrupt the program with Ctrl-C
    server.serve_forever()