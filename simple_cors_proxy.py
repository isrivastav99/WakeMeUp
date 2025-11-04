#!/usr/bin/env python3
"""
Simple CORS proxy for Google Places API
Runs on localhost:8082 to avoid CORS issues
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request
import urllib.parse
import json

class CORSProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            # Extract the target URL from query parameters
            if self.path.startswith('/proxy?'):
                # Parse query parameters
                query_string = self.path[7:]  # Remove '/proxy?'
                params = urllib.parse.parse_qs(query_string)
                
                if 'url' not in params:
                    self.send_error(400, "Missing 'url' parameter")
                    return
                
                target_url = params['url'][0]
                print(f"Proxying request to: {target_url}")
                
                # Make the request to Google Places API
                req = urllib.request.Request(target_url)
                req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
                
                with urllib.request.urlopen(req) as response:
                    data = response.read()
                    
                    # Send CORS headers
                    self.send_response(200)
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                    self.send_header('Access-Control-Allow-Headers', 'Content-Type')
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    
                    # Send the response
                    self.wfile.write(data)
                    
            else:
                self.send_error(404, "Not Found")
                
        except Exception as e:
            print(f"Error: {e}")
            self.send_error(500, f"Proxy Error: {str(e)}")
    
    def do_OPTIONS(self):
        # Handle preflight requests
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('localhost', 8082), CORSProxyHandler)
    print("CORS Proxy running on http://localhost:8082")
    print("Usage: http://localhost:8082/proxy?url=<encoded_google_places_url>")
    server.serve_forever()

