#ifndef DAEMON_UTILS_H
#define DAEMON_UTILS_H

#include "git-compat-util.h"
#include "run-command.h"
#include "string-list.h"

typedef void (*log_fn)(const char *msg, ...);

struct socketlist {
	int *list;
	size_t nr;
	size_t alloc;
};

/* Enable sending of keep-alive messages on the socket. */
void set_keep_alive(int sockfd, log_fn logerror);

/* Setup a number of sockets to listen on the provided addresses. */
void socksetup(struct string_list *listen_addr, int listen_port,
	       struct socketlist *socklist, int reuseaddr,
	       log_fn logerror);

struct child {
	struct child *next;
	struct child_process cld;
	struct sockaddr_storage address;
};

void add_child(struct child_process *cld, struct sockaddr *addr, socklen_t addrlen,
	       struct child *first, unsigned int *live_children);

void kill_some_child(struct child *first);

void check_dead_children(struct child *first, unsigned int *live_children,
			 log_fn loginfo);

#endif
