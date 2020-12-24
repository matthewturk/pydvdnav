# cython: language_level = 3
# distutils: libraries = dvdnav

from .dvd_types cimport *
from .dvdnav_events cimport *
from .dvdnav cimport *

from libc.stdio cimport FILE, fopen, fwrite, fclose

DEF DVD_READ_CACHE = 1
DEF DVD_LANGUAGE = b"en"

import numpy as np


def walkit(device_name = "/dev/dvd"):
    cdef dvdnav_t *dvdnav
    cdef FILE *output = NULL
    if dvdnav_open(&dvdnav, device_name.encode()) != DVDNAV_STATUS_OK:
        print("Error on dvdnav_open!")
        return 1

    if dvdnav_set_readahead_flag(dvdnav, DVD_READ_CACHE) != DVDNAV_STATUS_OK:
        print("Error on dvdnav_set_readahead_flag")
        return 2

    if dvdnav_menu_language_select(dvdnav, DVD_LANGUAGE) != DVDNAV_STATUS_OK or \
       dvdnav_audio_language_select(dvdnav, DVD_LANGUAGE) != DVDNAV_STATUS_OK or \
       dvdnav_spu_language_select(dvdnav, DVD_LANGUAGE) != DVDNAV_STATUS_OK:
        print("Error on setting languages: %s\n" % dvdnav_err_to_string(dvdnav))
        return 2

    if dvdnav_set_PGC_positioning_flag(dvdnav, 1) != DVDNAV_STATUS_OK:
        print("Error on dvdnav_set_PGC_positioning_flag: %s\n" % dvdnav_err_to_string(dvdnav))
        return 2

    cdef int finished = 0
    cdef int32_t result, event, length
    cdef uint8_t mem[DVD_VIDEO_LB_LEN]
    cdef uint8_t *buf = mem
    cdef int32_t tt = 0, ptt = 0
    cdef uint32_t pos, length2
    cdef dvdnav_still_event_t *still_event
    cdef dvdnav_highlight_event_t *highlight_event
    cdef pci_t *pci
    cdef int button
    cdef btni_t *btni
    cdef int dump = 0, tt_dump = 0


    print("Reading ...")

    while not finished:
        if DVD_READ_CACHE:
            result = dvdnav_get_next_cache_block(dvdnav, &buf, &event, &length)
        else:
            result = dvdnav_get_next_block(dvdnav, buf, &event, &length)

        if result == DVDNAV_STATUS_ERR:
            print("Error getting next block: %s" % dvdnav_err_to_string(dvdnav))
            return 3

        if event == DVDNAV_BLOCK_OK:
            if output == NULL:
                output = fopen("output.mpg", 'w')
            if dump == 1 or tt_dump == 1:
                print("Writing", length)
                fwrite(buf, sizeof(uint8_t), length, output)

        elif event == DVDNAV_NOP:
            print("DVDNAV_NOP")
        elif event == DVDNAV_STILL_FRAME:
            print("DVDNAV_STILL_FRAME")
            still_event = <dvdnav_still_event_t*> buf
            if still_event.length < 0xff:
                print("Skipping %d seconds of still frame" % still_event.length)
            else:
                print("Skipping indefinite length still frame")
            dvdnav_still_skip(dvdnav)
        elif event == DVDNAV_WAIT:
            print("DVDNAV_WAIT")
            print("Skipping wait condition")
            dvdnav_wait_skip(dvdnav)
        elif event == DVDNAV_SPU_CLUT_CHANGE:
            print("DVDNAV_SPU_CLUT_CHANGE")
        elif event == DVDNAV_SPU_STREAM_CHANGE:
            print("DVDNAV_SPU_STREAM_CHANGE")
        elif event == DVDNAV_AUDIO_STREAM_CHANGE:
            print("DVDNAV_AUDIO_STREAM_CHANGE")
        elif event == DVDNAV_HIGHLIGHT:
            print("DVDNAV_HIGHLIGHT")
            highlight_event = <dvdnav_highlight_event_t *> buf
            print("Selected button %d" % highlight_event.buttonN)
        elif event == DVDNAV_VTS_CHANGE:
            print("DVDNAV_VTS_CHANGE")
        elif event == DVDNAV_CELL_CHANGE:
            print("DVDNAV_CELL_CHANGE")

            dvdnav_current_title_info(dvdnav, &tt, &ptt)
            dvdnav_get_position(dvdnav, &pos, &length2)
            print("Cell change: Title %d, Chapter %d" % (tt, ptt))
            print("At position %s of %s inside the feature" % (pos, length2))
            dump = 0
            if (tt_dump and tt != tt_dump):
                tt_dump = 0
            if dump == 0 and tt_dump == 0:
                response = 'X'
                while response not in 'astq':
                    response = input("(a)ppend cell to output\n(s)kip cell\nappend until end of (t)itle\n(q)uit")
                if response == 'a':
                    dump = 1
                elif response == 't':
                    tt_dump = tt
                elif response == 'q':
                    finished = 1

        elif event == DVDNAV_NAV_PACKET:
            pci = dvdnav_get_current_nav_pci(dvdnav)
            if pci.hli.hl_gi.btn_ns > 0:
                print("Found %s DVD menu buttons..." % pci.hli.hl_gi.btn_ns)
                for button in range(pci.hli.hl_gi.btn_ns):
                    btni = &(pci.hli.btnit[button])
                    print("Button %d top-left @ (%d, %d), bottom-right @ (%d, %d)" % (
                        button + 1, btni.x_start, btni.y_start, btni.x_end, btni.y_end))
                finished = 1
        elif event == DVDNAV_HOP_CHANNEL:
            print("DVDNAV_HOP_CHANNEL")

        elif event == DVDNAV_STOP:
            finished = 1

        else:
            print("UNKNOWN EVENT", event)
            finished = 1

    if output != NULL:
        fclose(output)
    if DVD_READ_CACHE:
        dvdnav_free_cache_block(dvdnav, buf)
    if dvdnav_close(dvdnav) != DVDNAV_STATUS_OK:
        print("Error on dvdnav_close: %s" % dvdnav_err_to_string(dvdnav))
        return 5

    return 0

