#include <odin_memory.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>
#include <stdio.h>

#define MIN(a,b) (((a)<(b))?(a):(b))
#define strnLIMIT 32756

const size_t malloc_header_size = 2*(sizeof(size_t));
const size_t malloc_unique_header = 0xCAFEBEBEUL;

static size_t *get_ptr_magic_number(void *in)
{
	if(!in)
		return NULL;

	size_t *ptr = (size_t*)in;
	ptr -= 2;
	return ptr;
}

static void set_ptr_magic_number(void *in)
{
	if(!in)
		return;

	size_t *ptr = (size_t*)in;
	ptr -= 2;
	*ptr = malloc_unique_header;
}

static bool is_odin_ptr(void* in)
{
	size_t *magic_number_ptr = get_ptr_magic_number(in);
	bool is_valid_ptr = (
		NULL != magic_number_ptr 
		&& malloc_unique_header == (*magic_number_ptr)
	);
	return is_valid_ptr;
}

static size_t get_ptr_size(void *in)
{
	if(!(is_odin_ptr(in)))
		return 0;

	size_t *ptr = (size_t*)in;
	ptr -= 1;
	return (*ptr);
}

static void set_ptr_size(void *in, size_t n_bytes)
{
	if(!(is_odin_ptr(in)))
		return;

	size_t *ptr = (size_t*)in;
	ptr -= 1;
	(*ptr) = n_bytes;
}

/*-----------------------------------------------------------------------
 * (function: my_malloc_struct )
 *-----------------------------------------------------------------*/
void *odin_alloc(size_t n_byte)
{
	void *allocated = malloc( n_byte + malloc_header_size );
	if(allocated == NULL)
	{
		fprintf(stderr,"MEMORY FAILURE\n");
		assert (0);
	}

	memset(allocated, 0, n_byte);

	size_t *temp_ptr = (size_t*)allocated;
	temp_ptr += 2;
	allocated = (void*)temp_ptr;
	set_ptr_magic_number(allocated);
	set_ptr_size(allocated, n_byte);
	return allocated;
}

/*-----------------------------------------------------------------------
 * (function: my_malloc_struct )
 *-----------------------------------------------------------------*/
void *odin_calloc(size_t n_elements, size_t element_size)
{
	return odin_alloc(n_elements * element_size);
}

/*-----------------------------------------------------------------------
 * (function: my_malloc_struct )
 *-----------------------------------------------------------------*/
void *odin_realloc(void *to_rellocate, size_t n_bytes)
{
	void *new_space = odin_alloc(n_bytes);
	size_t previous_size = get_ptr_size(to_rellocate);
	if(previous_size != 0)
	{
		size_t copy_size = MIN(n_bytes, previous_size);
		memcpy(new_space, to_rellocate, copy_size);
		odin_free(to_rellocate);
	}
	to_rellocate = new_space;
	return new_space;
}

/*-----------------------------------------------------------------------
 * (function: my_malloc_struct )
 *-----------------------------------------------------------------*/
void *odin_free(void *to_free)
{
	if(is_odin_ptr(to_free))
	{
		size_t *ptr = (size_t*)to_free;
		ptr -= 2;
		free(ptr);
	}
	to_free = NULL;
	return to_free;
}

char *odin_strdup(const char *str)
{
	if(!str)
		return NULL;

	size_t str_size = strnlen(str, strnLIMIT);
	char *new_str = (char*)odin_calloc(str_size, sizeof(char));
	memcpy(new_str, str, str_size);
	return new_str;
}