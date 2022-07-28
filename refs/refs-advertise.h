#ifndef REFS_REFS_ADVERTISE_H
#define REFS_REFS_ADVERTISE_H

#include "../hash.h"

void create_advertise_refs_filter(const char *command);
void clean_advertise_refs_filter(void);
int filter_advertise_ref(const char *refname, const struct object_id *oid);
int filter_advertise_object(const struct object_id *oid);

#endif
