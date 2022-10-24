@@
type T;
T *ptr;
@@
- ptr = xcalloc(1, \( sizeof(T) \| sizeof(*ptr) \) )
+ T ptr
+ CALLOC(ptr)
