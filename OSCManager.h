//
//  OSCManager.h
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OSCInPort.h"
#import "OSCOutPort.h"
#import <pthread.h>

/*
	TOP-LEVEL OVERVIEW
	
	this osc manager class is all you need to add to your app.  it has methods for
	adding and removing ports.  you can have as many osc managers as you like, but
	you should really only need one instance.
	
	input ports have a delegate- delegate methods are called as the port receives data.
	it's important to note that the delegate methods must be thread-safe: each input
	port is running on its own (non-main) thread.
	
	data is sent via the output ports (convenience methods for doing this are built
	into the osc manager).
	
	
	
	
			GENERAL OSC STRUCTURE AND OVERVIEW
	
	this framework was written from the OSC spec found here:
	http://opensoundcontrol.org/spec-1_0
	
	- an OSC packet is the basic unit of transmitting OSC data.
	- an OSC packet consists of:
		- contents- contiguous block of binary data (either a bundle or a message), and then the
		- size- number of 8-bit bytes that comprise 'contents'- ALWAYS multiple of 4!
	- an OSC message consists of:
		- an OSC address pattern (starting with '/'), followed by
		- an OSC type tag string, followed by
		- zero or more 'OSC arguments'
	- an OSC bundle consists of:
		- the OSC-string "#bundle", followed by
		- an OSC  time tag, followed by
		- zero or more 'OSC bundle elements'
	- an OSC bundle element consists of:
		- 'size' (int32)- number of 8-bit bytes in the contents- ALWAYS multiple of 4!
		- 'contents'- either another OSC bundle, or an OSC message
	
	
	
	
			PORTS- SENDING AND RECEIVING UDP/TCP DATA
	
	some basic information, gleaned from:
	http://beej.us/guide/bgnet/output/html/multipage/index.html
	
	struct sockaddr	{
		unsigned short		sa_family;		//	address family, AF_xxx
		char				sa_data[14];	//	14 bytes of protocol address
	}
	struct sockaddr_in	{
		short int			sin_family;		//	address family
		unsigned short int	sin_port;		//	port number
		struct in_addr		sin_addr;		//	internet address
		unsigned char		sin_zero[8];	//	exists so sockaddr_in has same length as sockaddr
	}
	
	recv(int sockfd, void *buf, int len, unsigned int flags);
		- sockfd is the socket descriptor to read from
		- buf is the buffer to read the information into
		- len is the max length of the buffer
		- flags can be set to 0
	recvfrom(int sockfd, void *buf, int len, unsigned int flags, struct sockaddr *from, int *fromlen);
		- from is a pointer to a local struct sockaddr that will be filled with the IP & port of the originating machine
		- fromlen is a pointer to a local int that should be initialized to a sizeof(struct sockaddr)- contains length of address actually stored in from on return
		...as well as the 4 params listed above in recv()
	
	int select(int numfds, fd_set *readrds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
*/

@interface OSCManager : NSObject {
	NSMutableArray			*inPortArray;
	NSMutableArray			*outPortArray;
	
	pthread_rwlock_t		inPortLock;
	pthread_rwlock_t		outPortLock;
}

- (OSCInPort *) createNewInputForPort:(int)p;
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p;

- (id) inPortClass;
- (id) outPortClass;

@end
