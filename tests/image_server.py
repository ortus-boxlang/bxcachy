#!/usr/bin/env python3
"""A tiny local server for tests/image_cache_test.bxs: good and bad pictures, one too big, one with no length, one slow.
Usage: image_server.py PORTFILE   (picks a free port on 127.0.0.1, writes it to PORTFILE, logs every request path to PORTFILE.log)"""
import base64, http.server, socketserver, sys, time
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
GIF = base64.b64decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')
JPG = b'\xff\xd8\xff\xe0' + b'\x00' * 40
WEBP = b'RIFF' + (20).to_bytes(4, 'little') + b'WEBPVP8 ' + b'\x00' * 12
log = open(sys.argv[1] + '.log', 'a', buffering=1)
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, body, code=200, length=True):
        self.send_response(code); self.send_header('Content-Type', 'image/png')
        if length: self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        log.write(self.path + '\n')
        p = self.path
        if p == '/good.png': self.send(PNG)
        elif p == '/good.gif': self.send(GIF)
        elif p == '/good.jpg': self.send(JPG)
        elif p == '/good.webp': self.send(WEBP)
        elif p.startswith('/png/'):
            self.send(PNG) if p[5:] in ('thunderbird.png', 'slack-light.png', 'vscode-dark.png') else self.send(b'nope', 404)
        elif p == '/bad.png': self.send(b'this is not a picture at all')
        elif p == '/empty.png': self.send(b'')
        elif p == '/huge.png': self.send(PNG + b'\x00' * (6 * 1024 * 1024))
        elif p == '/huge-nolen.png':
            self.send_response(200); self.send_header('Connection', 'close'); self.end_headers()
            self.wfile.write(PNG + b'\x00' * (6 * 1024 * 1024))
        elif p == '/slow.png': time.sleep(30); self.send(PNG)
        else: self.send(b'nope', 404)
class S(socketserver.ThreadingMixIn, http.server.HTTPServer): daemon_threads = True
srv = S(('127.0.0.1', 0), H)
open(sys.argv[1], 'w').write(str(srv.server_address[1]))
srv.serve_forever()
