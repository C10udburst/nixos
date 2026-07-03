#!/usr/bin/env python3
import http.server
import mimetypes
import socket
import socketserver
from argparse import ArgumentParser
from base64 import b64encode
from http.server import HTTPServer, SimpleHTTPRequestHandler
from os import chdir

# argparse
parser = ArgumentParser(
    description="Create a simple web server to share files over local network"
)
parser.add_argument(
    "--port", type=int, default=8000, help="Define server's port (default:8000)"
)
parser.add_argument(
    "--dir",
    type=str,
    default=".",
    help="Define directory which is used by server (default: current)",
)
parser.add_argument("--auth", type=str, nargs=2, help="Enable password protection")
args = parser.parse_args()

chdir(args.dir)

# Auth settings
username, password = [0, 0]
if args.auth:
  username = args.auth[0]
  password = args.auth[1]


class AuthHandler(SimpleHTTPRequestHandler):
  """Main class to present webpages and authentication."""

  def end_headers(self):
    self.send_header("Access-Control-Allow-Origin", "*")
    SimpleHTTPRequestHandler.end_headers(self)

  def do_AUTHHEAD(self):
    self.send_response(401)
    self.send_header("WWW-Authenticate", 'Basic realm="www"')
    self.send_header("Content-type", "text/html")
    self.send_header("Content-Length", "47")
    self.end_headers()

  def do_GET(self):
    """Present frontpage with user authentication."""
    self.authheader = "Basic " + (
        b64encode((username + ":" + password).encode("utf-8"))
    ).decode("utf-8")
    if self.headers["Authorization"] == None:
      self.do_AUTHHEAD()
      self.wfile.write(b'<h1 style="color: #e01a00;">Not authorized</h1>')
      pass
    elif self.headers["Authorization"] == self.authheader:
      SimpleHTTPRequestHandler.do_GET(self)
      print("Auth header: " + self.headers["Authorization"])
      pass
    else:
      self.do_AUTHHEAD()
      self.wfile.write(b'<h1 style="color: #e01a00;">Not authorized</h1>')
      print("Auth header: " + self.headers["Authorization"])
      pass

  def do_POST(self):
    content_length = int(self.headers["Content-Length"])
    post_data = self.rfile.read(content_length)
    ext = (
        str(mimetypes.guess_extension(self.headers["Content-Type"]))
        .replace("None", "")
    )
    open("file" + ext, "wb").write(post_data)
    print("Saved file" + ext)
    SimpleHTTPRequestHandler.do_HEAD(self)


class RegularHandler(SimpleHTTPRequestHandler):

  def end_headers(self):
    self.send_header("Access-Control-Allow-Origin", "*")
    SimpleHTTPRequestHandler.end_headers(self)

  def do_GET(self):
    SimpleHTTPRequestHandler.do_GET(self)

  def do_POST(self):
    content_length = int(self.headers["Content-Length"])
    post_data = self.rfile.read(content_length)
    ext = (
        str(mimetypes.guess_extension(self.headers["Content-Type"]))
        .replace("None", "")
    )
    open("file" + ext, "wb").write(post_data)
    print("Saved file" + ext)
    SimpleHTTPRequestHandler.do_HEAD(self)


try:
  ipaddrs = sorted(
      {
          addr[4][0]
          for addr in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET)
          if not addr[4][0].startswith("127.")
      }
  )
  if not ipaddrs:
    ipaddrs = ["localhost"]
except Exception:
  ipaddrs = ["localhost"]

if args.auth:
  Handler = AuthHandler
else:
  Handler = RegularHandler

with socketserver.TCPServer(("", args.port), Handler) as httpd:
  if args.auth:
    print(
        "Server running on: "
        + ", ".join([f"http://{ip}:{args.port}" for ip in ipaddrs])
        + " with credentials: "
        + ", ".join(args.auth)
        + "\n"
        + "-" * 100
        + "\n"
    )
  else:
    print(
        "Server running on: "
        + ", ".join(["http://" + ip + ":" + str(args.port) for ip in ipaddrs])
        + "\n"
        + "-" * 100
        + "\n"
    )
  try:
    httpd.serve_forever()
  except KeyboardInterrupt:
    print("^C pressed. Exiting...")
    raise SystemExit(0)
  except Exception:
    print("An error has occurred when starting server. Exiting...")
    raise SystemExit(1)
