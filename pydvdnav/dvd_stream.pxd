from libc.stdio cimport FILE, fopen, fwrite, fclose
from libc.stdint cimport uint8_t
from .dvd_types cimport *
from .dvdnav_events cimport *
from .dvdnav cimport *

cdef class DVDStream:
    cdef dvdnav_t *dvdnav
    cdef uint8_t last_block[DVD_VIDEO_LB_LEN]
    cdef uint8_t *buf
    cdef FILE *outstream
    cdef int cache

cdef class DVDStreamEvent:
    cdef public object event_type
    cdef public uint32_t position
    cdef public uint32_t length
    cdef public uint32_t title
    cdef public uint32_t chapter

cdef class ButtonLocations:
    pass
