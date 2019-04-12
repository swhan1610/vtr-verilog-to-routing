#ifndef ODIN_MEMORY_H
#define ODIN_MEMMRY_H

#include <cstdlib>

void *odin_alloc(size_t n_byte);
void *odin_calloc(size_t n_elements, size_t element_size);
void *odin_realloc(void *to_rellocate, size_t n_bytes);
void *odin_free(void *to_free);
char *odin_strdup(const char *str);

#endif