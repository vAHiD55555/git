#include "cache.h"
#include "merge-strategies.h"

static int merge_entry(struct index_state *istate, unsigned int pos,
		       const char *path, int *err, merge_index_fn fn,
		       void *data)
{
	int found = 0;
	const struct object_id *oids[3] = { 0 };
	unsigned int modes[3] = { 0 };

	*err = 0;

	if (pos >= istate->cache_nr)
		die(_("'%s' is not in the cache"), path);
	do {
		const struct cache_entry *ce = istate->cache[pos];
		int stage = ce_stage(ce);

		if (strcmp(ce->name, path))
			break;
		found++;
		oids[stage - 1] = &ce->oid;
		modes[stage - 1] = ce->ce_mode;
	} while (++pos < istate->cache_nr);
	if (!found)
		die(_("'%s' is not in the cache"), path);

	if (fn(istate, oids[0], oids[1], oids[2], path, modes[0], modes[1],
	       modes[2], data))
		(*err)++;

	return found;
}

int merge_index_path(struct index_state *istate, int oneshot, int quiet,
		     const char *path, merge_index_fn fn, void *data)
{
	int err, ret;
	int pos = index_name_pos(istate, path, strlen(path));

	/*
	 * If it already exists in the cache as stage0, it's
	 * already merged and there is nothing to do.
	 */
	if (pos >= 0)
		return 0;

	ret = merge_entry(istate, -pos - 1, path, &err, fn, data);
	if (ret < 0)
		return ret;
	if (err) {
		if (!quiet && !oneshot)
			die(_("merge program failed"));
		return 1;
	}
	return 0;
}

int merge_all_index(struct index_state *istate, int oneshot, int quiet,
		    merge_index_fn fn, void *data)
{
	int err, ret;
	unsigned int i;

	for (i = 0; i < istate->cache_nr; i++) {
		const struct cache_entry *ce = istate->cache[i];
		if (!ce_stage(ce))
			continue;

		ret = merge_entry(istate, i, ce->name, &err, fn, data);
		if (ret < 0)
			return ret;
		else if (ret > 0)
			i += ret - 1;

		if (err && !oneshot) {
			if (!quiet)
				die(_("merge program failed"));
			return 1;
		}
	}

	if (err && !quiet)
		die(_("merge program failed"));
	return err;
}
