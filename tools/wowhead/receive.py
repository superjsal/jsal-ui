"""Takes data out of the browser pane, where downloads are blocked and Wowhead's pages may not
send to other sites: serves a page on 127.0.0.1:8799; a browser tab sent to
http://127.0.0.1:8799/#<the data, URI-encoded> posts the data back to it, and it's written to
the file given. It stops after one save (or ten minutes).

Run: python -I tools/wowhead/receive.py data/gear/wowhead-items.json
"""
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = sys.argv[1]

PAGE = b"""<!doctype html><meta charset="utf-8"><title>receiver</title><p id="s">waiting</p>
<script>
if (location.hash.length > 1) {
  fetch('/', { method: 'POST', body: decodeURIComponent(location.hash.slice(1)) })
    .then(r => r.text()).then(t => { document.getElementById('s').textContent = 'saved ' + t + ' bytes'; });
}
</script>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(PAGE)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n)
        with open(OUT, "wb") as f:
            f.write(body)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(str(len(body)).encode())
        self.server.done = True

    def log_message(self, *args):
        pass


server = HTTPServer(("127.0.0.1", 8799), Handler)
server.done = False
server.timeout = 600
while not server.done:
    server.handle_request()
print("saved", OUT)
