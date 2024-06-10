import http.server
import socket
import socketserver
import threading
import subprocess
import time

PORT = 45678
request_count = 0

def main():
    """Checks that the kiosk-browser does not crash immediately on start and makes a request to the provided URL.

    This serves as a minimal test to make sure the kiosk can run on different platforms.
    """

    # Start dummy web server in thread, with signal to stop
    keep_running = threading.Event()
    keep_running.set()
    server_thread = threading.Thread(target=run_server, args=(keep_running,))
    server_thread.start()
    time.sleep(1)

    try:
        browser_process = subprocess.Popen(['bin/kiosk-browser', f'http://localhost:{PORT}', f'http://localhost:{PORT}'])
        time.sleep(5)

        # Minimal expectations
        assert browser_process.poll() is None, "Browser process has crashed."
        assert request_count >= 1, "No requests were made to the server."
        
        print("Smoke test passed successfully.")

    finally:
        # Send signal to stop web server and wait for completion
        keep_running.clear()
        server_thread.join()

        # Terminate the browser process
        browser_process.terminate()

class RequestHandler(http.server.SimpleHTTPRequestHandler):
    """Default request handler with added counter."""
    def do_GET(self):
        global request_count
        request_count += 1
        # Call superclass method to actually serve the request
        super().do_GET()

def run_server(keep_running):
    """Run the web server, checking whether to keep running frequently."""
    with socketserver.TCPServer(("", PORT), RequestHandler, bind_and_activate=False) as httpd:
        # Let address be reused to avoid failure on repeated runs
        httpd.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        httpd.server_bind()
        httpd.server_activate()
        # Timeout frequently to check if killed
        httpd.timeout = 0.5
        try:
            while keep_running.is_set():
                httpd.handle_request()
        finally:
            httpd.server_close()

main()
