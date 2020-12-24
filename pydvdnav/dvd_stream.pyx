# cython: language_level = 3
# distutils: libraries = dvdnav

from libc.stdint cimport uint8_t, int32_t, uint32_t
from .dvd_types cimport *
from .dvdnav_events cimport *
from .dvdnav cimport *

cdef class DVDStream:
    def __cinit__(self, device_name = "/dev/dvd", cache = True, language = "en"):
        if dvdnav_open(&self.dvdnav, device_name.encode()) != DVDNAV_STATUS_OK:
            raise RuntimeError("Error on dvdnav_open!")

        print("Setting", int(cache))
        if dvdnav_set_readahead_flag(self.dvdnav, int(cache)) != DVDNAV_STATUS_OK:
            raise RuntimeError("Error on dvdnav_set_readahead_flag (%s)" % cache)
        self.cache = int(cache)
        self.buf = self.last_block


        if dvdnav_menu_language_select(self.dvdnav, language.encode()) != DVDNAV_STATUS_OK or \
           dvdnav_audio_language_select(self.dvdnav, language.encode()) != DVDNAV_STATUS_OK or \
           dvdnav_spu_language_select(self.dvdnav, language.encode()) != DVDNAV_STATUS_OK:
            raise RuntimeError("Error on setting languages: %s\n" % dvdnav_err_to_string(self.dvdnav))

        if dvdnav_set_PGC_positioning_flag(self.dvdnav, 1) != DVDNAV_STATUS_OK:
            raise RuntimeError("Error on dvdnav_set_PGC_positioning_flag: %s\n" % dvdnav_err_to_string(self.dvdnav))

        self.outstream = NULL

    def set_outstream(self, filename, clobber = True):
        if self.outstream != NULL:
            fclose(self.outstream)
        if clobber:
            self.outstream = fopen(filename.encode(), "w")
        else:
            self.outstream = fopen(filename.encode(), "a")

    def __iter__(self):
        cdef int finished = 0
        cdef int32_t result, event, length, tt = 0, ptt = 0
        cdef uint32_t pos, length2
        cdef dvdnav_still_event_t *still_event
        cdef dvdnav_highlight_event_t *highlight_event
        cdef pci_t *pci
        cdef int button
        cdef btni_t *btni
        while not finished:
            if self.cache:
                result = dvdnav_get_next_cache_block(self.dvdnav, &self.buf, &event, &length)
            else:
                result = dvdnav_get_next_block(self.dvdnav, self.buf, &event, &length)
            if result == DVDNAV_STATUS_ERR:
                raise RuntimeError("Error getting next block: %s" %
                                   dvdnav_err_to_string(self.dvdnav))
            if event == DVDNAV_BLOCK_OK:
                if self.outstream != NULL:
                    fwrite(self.buf, sizeof(uint8_t), length, self.outstream)
            elif event == DVDNAV_NOP:
                yield DVDStreamEvent("No-Op", self)
            elif event == DVDNAV_STILL_FRAME:
                yield DVDStreamEvent("Still Frame", self)
                still_event = <dvdnav_still_event_t*> self.buf
                if still_event.length < 0xff:
                    print("Skipping %d seconds of still frame" % still_event.length)
                else:
                    print("Skipping indefinite length still frame")
                dvdnav_still_skip(self.dvdnav)
            elif event == DVDNAV_WAIT:
                yield DVDStreamEvent("Wait", self)
                print("Skipping wait condition")
                dvdnav_wait_skip(self.dvdnav)
            elif event == DVDNAV_SPU_CLUT_CHANGE:
                yield DVDStreamEvent("SPU CLUT Change", self)
            elif event == DVDNAV_SPU_STREAM_CHANGE:
                yield DVDStreamEvent("SPU Stream Change", self)
            elif event == DVDNAV_AUDIO_STREAM_CHANGE:
                yield DVDStreamEvent("Audio Stream Change", self)
            elif event == DVDNAV_HIGHLIGHT:
                yield DVDStreamEvent("Highlight", self)
                highlight_event = <dvdnav_highlight_event_t *> self.buf
                print("Selected button %d" % highlight_event.buttonN)
            elif event == DVDNAV_VTS_CHANGE:
                yield DVDStreamEvent("VTS Change", self)
            elif event == DVDNAV_CELL_CHANGE:
                dvdnav_current_title_info(self.dvdnav, &tt, &ptt)
                dvdnav_get_position(self.dvdnav, &pos, &length2)
                print("Cell change: Title %d, Chapter %d" % (tt, ptt))
                print("At position %s of %s inside the feature" % (pos, length2))
                yield DVDStreamEvent("Cell Change", self)

            elif event == DVDNAV_NAV_PACKET:
                pci = dvdnav_get_current_nav_pci(self.dvdnav)
                if pci.hli.hl_gi.btn_ns > 0:
                    print("Found %s DVD menu buttons..." % pci.hli.hl_gi.btn_ns)
                    for button in range(pci.hli.hl_gi.btn_ns):
                        btni = &(pci.hli.btnit[button])
                        print("Button %d top-left @ (%d, %d), bottom-right @ (%d, %d)" % (
                            button + 1, btni.x_start, btni.y_start, btni.x_end, btni.y_end))
                    finished = 1
            elif event == DVDNAV_HOP_CHANNEL:
                yield DVDStreamEvent("Hop Channel", self)

            elif event == DVDNAV_STOP:
                yield DVDStreamEvent("Stop", self)
                finished = 1

            else:
                yield DVDStreamEvent("Unknown", self)
                finished = 1
        if self.cache:
            dvdnav_free_cache_block(self.dvdnav, self.buf)
        if dvdnav_close(self.dvdnav) != DVDNAV_STATUS_OK:
            print("Error on dvdnav_close: %s" % dvdnav_err_to_string(self.dvdnav))

cdef class DVDStreamEvent:
    def __cinit__(self, event_type, DVDStream stream):
        self.event_type = event_type
        cdef uint32_t pos, length
        cdef int32_t tt = 0, ptt = 0
        dvdnav_current_title_info(stream.dvdnav, &tt, &ptt)
        dvdnav_get_position(stream.dvdnav, &pos, &length)
        self.position = pos
        self.length = length
        self.title = tt
        self.chapter = ptt

    def __repr__(self):
        return "DVDStreamEvent: % 30s at Title: % 3i Chaper: % 3i - Pos % 8i / % 8i" % (self.event_type, self.title, self.chapter, self.position, self.length)
