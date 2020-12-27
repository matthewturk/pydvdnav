# wrapper for dvd_types.h

from libc.stdint cimport uint16_t, uint32_t

cdef extern from "dvd_types.h":
    ctypedef enum DVDMenuID_t:
        DVD_MENU_Escape     = 0
        DVD_MENU_Title      = 2
        DVD_MENU_Root       = 3
        DVD_MENU_Subpicture = 4
        DVD_MENU_Audio      = 5
        DVD_MENU_Angle      = 6
        DVD_MENU_Part       = 7

    ctypedef enum DVDDomain_t:
        DVD_DOMAIN_FirstPlay = 1
        DVD_DOMAIN_VTSTitle  = 2
        DVD_DOMAIN_VMGM      = 4
        DVD_DOMAIN_VTSMenu   = 8

    ctypedef struct dvdnav_highlight_area_t:
        uint32_t palette
        uint16_t sx
        uint16_t sy
        uint16_t ex
        uint16_t ey
        uint32_t pts
        uint32_t buttonN

    ctypedef enum DVDAudioFormat_t:
        DVD_AUDIO_FORMAT_AC3        = 0
        DVD_AUDIO_FORMAT_UNKNOWN_1  = 1
        DVD_AUDIO_FORMAT_MPEG       = 2
        DVD_AUDIO_FORMAT_MPEG2_EXT  = 3
        DVD_AUDIO_FORMAT_LPCM       = 4
        DVD_AUDIO_FORMAT_UNKNOWN_5  = 5
        DVD_AUDIO_FORMAT_DTS        = 6
        DVD_AUDIO_FORMAT_SDDS       = 7
