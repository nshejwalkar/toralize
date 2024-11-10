This tool simulates connecting to a host ip through the [Tor network](https://en.wikipedia.org/wiki/Tor_(network)), which routes traffic through a random chain of 3 proxies from thousands of volunteer relays around the world, the process of which is called onion routing.
Like onion routing, toralize will start a variable number (>=3) of local proxy servers using [Dante](https://www.inet.no/dante/), randomly choose a 3 proxy route between all of them, and send the connection request through using [SOCKS4](https://www.openssh.com/txt/socks4.protocol).
Unlike onion routing, toralize has no encryption (yet).

Usage: ./toralize.sh [-s num_servers] [-v] <host> <port>
      -s         specify number of dante servers to open (default is 3)
      -v         verbose

NEED:
Dante
- sudo apt install -y dante-server

gcc
