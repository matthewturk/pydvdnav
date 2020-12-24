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

cdef class DVDStreamEventHighlight(DVDStreamEvent):
    cdef public int display
    cdef public uint32_t palette
    cdef public uint16_t sx, sy, ex, ey
    cdef public uint32_t pts
    cdef public uint32_t buttonN

cdef class DVDStreamEventNavigation(DVDStreamEvent):
    cdef pci_t *pci
    cdef public dict button_info
