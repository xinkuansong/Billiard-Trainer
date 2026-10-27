from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
from pathlib import Path
import json,os
root=Path(__file__).resolve().parents[2]/'output'
server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(root)))
(root/'rack-front-playback-20261027/server.json').write_text(json.dumps(dict(pid=os.getpid(),port=server.server_port,url=f'http://127.0.0.1:{server.server_port}/rack-front-playback-20261027/player.html')))
server.serve_forever()
