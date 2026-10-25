#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include <ruby.h>
#include <fcntl.h>
#include <stdint.h>
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

RUBY_FUNC_EXPORTED void
Init_fanotify(void)
{
    VALUE mod = rb_define_module("Fanotify");

    rb_define_singleton_method(mod, "init", fanotify_rb_init, 2);
    rb_define_singleton_method(mod, "mark", fanotify_rb_mark, 5);

    rb_define_const(mod, "AT_FDCWD", INT2NUM(AT_FDCWD));
#include "constants.h"
}
