#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3

from http.server import BaseHTTPRequestHandler, HTTPServer

isAuthorized = False

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
        host = self.headers['host']
        if self.path == '/portal':
            textHtml(self, (
                '<form action="/portal" method="POST">'
                '<label>Useless input: <input type="text"></label><br>'
                '<label>Mandatory checkbox: <input required type="checkbox"></label><br>'
                '<button>Login</button>'
                '</form>'
            ))

        elif self.path == '/logout':
            global isAuthorized
            isAuthorized = False
            redirectTo(self, f'http://{host}/portal')

        elif isAuthorized:
            textHtml(self, 'Open Sesame')

        else:
            redirectTo(self, f'http://{host}/portal')

    def do_POST(self):
        host = self.headers['host']
        if self.path == '/portal':
            global isAuthorized
            isAuthorized = True
            redirectTo(self, f'http://{host}')

port = 8000
with HTTPServer(('127.0.0.1', port), requestHandler) as httpd:
    print(f'Running captive portal on port {port}...')
    httpd.serve_forever()
