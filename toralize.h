#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#ifdef _WIN32
   #include <winsock2.h>    // Main Winsock library
   #include <ws2tcpip.h>    // For newer functionalities like inet_pton
#else
   #include <sys/socket.h>
   #include <netinet/in.h>
   #include <arpa/inet.h>
#endif

//// this is the localhost loopback interface. when running thru wsl, because wsl is a virtualized network environment, this will just point to itself (WE WANT THIS)
#define PROXYIP "127.0.0.1"
//// this is the window host's ip address through wsl. Specified by "nameserver" in /etc/resolv.conf file in wsl. changes every time wsl is closed/opened (THIS IS BAD, trying to interact wsl <-> host machine in networking brings out many complications/restrictions)
// #define PROXYIP "172.26.96.1"
//// this used to be 8080, but changed it because we need a port that is listened to by either 0.0.0.0 or 172.30.144.1 in windows specifically (use netstat -an on cmd to check) (<- IGNORE THAT, CHANGED TO RFC standard 1080, I set up a local dante server on wsl)
#define PROXYPORT 1083
#define USERNAME "toraliz"
#define reqsize sizeof(struct proxy_request)
#define ressize sizeof(struct proxy_response)

typedef unsigned char int8;         // 1 byte
typedef unsigned short int int16;   // 2 bytes
typedef unsigned int int32;         // 4 bytes

typedef struct proxy_request {
   int8 vn;                // 
   int8 cd;
   int16 dstport;
   int32 dstip;
   unsigned char userid[8];
   // int8 null;
} Req;

typedef struct proxy_response {
   int8 vn;                // 
   int8 cd;                // response code
   int16 _;                // ignored
   int32 __;               // ignored
} Res;

Req* request(const char*, const int);
void printRes(Res* res);
int main(int, char**);