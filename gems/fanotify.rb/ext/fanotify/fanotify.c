#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include <ruby.h>
#include <fcntl.h>
#include <stdint.h>
#include <stddef.h>
#include <sys/fanotify.h>

/* Fanotify.init(flags, event_f_flags) -> Integer file descriptor */
static VALUE
fanotify_rb_init(VALUE self, VALUE flags, VALUE event_f_flags)
{
    unsigned int c_flags = NUM2UINT(flags);
    unsigned int c_event_f_flags = NUM2UINT(event_f_flags);
    int fd = fanotify_init(c_flags, c_event_f_flags);

    if (fd == -1)
        rb_sys_fail("fanotify_init");

    return INT2NUM(fd);
}

/* Fanotify.mark(fanotify_fd, flags, mask, dirfd, pathname) -> 0 */
static VALUE
fanotify_rb_mark(VALUE self, VALUE fanotify_fd, VALUE flags, VALUE mask,
                 VALUE dirfd, VALUE pathname)
{
    int c_fd = NUM2INT(fanotify_fd);
    unsigned int c_flags = NUM2UINT(flags);
    uint64_t c_mask = NUM2ULL(mask);
    int c_dirfd = NUM2INT(dirfd);
    const char *c_path = NULL;
    int result;

    if (!NIL_P(pathname)) {
        pathname = rb_get_path(pathname);
        c_path = StringValueCStr(pathname);
    }

    result = fanotify_mark(c_fd, c_flags, c_mask, c_dirfd, c_path);
    RB_GC_GUARD(pathname);

    if (result == -1)
        rb_sys_fail("fanotify_mark");

    return INT2NUM(result);
}

/* name_to_handle_at(dirfd, pathname, flags) -> [mount_id, handle_type, bytes] */
static VALUE
fanotify_rb_name_to_handle_at(VALUE self, VALUE dirfd, VALUE pathname, VALUE flags)
{
    int c_dirfd = NUM2INT(dirfd);
    int c_flags = NUM2INT(flags);
    /* AT_HANDLE_MNT_ID_UNIQUE (Linux UAPI bit 0x001) makes this output
     * 64-bit, even when libc headers predate that flag. */
    union { int legacy; uint64_t unique; } mount_id = {0};
    int type;
    unsigned int length;
    VALUE storage;
    struct file_handle *handle;
    VALUE bytes;

    pathname = rb_get_path(pathname);
    StringValueCStr(pathname);
    storage = rb_str_new(NULL, sizeof(struct file_handle) + MAX_HANDLE_SZ);
    handle = (struct file_handle *)RSTRING_PTR(storage);
    handle->handle_bytes = MAX_HANDLE_SZ;
    if (name_to_handle_at(c_dirfd, RSTRING_PTR(pathname), handle, &mount_id.legacy, c_flags) == -1)
        rb_sys_fail("name_to_handle_at");

    type = handle->handle_type;
    length = handle->handle_bytes;
    bytes = rb_str_substr(storage, offsetof(struct file_handle, f_handle), length);
    RB_GC_GUARD(storage);
    RB_GC_GUARD(pathname);
    return rb_ary_new_from_args(3,
        (c_flags & 0x001) ? ULL2NUM(mount_id.unique) : INT2NUM(mount_id.legacy),
        INT2NUM(type), bytes);
}

RUBY_FUNC_EXPORTED void
Init_fanotify(void)
{
    VALUE mod = rb_define_module("Fanotify");

    rb_define_singleton_method(mod, "init", fanotify_rb_init, 2);
    rb_define_singleton_method(mod, "mark", fanotify_rb_mark, 5);
    rb_define_singleton_method(mod, "name_to_handle_at", fanotify_rb_name_to_handle_at, 3);

    rb_define_const(mod, "AT_FDCWD", INT2NUM(AT_FDCWD));
#ifdef AT_HANDLE_FID
    rb_define_const(mod, "AT_HANDLE_FID", INT2NUM(AT_HANDLE_FID));
#endif
#include "constants.h"
}
