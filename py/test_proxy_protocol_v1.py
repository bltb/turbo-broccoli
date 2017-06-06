#!/usr/bin/env python
'''
Crude test client to a HTTP(S) server listening for proxy protocol
connections. Takes a HTTP(S) url as an argument and prints out the raw
response.

$ ppurlcat.py https://localhost/ | head -1
HTTP/1.1 200 OK
'''

import socket
import ssl
import sys
from urlparse import urlparse

class ProxyHTTPRequest(object):
    '''
    ProxyHTTPRequest
    '''
    def __init__(self, url):
        parsed = urlparse(url)
        dst = parsed.netloc
        if ':' in parsed.netloc:
            dst, dst_port = dst.split(':')
        else:
            dst_port = {'https': 443, 'http': 80}[parsed.scheme]
        self.parsed = parsed
        self.src_port = 33333
        self.src = '127.0.0.1'
        self.dst = socket.gethostbyname(dst)
        self.dst_port = dst_port
        self.conn = None

    def proxy_request(self):
        'Generates the proxy protocol string'

        lll = ('PROXY', 'TCP4', self.src, self.dst, self.src_port, self.dst_port)
        data = [str(x) for x in lll]
        return ' '.join(data) + '\r\n'

    def connect(self):
        '''Creates the TCP connection, sends the proxy protocol string then
           upgrades the socket to SSL if appropriate'''

        self.conn = socket.create_connection((self.dst, self.dst_port))
        self.conn.send(self.proxy_request())
        if self.parsed.scheme == 'https':

            # context = ssl.SSLContext(ssl.PROTOCOL_TLSv1)
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            context.load_default_certs()
            
            # s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            # ssl_sock = context.wrap_socket(s, server_hostname='www.verisign.com')
            # ssl_sock.connect(('www.verisign.com', 443))

            # # monkey patch
            # try:
            #     _create_unverified_https_context = ssl._create_unverified_context
            # except AttributeError:
            # # Legacy Python that doesn't verify HTTPS certificates by default
            #     pass
            # else:
            #     # Handle target environment that doesn't support HTTPS verification
            #     ssl._create_default_https_context = _create_unverified_https_context
            self.conn = context.wrap_socket(self.conn)
            # self.conn = ssl.wrap_socket(self.conn)

    def get(self):
        'Sends a simple HTTP request and prints out the raw response'

        self.connect()
        self.conn.send('GET {0} HTTP/1.0\r\n\r\n'.format(self.parsed.path))
        out = ''
        while True:
            last_read = self.conn.recv()
            if not last_read:
                break
            else:
                out += last_read
        return out


if __name__ == '__main__':
    print ProxyHTTPRequest(sys.argv[1]).get()
