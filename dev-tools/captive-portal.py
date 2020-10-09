#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3

from http.server import BaseHTTPRequestHandler, HTTPServer

isAuthorized = False
host = '127.0.0.1'
port = 8000

def textHtml(requestHandler, content):
    requestHandler.send_response(200)
    requestHandler.send_header('Content-type', 'text/html')
    requestHandler.end_headers()
    requestHandler.wfile.write(bytes(content, 'utf8'))

def redirectTo(requestHandler, location):
    requestHandler.send_response(301)
    requestHandler.send_header('Location', location)
    requestHandler.end_headers()
    requestHandler.wfile.write(bytes("Redirection!", 'utf8'))

class requestHandler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path == '/portal':
            textHtml(self, '<form action="/portal" method="POST"><button>Login</button></form>')

        elif self.path == '/logout':
            global isAuthorized
            isAuthorized = False
            redirectTo(self, 'http://localhost:8000/portal')

        elif isAuthorized:
            textHtml(self, 'Success')

        else:
            redirectTo(self, 'http://localhost:8000/portal')

    def do_POST(self):
        if self.path == '/portal':
            global isAuthorized
            isAuthorized = True
            redirectTo(self, 'http://localhost:8000')

with HTTPServer((host, port), requestHandler) as httpd:
    print(f'Running captive portal on port {port}...')
    httpd.serve_forever()
