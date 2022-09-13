#include "builtin.h"
#include "repository.h"
#include "fuzz-cmd-base.h"

int cmd_status(int argc, const char **argv, const char *prefix);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
   int no_of_commit;
   int max_commit_count;
   char *argv[2];
   char *data_chunk;
   char *basedir = "./.git";

   /*
    *  Initialize the repository
    */
   initialize_the_repository();

   max_commit_count = get_max_commit_count(size, 0, HASH_SIZE);

   /*
    * End this round of fuzzing if the data is not large enough
    */
   if (size <= (HASH_SIZE * 2 + 4)) {
      repo_clear(the_repository);
      return 0;
   }

   if (reset_git_folder()) {
      repo_clear(the_repository);
      return 0;
   }

   /*
    * Generate random commit
    */
   no_of_commit = (*((int *)data)) % max_commit_count + 1;
   data += 4;
   size -= 4;

   for (int i=0; i<no_of_commit; i++) {
      data_chunk = malloc(HASH_SIZE * 2);
      memcpy(data_chunk, data, HASH_SIZE * 2);
      generate_commit(data_chunk, HASH_SIZE);
      data += (HASH_SIZE * 2);
      size -= (HASH_SIZE * 2);
      free(data_chunk);
   }

   /*
    * Final preparing of the repository settings
    */
   repo_clear(the_repository);
   repo_init(the_repository, basedir, ".");

   /*
    * Calling target git command
    */
   argv[0] = "status";
   argv[1] = "-v";
   cmd_status(2, (const char **)argv, (const char *)"");

   repo_clear(the_repository);

   return 0;
}
