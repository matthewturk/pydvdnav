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
        print("Setting outstream to ", filename)
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
                yield Event("No-Op", self)
            elif event == DVDNAV_STILL_FRAME:
                yield Event("Still Frame", self)
                still_event = <dvdnav_still_event_t*> self.buf
                if still_event.length < 0xff:
                    print("Skipping %d seconds of still frame" % still_event.length)
                else:
                    print("Skipping indefinite length still frame")
                dvdnav_still_skip(self.dvdnav)
            elif event == DVDNAV_WAIT:
                yield Event("Wait", self)
                print("Skipping wait condition")
                dvdnav_wait_skip(self.dvdnav)
            elif event == DVDNAV_SPU_CLUT_CHANGE:
                yield Event("SPU CLUT Change", self)
            elif event == DVDNAV_SPU_STREAM_CHANGE:
                yield SPUStreamChangeEvent("SPU Stream Change", self)
            elif event == DVDNAV_AUDIO_STREAM_CHANGE:
                yield AudioStreamChangeEvent("Audio Stream Change", self)
            elif event == DVDNAV_HIGHLIGHT:
                yield HighlightEvent("Highlight", self)
            elif event == DVDNAV_VTS_CHANGE:
                yield VTSChangeEvent("VTS Change", self)
            elif event == DVDNAV_CELL_CHANGE:
                dvdnav_current_title_info(self.dvdnav, &tt, &ptt)
                dvdnav_get_position(self.dvdnav, &pos, &length2)
                print("Cell change: Title %d, Chapter %d" % (tt, ptt))
                print("At position %s of %s inside the feature" % (pos, length2))
                yield CellChangeEvent("Cell Change", self)

            elif event == DVDNAV_NAV_PACKET:
                ty = NavigationEvent("Navigation", self)
                yield ty
                #if len(ty.button_info) > 0:
                #    finished = 1
            elif event == DVDNAV_HOP_CHANNEL:
                yield Event("Hop Channel", self)

            elif event == DVDNAV_STOP:
                yield Event("Stop", self)
                finished = 1

            else:
                yield Event("Unknown", self)
                finished = 1
        if self.cache:
            dvdnav_free_cache_block(self.dvdnav, self.buf)
        if dvdnav_close(self.dvdnav) != DVDNAV_STATUS_OK:
            print("Error on dvdnav_close: %s" % dvdnav_err_to_string(self.dvdnav))

    def __dealloc__(self):
        if self.outstream != NULL:
            fclose(self.outstream)

cdef class Event:
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
        return "Event: % 30s at Title: % 3i Chaper: % 3i - Pos % 8i / % 8i" % (self.event_type, self.title, self.chapter, self.position, self.length)

cdef class NavigationEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        cdef btni_t *btni = NULL
        self.pci = dvdnav_get_current_nav_pci(stream.dvdnav)
        self.button_info = {}
        if self.pci.hli.hl_gi.btn_ns > 0:
            for button in range(self.pci.hli.hl_gi.btn_ns):
                btni = &(self.pci.hli.btnit[button])
                self.button_info[button + 1] = (btni.x_start, btni.y_start, btni.x_end, btni.y_end, btni.auto_action_mode)

    def select_button(self, DVDStream stream, int button_id):
        dvdnav_button_select_and_activate(stream.dvdnav, self.pci, button_id)

cdef class StillEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        self.still_length = (<dvdnav_still_event_t*> stream.buf).length

cdef class SPUStreamChangeEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        cdef dvdnav_spu_stream_change_event_t *change_event
        change_event = <dvdnav_spu_stream_change_event_t*> stream.buf
        self.physical_wide = change_event.physical_wide
        self.physical_letterbox = change_event.physical_letterbox
        self.physical_pan_scan = change_event.physical_pan_scan
        self.logical = change_event.logical

cdef class AudioStreamChangeEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        cdef dvdnav_audio_stream_change_event_t *change_event
        change_event = <dvdnav_audio_stream_change_event_t *> stream.buf
        self.physical = change_event.physical
        self.logical = change_event.logical

cdef class VTSChangeEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        # The size of the enums is causing some annoyance and I don't need it
        # right now, so commenting.
        #cdef dvdnav_vts_change_event_t *change_event
        #change_event = <dvdnav_vts_change_event_t *> stream.buf
        #self.old_vtsN = change_event.old_vtsN
        #self.old_domain = change_event.old_domain
        #self.new_vtsN = change_event.new_vtsN
        #self.new_domain = change_event.new_domain
        pass

cdef class CellChangeEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        cdef dvdnav_cell_change_event_t *change_event
        change_event = <dvdnav_cell_change_event_t*> stream.buf
        self.cellN = change_event.cellN
        self.pgN = change_event.pgN
        self.cell_length = change_event.cell_length
        self.pg_length = change_event.pg_length
        self.pgc_length = change_event.pgc_length
        self.cell_start = change_event.cell_start
        self.pg_start = change_event.pg_start

cdef class HighlightEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        # The position etc stuff is set
        cdef dvdnav_highlight_event_t *highlight_event
        highlight_event = <dvdnav_highlight_event_t *> stream.buf
        self.display = highlight_event.display
        self.palette = highlight_event.palette
        self.sx = highlight_event.sx
        self.sy = highlight_event.sy
        self.ex = highlight_event.ex
        self.ey = highlight_event.ey
        self.pts = highlight_event.pts
        self.buttonN = highlight_event.buttonN

