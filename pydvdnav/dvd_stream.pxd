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

cdef class Event:
    cdef public object event_type
    cdef public uint32_t position
    cdef public uint32_t length
    cdef public uint32_t title
    cdef public uint32_t chapter

cdef class NavigationEvent(Event):
    cdef pci_t *pci
    cdef public dict button_info

cdef class StillEvent(Event):
    cdef public int still_length

cdef class SPUStreamChangeEvent(Event):
    cdef public int physical_wide
    cdef public int physical_letterbox
    cdef public int physical_pan_scan
    cdef public int logical

cdef class AudioStreamChangeEvent(Event):
    cdef public int physical
    cdef public int logical

cdef class VTSChangeEvent(Event):
    cdef public int old_vtsN
    cdef public int old_domain
    cdef public int new_vtsN
    cdef public int new_domain

cdef class CellChangeEvent(Event):
    cdef public int cellN
    cdef public int pgN
    cdef public int64_t cell_length
    cdef public int64_t pg_length
    cdef public int64_t pgc_length
    cdef public int64_t cell_start
    cdef public int64_t pg_start

cdef class HighlightEvent(Event):
    cdef public int display
    cdef public uint32_t palette
    cdef public uint16_t sx, sy, ex, ey
    cdef public uint32_t pts
    cdef public uint32_t buttonN

