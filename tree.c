#include "cache.h"
#include "cache-tree.h"
#include "tree.h"
#include "object-store.h"
#include "blob.h"
#include "commit.h"
#include "tag.h"
#include "alloc.h"
#include "tree-walk.h"
#include "repository.h"
#include "pathspec.h"

const char *tree_type = "tree";

int read_tree_at(struct repository *r,
		 struct tree *tree, struct strbuf *base,
		 const struct pathspec *pathspec,
		 read_tree_fn_t fn, void *context)
{
	struct tree_desc desc;
	struct name_entry entry;
	struct object_id oid;
	int len, oldlen = base->len;
	enum interesting retval = entry_not_interesting;

	if (repo_parse_tree(r, tree))
		die("Failed to parse tree");

	init_tree_desc(&desc, tree->buffer, tree->size);

	while (tree_entry(&desc, &entry)) {
		if (retval != all_entries_interesting) {
			retval = tree_entry_interesting(r->index, &entry,
							base, 0, pathspec);
			if (retval == all_entries_not_interesting)
				break;
			if (retval == entry_not_interesting)
				continue;
		}

		switch (fn(r, &entry.oid, base,
			   entry.path, entry.mode, context)) {
		case 0:
			continue;
		case READ_TREE_RECURSIVE:
			break;
		default:
			return -1;
		}

		if (S_ISDIR(entry.mode)) {
			oidcpy(&oid, &entry.oid);
			len = tree_entry_len(&entry);
			strbuf_add(base, entry.path, len);
			strbuf_addch(base, '/');
			retval = read_tree_at(r, lookup_tree(r, &oid),
						base, pathspec,
						fn, context);
			strbuf_setlen(base, oldlen);
			if (retval)
				return -1;
		} else if (pathspec->recurse_submodules && S_ISGITLINK(entry.mode)) {
			struct commit *commit;
			struct repository subrepo;
			struct repository* subrepo_p = &subrepo;
			struct tree* submodule_tree;

			if (repo_submodule_init(subrepo_p, r, entry.path, null_oid()))
				die("couldn't init submodule %s%s", base->buf, entry.path);

			if (repo_read_index(subrepo_p) < 0)
				die("index file corrupt");

			commit = lookup_commit(subrepo_p, &entry.oid);
			if (!commit)
				die("Commit %s in submodule path %s%s not found",
				    oid_to_hex(&entry.oid),
				    base->buf, entry.path);

			if (repo_parse_commit(subrepo_p, commit))
				die("Invalid commit %s in submodule path %s%s",
				    oid_to_hex(&entry.oid),
				    base->buf, entry.path);

			submodule_tree = repo_get_commit_tree(subrepo_p, commit);
			oidcpy(&oid, submodule_tree ? &submodule_tree->object.oid : NULL);

			len = tree_entry_len(&entry);
			strbuf_add(base, entry.path, len);
			strbuf_addch(base, '/');
			retval = read_tree_at(subrepo_p, lookup_tree(subrepo_p, &oid),
						base, pathspec,
						fn, context);
			if (retval) {
			    die("failed to read tree for %s%s", base->buf, entry.path);
			    return -1;
			}
			strbuf_setlen(base, oldlen);
			repo_clear(subrepo_p);
		}

	}
	return 0;
}

int read_tree(struct repository *r,
	      struct tree *tree,
	      const struct pathspec *pathspec,
	      read_tree_fn_t fn, void *context)
{
	struct strbuf sb = STRBUF_INIT;
	int ret = read_tree_at(r, tree, &sb, pathspec, fn, context);
	strbuf_release(&sb);
	return ret;
}

int cmp_cache_name_compare(const void *a_, const void *b_)
{
	const struct cache_entry *ce1, *ce2;

	ce1 = *((const struct cache_entry **)a_);
	ce2 = *((const struct cache_entry **)b_);
	return cache_name_stage_compare(ce1->name, ce1->ce_namelen, ce_stage(ce1),
				  ce2->name, ce2->ce_namelen, ce_stage(ce2));
}

struct tree *lookup_tree(struct repository *r, const struct object_id *oid)
{
	struct object *obj = lookup_object(r, oid);
	if (!obj)
		return create_object(r, oid, alloc_tree_node(r));
	return object_as_type(obj, OBJ_TREE, 0);
}

int parse_tree_buffer(struct tree *item, void *buffer, unsigned long size)
{
	if (item->object.parsed)
		return 0;
	item->object.parsed = 1;
	item->buffer = buffer;
	item->size = size;

	return 0;
}

int parse_tree_gently(struct repository *r, struct tree *item, int quiet_on_missing)
{
	 enum object_type type;
	 void *buffer;
	 unsigned long size;

	if (item->object.parsed)
		return 0;
	buffer = repo_read_object_file(r, &item->object.oid, &type, &size);
	if (!buffer)
		return quiet_on_missing ? -1 :
			error("Could not read %s",
			     oid_to_hex(&item->object.oid));
	if (type != OBJ_TREE) {
		free(buffer);
		return error("Object %s not a tree",
			     oid_to_hex(&item->object.oid));
	}
	return parse_tree_buffer(item, buffer, size);
}

void free_tree_buffer(struct tree *tree)
{
	FREE_AND_NULL(tree->buffer);
	tree->size = 0;
	tree->object.parsed = 0;
}

struct tree *parse_tree_indirect(const struct object_id *oid)
{
	struct repository *r = the_repository;
	struct object *obj = parse_object(r, oid);
	return (struct tree *)repo_peel_to_type(r, NULL, 0, obj, OBJ_TREE);
}
