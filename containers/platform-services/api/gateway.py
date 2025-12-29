#!/usr/bin/env python3
"""
CNOE Platform API Gateway
Simple API gateway for platform services
"""
import http.server
import socketserver
import json
import os
from urllib.parse import urlparse, parse_qs

PORT = int(os.environ.get('PORT', 8080))

class CNOEHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        
        # Health check endpoint
        if parsed_path.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'status': 'healthy',
                'service': 'cnoe-platform-api',
                'version': '1.0.0'
            }
            self.wfile.write(json.dumps(response).encode())
            return
        
        # API info endpoint
        if parsed_path.path == '/api/info':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'platform': 'CNOE Internal Developer Portal',
                'components': {
                    'argocd': 'GitOps Continuous Delivery',
                    'backstage': 'Developer Portal (Infrastructure Ready)',
                    'kubernetes': 'Container Orchestration'
                },
                'endpoints': {
                    'api': 'http://localhost:8080',
                    'portal': 'http://localhost:8081',
                    'docs': 'http://localhost:8082'
                }
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            return
        
        # Catalog endpoint
        if parsed_path.path == '/api/catalog':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'services': [
                    {
                        'name': 'sample-app',
                        'type': 'application',
                        'status': 'active',
                        'repository': 'https://github.com/your-org/sample-app'
                    }
                ],
                'templates': [
                    {
                        'name': 'nodejs-service',
                        'description': 'Node.js microservice template',
                        'language': 'javascript'
                    },
                    {
                        'name': 'python-api',
                        'description': 'Python FastAPI template',
                        'language': 'python'
                    }
                ]
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
            return
        
        # Default 404
        self.send_response(404)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        response = {'error': 'Not Found', 'path': self.path}
        self.wfile.write(json.dumps(response).encode())

if __name__ == '__main__':
    with socketserver.TCPServer(("", PORT), CNOEHandler) as httpd:
        print(f"CNOE Platform API Gateway running on port {PORT}")
        httpd.serve_forever()
