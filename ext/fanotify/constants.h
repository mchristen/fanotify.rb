/* Linux UAPI constants; availability follows the build headers. */
#ifdef FAN_ACCESS
    rb_define_const(mod, "FAN_ACCESS", ULL2NUM(FAN_ACCESS));
#endif
#ifdef FAN_MODIFY
    rb_define_const(mod, "FAN_MODIFY", ULL2NUM(FAN_MODIFY));
#endif
#ifdef FAN_ATTRIB
    rb_define_const(mod, "FAN_ATTRIB", ULL2NUM(FAN_ATTRIB));
#endif
#ifdef FAN_CLOSE_WRITE
    rb_define_const(mod, "FAN_CLOSE_WRITE", ULL2NUM(FAN_CLOSE_WRITE));
#endif
#ifdef FAN_CLOSE_NOWRITE
    rb_define_const(mod, "FAN_CLOSE_NOWRITE", ULL2NUM(FAN_CLOSE_NOWRITE));
#endif
#ifdef FAN_OPEN
    rb_define_const(mod, "FAN_OPEN", ULL2NUM(FAN_OPEN));
#endif
#ifdef FAN_MOVED_FROM
    rb_define_const(mod, "FAN_MOVED_FROM", ULL2NUM(FAN_MOVED_FROM));
#endif
#ifdef FAN_MOVED_TO
    rb_define_const(mod, "FAN_MOVED_TO", ULL2NUM(FAN_MOVED_TO));
#endif
#ifdef FAN_CREATE
    rb_define_const(mod, "FAN_CREATE", ULL2NUM(FAN_CREATE));
#endif
#ifdef FAN_DELETE
    rb_define_const(mod, "FAN_DELETE", ULL2NUM(FAN_DELETE));
#endif
#ifdef FAN_DELETE_SELF
    rb_define_const(mod, "FAN_DELETE_SELF", ULL2NUM(FAN_DELETE_SELF));
#endif
#ifdef FAN_MOVE_SELF
    rb_define_const(mod, "FAN_MOVE_SELF", ULL2NUM(FAN_MOVE_SELF));
#endif
#ifdef FAN_OPEN_EXEC
    rb_define_const(mod, "FAN_OPEN_EXEC", ULL2NUM(FAN_OPEN_EXEC));
#endif
#ifdef FAN_Q_OVERFLOW
    rb_define_const(mod, "FAN_Q_OVERFLOW", ULL2NUM(FAN_Q_OVERFLOW));
#endif
#ifdef FAN_FS_ERROR
    rb_define_const(mod, "FAN_FS_ERROR", ULL2NUM(FAN_FS_ERROR));
#endif
#ifdef FAN_OPEN_PERM
    rb_define_const(mod, "FAN_OPEN_PERM", ULL2NUM(FAN_OPEN_PERM));
#endif
#ifdef FAN_ACCESS_PERM
    rb_define_const(mod, "FAN_ACCESS_PERM", ULL2NUM(FAN_ACCESS_PERM));
#endif
#ifdef FAN_OPEN_EXEC_PERM
    rb_define_const(mod, "FAN_OPEN_EXEC_PERM", ULL2NUM(FAN_OPEN_EXEC_PERM));
#endif
#ifdef FAN_PRE_ACCESS
    rb_define_const(mod, "FAN_PRE_ACCESS", ULL2NUM(FAN_PRE_ACCESS));
#endif
#ifdef FAN_MNT_ATTACH
    rb_define_const(mod, "FAN_MNT_ATTACH", ULL2NUM(FAN_MNT_ATTACH));
#endif
#ifdef FAN_MNT_DETACH
    rb_define_const(mod, "FAN_MNT_DETACH", ULL2NUM(FAN_MNT_DETACH));
#endif
#ifdef FAN_EVENT_ON_CHILD
    rb_define_const(mod, "FAN_EVENT_ON_CHILD", ULL2NUM(FAN_EVENT_ON_CHILD));
#endif
#ifdef FAN_RENAME
    rb_define_const(mod, "FAN_RENAME", ULL2NUM(FAN_RENAME));
#endif
#ifdef FAN_ONDIR
    rb_define_const(mod, "FAN_ONDIR", ULL2NUM(FAN_ONDIR));
#endif
#ifdef FAN_CLOSE
    rb_define_const(mod, "FAN_CLOSE", ULL2NUM(FAN_CLOSE));
#endif
#ifdef FAN_MOVE
    rb_define_const(mod, "FAN_MOVE", ULL2NUM(FAN_MOVE));
#endif
#ifdef FAN_CLOEXEC
    rb_define_const(mod, "FAN_CLOEXEC", ULL2NUM(FAN_CLOEXEC));
#endif
#ifdef FAN_NONBLOCK
    rb_define_const(mod, "FAN_NONBLOCK", ULL2NUM(FAN_NONBLOCK));
#endif
#ifdef FAN_CLASS_NOTIF
    rb_define_const(mod, "FAN_CLASS_NOTIF", ULL2NUM(FAN_CLASS_NOTIF));
#endif
#ifdef FAN_CLASS_CONTENT
    rb_define_const(mod, "FAN_CLASS_CONTENT", ULL2NUM(FAN_CLASS_CONTENT));
#endif
#ifdef FAN_CLASS_PRE_CONTENT
    rb_define_const(mod, "FAN_CLASS_PRE_CONTENT", ULL2NUM(FAN_CLASS_PRE_CONTENT));
#endif
#ifdef FAN_ALL_CLASS_BITS
    rb_define_const(mod, "FAN_ALL_CLASS_BITS", ULL2NUM(FAN_ALL_CLASS_BITS));
#endif
#ifdef FAN_UNLIMITED_QUEUE
    rb_define_const(mod, "FAN_UNLIMITED_QUEUE", ULL2NUM(FAN_UNLIMITED_QUEUE));
#endif
#ifdef FAN_UNLIMITED_MARKS
    rb_define_const(mod, "FAN_UNLIMITED_MARKS", ULL2NUM(FAN_UNLIMITED_MARKS));
#endif
#ifdef FAN_ENABLE_AUDIT
    rb_define_const(mod, "FAN_ENABLE_AUDIT", ULL2NUM(FAN_ENABLE_AUDIT));
#endif
#ifdef FAN_REPORT_PIDFD
    rb_define_const(mod, "FAN_REPORT_PIDFD", ULL2NUM(FAN_REPORT_PIDFD));
#endif
#ifdef FAN_REPORT_TID
    rb_define_const(mod, "FAN_REPORT_TID", ULL2NUM(FAN_REPORT_TID));
#endif
#ifdef FAN_REPORT_FID
    rb_define_const(mod, "FAN_REPORT_FID", ULL2NUM(FAN_REPORT_FID));
#endif
#ifdef FAN_REPORT_DIR_FID
    rb_define_const(mod, "FAN_REPORT_DIR_FID", ULL2NUM(FAN_REPORT_DIR_FID));
#endif
#ifdef FAN_REPORT_NAME
    rb_define_const(mod, "FAN_REPORT_NAME", ULL2NUM(FAN_REPORT_NAME));
#endif
#ifdef FAN_REPORT_TARGET_FID
    rb_define_const(mod, "FAN_REPORT_TARGET_FID", ULL2NUM(FAN_REPORT_TARGET_FID));
#endif
#ifdef FAN_REPORT_FD_ERROR
    rb_define_const(mod, "FAN_REPORT_FD_ERROR", ULL2NUM(FAN_REPORT_FD_ERROR));
#endif
#ifdef FAN_REPORT_MNT
    rb_define_const(mod, "FAN_REPORT_MNT", ULL2NUM(FAN_REPORT_MNT));
#endif
#ifdef FAN_REPORT_DFID_NAME
    rb_define_const(mod, "FAN_REPORT_DFID_NAME", ULL2NUM(FAN_REPORT_DFID_NAME));
#endif
#ifdef FAN_REPORT_DFID_NAME_TARGET
    rb_define_const(mod, "FAN_REPORT_DFID_NAME_TARGET", ULL2NUM(FAN_REPORT_DFID_NAME_TARGET));
#endif
#ifdef FAN_ALL_INIT_FLAGS
    rb_define_const(mod, "FAN_ALL_INIT_FLAGS", ULL2NUM(FAN_ALL_INIT_FLAGS));
#endif
#ifdef FAN_MARK_ADD
    rb_define_const(mod, "FAN_MARK_ADD", ULL2NUM(FAN_MARK_ADD));
#endif
#ifdef FAN_MARK_REMOVE
    rb_define_const(mod, "FAN_MARK_REMOVE", ULL2NUM(FAN_MARK_REMOVE));
#endif
#ifdef FAN_MARK_DONT_FOLLOW
    rb_define_const(mod, "FAN_MARK_DONT_FOLLOW", ULL2NUM(FAN_MARK_DONT_FOLLOW));
#endif
#ifdef FAN_MARK_ONLYDIR
    rb_define_const(mod, "FAN_MARK_ONLYDIR", ULL2NUM(FAN_MARK_ONLYDIR));
#endif
#ifdef FAN_MARK_IGNORED_MASK
    rb_define_const(mod, "FAN_MARK_IGNORED_MASK", ULL2NUM(FAN_MARK_IGNORED_MASK));
#endif
#ifdef FAN_MARK_IGNORED_SURV_MODIFY
    rb_define_const(mod, "FAN_MARK_IGNORED_SURV_MODIFY", ULL2NUM(FAN_MARK_IGNORED_SURV_MODIFY));
#endif
#ifdef FAN_MARK_FLUSH
    rb_define_const(mod, "FAN_MARK_FLUSH", ULL2NUM(FAN_MARK_FLUSH));
#endif
#ifdef FAN_MARK_EVICTABLE
    rb_define_const(mod, "FAN_MARK_EVICTABLE", ULL2NUM(FAN_MARK_EVICTABLE));
#endif
#ifdef FAN_MARK_IGNORE
    rb_define_const(mod, "FAN_MARK_IGNORE", ULL2NUM(FAN_MARK_IGNORE));
#endif
#ifdef FAN_MARK_INODE
    rb_define_const(mod, "FAN_MARK_INODE", ULL2NUM(FAN_MARK_INODE));
#endif
#ifdef FAN_MARK_MOUNT
    rb_define_const(mod, "FAN_MARK_MOUNT", ULL2NUM(FAN_MARK_MOUNT));
#endif
#ifdef FAN_MARK_FILESYSTEM
    rb_define_const(mod, "FAN_MARK_FILESYSTEM", ULL2NUM(FAN_MARK_FILESYSTEM));
#endif
#ifdef FAN_MARK_MNTNS
    rb_define_const(mod, "FAN_MARK_MNTNS", ULL2NUM(FAN_MARK_MNTNS));
#endif
#ifdef FAN_MARK_IGNORE_SURV
    rb_define_const(mod, "FAN_MARK_IGNORE_SURV", ULL2NUM(FAN_MARK_IGNORE_SURV));
#endif
#ifdef FAN_ALL_MARK_FLAGS
    rb_define_const(mod, "FAN_ALL_MARK_FLAGS", ULL2NUM(FAN_ALL_MARK_FLAGS));
#endif
#ifdef FAN_ALL_EVENTS
    rb_define_const(mod, "FAN_ALL_EVENTS", ULL2NUM(FAN_ALL_EVENTS));
#endif
#ifdef FAN_ALL_PERM_EVENTS
    rb_define_const(mod, "FAN_ALL_PERM_EVENTS", ULL2NUM(FAN_ALL_PERM_EVENTS));
#endif
#ifdef FAN_ALL_OUTGOING_EVENTS
    rb_define_const(mod, "FAN_ALL_OUTGOING_EVENTS", ULL2NUM(FAN_ALL_OUTGOING_EVENTS));
#endif
#ifdef FANOTIFY_METADATA_VERSION
    rb_define_const(mod, "FANOTIFY_METADATA_VERSION", ULL2NUM(FANOTIFY_METADATA_VERSION));
#endif
#ifdef FAN_EVENT_INFO_TYPE_FID
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_FID", ULL2NUM(FAN_EVENT_INFO_TYPE_FID));
#endif
#ifdef FAN_EVENT_INFO_TYPE_DFID_NAME
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_DFID_NAME", ULL2NUM(FAN_EVENT_INFO_TYPE_DFID_NAME));
#endif
#ifdef FAN_EVENT_INFO_TYPE_DFID
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_DFID", ULL2NUM(FAN_EVENT_INFO_TYPE_DFID));
#endif
#ifdef FAN_EVENT_INFO_TYPE_PIDFD
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_PIDFD", ULL2NUM(FAN_EVENT_INFO_TYPE_PIDFD));
#endif
#ifdef FAN_EVENT_INFO_TYPE_ERROR
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_ERROR", ULL2NUM(FAN_EVENT_INFO_TYPE_ERROR));
#endif
#ifdef FAN_EVENT_INFO_TYPE_RANGE
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_RANGE", ULL2NUM(FAN_EVENT_INFO_TYPE_RANGE));
#endif
#ifdef FAN_EVENT_INFO_TYPE_MNT
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_MNT", ULL2NUM(FAN_EVENT_INFO_TYPE_MNT));
#endif
#ifdef FAN_EVENT_INFO_TYPE_OLD_DFID_NAME
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_OLD_DFID_NAME", ULL2NUM(FAN_EVENT_INFO_TYPE_OLD_DFID_NAME));
#endif
#ifdef FAN_EVENT_INFO_TYPE_NEW_DFID_NAME
    rb_define_const(mod, "FAN_EVENT_INFO_TYPE_NEW_DFID_NAME", ULL2NUM(FAN_EVENT_INFO_TYPE_NEW_DFID_NAME));
#endif
#ifdef FAN_RESPONSE_INFO_NONE
    rb_define_const(mod, "FAN_RESPONSE_INFO_NONE", ULL2NUM(FAN_RESPONSE_INFO_NONE));
#endif
#ifdef FAN_RESPONSE_INFO_AUDIT_RULE
    rb_define_const(mod, "FAN_RESPONSE_INFO_AUDIT_RULE", ULL2NUM(FAN_RESPONSE_INFO_AUDIT_RULE));
#endif
#ifdef FAN_ALLOW
    rb_define_const(mod, "FAN_ALLOW", ULL2NUM(FAN_ALLOW));
#endif
#ifdef FAN_DENY
    rb_define_const(mod, "FAN_DENY", ULL2NUM(FAN_DENY));
#endif
#ifdef FAN_ERRNO_BITS
    rb_define_const(mod, "FAN_ERRNO_BITS", ULL2NUM(FAN_ERRNO_BITS));
#endif
#ifdef FAN_ERRNO_SHIFT
    rb_define_const(mod, "FAN_ERRNO_SHIFT", ULL2NUM(FAN_ERRNO_SHIFT));
#endif
#ifdef FAN_ERRNO_MASK
    rb_define_const(mod, "FAN_ERRNO_MASK", ULL2NUM(FAN_ERRNO_MASK));
#endif
#ifdef FAN_AUDIT
    rb_define_const(mod, "FAN_AUDIT", ULL2NUM(FAN_AUDIT));
#endif
#ifdef FAN_INFO
    rb_define_const(mod, "FAN_INFO", ULL2NUM(FAN_INFO));
#endif
#ifdef FAN_NOFD
    rb_define_const(mod, "FAN_NOFD", INT2NUM(FAN_NOFD));
#endif
#ifdef FAN_NOPIDFD
    rb_define_const(mod, "FAN_NOPIDFD", INT2NUM(FAN_NOPIDFD));
#endif
#ifdef FAN_EPIDFD
    rb_define_const(mod, "FAN_EPIDFD", INT2NUM(FAN_EPIDFD));
#endif
#ifdef FAN_EVENT_METADATA_LEN
    rb_define_const(mod, "FAN_EVENT_METADATA_LEN", ULL2NUM(FAN_EVENT_METADATA_LEN));
#endif
