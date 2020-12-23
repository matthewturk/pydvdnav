from libc.stdint cimport uint16_t, uint32_t, int64_t
from .dvd_types cimport DVDDomain_t, DVDAudioFormat_t

cdef extern from "dvdnav_events.h":
    enum:
        DVDNAV_BLOCK_OK
        DVDNAV_NOP
        DVDNAV_STILL_FRAME
        DVDNAV_SPU_STREAM_CHANGE
        DVDNAV_AUDIO_STREAM_CHANGE
        DVDNAV_VTS_CHANGE
        DVDNAV_CELL_CHANGE
        DVDNAV_NAV_PACKET
        DVDNAV_STOP
        DVDNAV_HIGHLIGHT
        DVDNAV_SPU_CLUT_CHANGE
        DVDNAV_HOP_CHANNEL
        DVDNAV_WAIT

    ctypedef struct dvdnav_still_event_t:
        int length

    ctypedef struct dvdnav_spu_stream_change_event_t:
        int physical_wide
        int physical_letterbox
        int physical_pan_scan
        int logical

    ctypedef struct dvdnav_audio_stream_change_event_t:
        int physical
        int logical

    ctypedef struct dvdnav_vts_change_event_t:
        int old_vtsN
        DVDDomain_t old_domain
        int new_vtsN
        DVDDomain_t new_domain

    ctypedef struct dvdnav_cell_change_event_t:
        int cellN
        int pgN
        int64_t cell_length
        int64_t pg_length
        int64_t pgc_length
        int64_t cell_start
        int64_t pg_start

    ctypedef struct dvdnav_highlight_event_t:
        int display
        uint32_t palette
        uint16_t sx, sy, ex, ey
        uint32_t pts
        uint32_t buttonN
