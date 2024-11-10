#include "toralize.h"

Req* request(const char* dstip, const int dstport) {
   Req* req;
   req = malloc(reqsize);

   req->vn = 4;                     // always 4 
   req->cd = 1;                     // 1 = connect
   req->dstport = htons(dstport);
   req->dstip = inet_addr(dstip);
   strcpy(req->userid, USERNAME);
   // req->null = 0;

   return req;
}

void printRes(Res* res) {
   printf("vn is %d\n", res->vn);
   printf("cd is %d\n", res->cd);
   printf("third is %d\n", res->_);
   printf("fourth is %d\n", res->__);
}

int main(int argc, char* argv[]) {
   char* host;    // server to eventually connect to
   int port;      // host port

   int s;                     // local socket fd (lives on machine)
   struct sockaddr_in sock;   // holds data about where to connect to
   Req* req;
   Res* res;
   char buf[ressize];
   int success;

   if (argc < 3) {
      fprintf(stderr, "Usage: %s <host> <port>\n", argv[0]);
      return -1;
   }

   host = argv[1];
   port = atoi(argv[2]);  

   s = socket(AF_INET, SOCK_STREAM, 0);
   if (s < 0) {
      perror("Socket creation failed");
      exit(EXIT_FAILURE);
   }
 
   sock.sin_family = AF_INET;
   sock.sin_port = htons(PROXYPORT);  // SOCKS4 proxy port, htons converts port # to network byte order as expected by connect
   sock.sin_addr.s_addr = inet_addr(PROXYIP);  // Proxy server IP
   if (connect(s, (struct sockaddr *)&sock, sizeof(sock))) {
      perror("connection failed");
      exit(EXIT_FAILURE);
   }
   // printf("reqsize is %ld\n", reqsize);
   printf("Connected to proxy at ip %s via port %d\n", PROXYIP, PROXYPORT);

   // send SOCKS4 request to proxy, which will try to honor it
   req = request(host, port);
   write(s, req, reqsize);
   
   // prepare to read
   memset(buf, 0, ressize);
   
   // read response from proxy
   if (read(s, buf, ressize) < 1) {
      perror("read error");
      free(req);
      close(s);
      return -1;
   }

   res = (Res *)buf;
   success = (res->cd == 90);
   if (!success) {
      fprintf(stderr, "unable to traverse the proxy, ecode: %d\n",
      res->cd);
      free(req);
      close(s);
      return -1;
   }

   printf("Successfully connected thru proxy to host %s:%d\n", host, port);

   free(req);
   close(s);
   return 0;
}