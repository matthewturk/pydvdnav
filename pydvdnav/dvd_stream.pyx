# cython: language_level = 3
# distutils: libraries = dvdnav

from libc.stdint cimport uint8_t, int32_t, uint32_t
from libc.stdlib cimport free
from .dvd_types cimport *
from .dvdnav_events cimport *
from .dvdnav cimport *
import numpy as np
cimport numpy as np

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

    def read(self):
        cdef int32_t result, event, length
        if self.cache:
            result = dvdnav_get_next_cache_block(self.dvdnav, &self.buf, &event, &length)
        else:
            result = dvdnav_get_next_block(self.dvdnav, self.buf, &event, &length)
        self.last_result = result
        self.last_event = event
        self.last_length = length
        if result == DVDNAV_STATUS_ERR:
            raise RuntimeError("Error getting next block: %s" %
                               dvdnav_err_to_string(self.dvdnav))
        if event == DVDNAV_BLOCK_OK:
            if self.outstream != NULL:
                fwrite(self.buf, sizeof(uint8_t), length, self.outstream)
            return BlockReadEvent("BLOCK_OK", self)
        elif event == DVDNAV_NOP:
            return Event("NOP", self)
        elif event == DVDNAV_STILL_FRAME:
            return StillEvent("STILL_FRAME", self)
        elif event == DVDNAV_WAIT:
            return WaitEvent("WAIT", self)
        elif event == DVDNAV_SPU_CLUT_CHANGE:
            return Event("SPU_CLUT_CHANGE", self)
        elif event == DVDNAV_SPU_STREAM_CHANGE:
            return SPUStreamChangeEvent("SPU_STREAM_CHANGE", self)
        elif event == DVDNAV_AUDIO_STREAM_CHANGE:
            return AudioStreamChangeEvent("AUDIO_STREAM_CHANGE", self)
        elif event == DVDNAV_HIGHLIGHT:
            return HighlightEvent("HIGHLIGHT", self)
        elif event == DVDNAV_VTS_CHANGE:
            return VTSChangeEvent("VTS_CHANGE", self)
        elif event == DVDNAV_CELL_CHANGE:
            return CellChangeEvent("CELL_CHANGE", self)
        elif event == DVDNAV_NAV_PACKET:
            return NavigationEvent("NAV_PACKET", self)
        elif event == DVDNAV_HOP_CHANNEL:
            return Event("HOP_CHANNEL", self)
        elif event == DVDNAV_STOP:
            return Event("STOP", self)
            # This won't let you continue
        else:
            return Event("UNKNOWN", self)
            # This will not allow continuing

    def reset(self):
        cdef dvdnav_status_t status
        status = dvdnav_reset(self.dvdnav)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error reseting status: %s" %
                               dvdnav_err_to_string(self.dvdnav))

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
            self.last_result = result
            self.last_event = event
            self.last_length = length
            if result == DVDNAV_STATUS_ERR:
                raise RuntimeError("Error getting next block: %s" %
                                   dvdnav_err_to_string(self.dvdnav))
            if event == DVDNAV_BLOCK_OK:
                if self.outstream != NULL:
                    fwrite(self.buf, sizeof(uint8_t), length, self.outstream)
                yield BlockReadEvent("BLOCK_OK", self)
            elif event == DVDNAV_NOP:
                yield Event("NOP", self)
            elif event == DVDNAV_STILL_FRAME:
                yield Event("STILL_FRAME", self)
                still_event = <dvdnav_still_event_t*> self.buf
                if still_event.length < 0xff:
                    print("Skipping %d seconds of still frame" % still_event.length)
                else:
                    print("Skipping indefinite length still frame")
                dvdnav_still_skip(self.dvdnav)
            elif event == DVDNAV_WAIT:
                yield Event("WAIT", self)
                print("Skipping wait condition")
                dvdnav_wait_skip(self.dvdnav)
            elif event == DVDNAV_SPU_CLUT_CHANGE:
                yield Event("SPU_CLUT_CHANGE", self)
            elif event == DVDNAV_SPU_STREAM_CHANGE:
                yield SPUStreamChangeEvent("SPU_STREAM_CHANGE", self)
            elif event == DVDNAV_AUDIO_STREAM_CHANGE:
                yield AudioStreamChangeEvent("AUDIO_STREAM_CHANGE", self)
            elif event == DVDNAV_HIGHLIGHT:
                yield HighlightEvent("HIGHLIGHT", self)
            elif event == DVDNAV_VTS_CHANGE:
                yield VTSChangeEvent("VTS_CHANGE", self)
            elif event == DVDNAV_CELL_CHANGE:
                dvdnav_current_title_info(self.dvdnav, &tt, &ptt)
                dvdnav_get_position(self.dvdnav, &pos, &length2)
                print("Cell change: Title %d, Chapter %d" % (tt, ptt))
                print("At position %s of %s inside the feature" % (pos, length2))
                yield CellChangeEvent("CELL_CHANGE", self)

            elif event == DVDNAV_NAV_PACKET:
                ty = NavigationEvent("NAV_PACKET", self)
                yield ty
                #if len(ty.button_info) > 0:
                #    finished = 1
            elif event == DVDNAV_HOP_CHANNEL:
                yield Event("HOP_CHANNEL", self)

            elif event == DVDNAV_STOP:
                yield Event("STOP", self)
                finished = 1

            else:
                yield Event("UNKNOWN", self)
                finished = 1
        if self.cache:
            dvdnav_free_cache_block(self.dvdnav, self.buf)
        if dvdnav_close(self.dvdnav) != DVDNAV_STATUS_OK:
            print("Error on dvdnav_close: %s" % dvdnav_err_to_string(self.dvdnav))

    @property
    def table_of_contents(self):
        cdef int32_t titles, parts
        cdef uint32_t chapters
        cdef uint64_t *times
        cdef uint64_t duration
        cdef dvdnav_status_t status = dvdnav_get_number_of_titles(self.dvdnav, &titles)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error getting number of titles: %s" % (dvdnav_err_to_string(self.dvdnav)))
        toc = {}
        for i in range(1, titles + 1):
            status = dvdnav_get_number_of_parts(self.dvdnav, i, &parts)
            if status != DVDNAV_STATUS_OK:
                raise RuntimeError("Error getting number of parts for title %s: %s" % (
                    i, dvdnav_err_to_string(self.dvdnav)))
            chapters = dvdnav_describe_title_chapters(self.dvdnav, i, &times, &duration)
            this_times = []
            # durations are reported in PTS ticks, so to get to seconds, divide by 90000
            for j in range(chapters):
                this_times.append(times[j] / 90000.0)
            toc[i] = (parts, duration / 90000.0, this_times)
            free(times)
        return toc

    @property
    def current_title(self):
        cdef dvdnav_status_t status
        cdef int32_t title, part
        status = dvdnav_current_title_info(self.dvdnav, &title, &part)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error getting title info: %s" % (
                    dvdnav_err_to_string(self.dvdnav)))
        return title

    @current_title.setter
    def current_title(self, value):
        cdef dvdnav_status_t status
        cdef int32_t title = value
        status = dvdnav_title_play(self.dvdnav, title)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error setting title to %s: %s" % (
                    title, dvdnav_err_to_string(self.dvdnav)))

    @property
    def current_title_info(self):
        #dvdnav_status_t dvdnav_current_title_info(dvdnav_t *self, int32_t *title, int32_t *part);
        cdef dvdnav_status_t status
        cdef int32_t title, part
        status = dvdnav_current_title_info(self.dvdnav, &title, &part)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error getting title info: %s" % (
                    dvdnav_err_to_string(self.dvdnav)))
        return title, part

    @current_title_info.setter
    def current_title_info(self, value):
        cdef dvdnav_status_t status
        cdef int32_t title, part
        title = value[0]
        part = value[1]
        status = dvdnav_part_play(self.dvdnav, title, part)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error setting title to %s and part to %s: %s" % (
                    title, part, dvdnav_err_to_string(self.dvdnav)))

    @property
    def current_title_program(self):
        cdef dvdnav_status_t status
        cdef int32_t title, pgc, pgn
        status = dvdnav_current_title_program(self.dvdnav, &title, &pgc, &pgn)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error getting title program: %s" % (
                    dvdnav_err_to_string(self.dvdnav)))
        return title, pgc, pgn

    @current_title_program.setter
    def current_title_program(self, value):
        cdef dvdnav_status_t status
        cdef int32_t title, pgcn, pgn
        title = value[0]
        pgcn = value[1]
        pgn = value[2]
        status = dvdnav_program_play(self.dvdnav, title, pgcn, pgn)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error setting title program to (%s, %s, %s): %s" % (
                    title, pgcn, pgn, dvdnav_err_to_string(self.dvdnav)))

    @property
    def current_time(self):
        return dvdnav_get_current_time(self.dvdnav) / 90000.0

    @property
    def next_still_flag(self):
        return dvdnav_get_next_still_flag(self.dvdnav)

    def menu_call(self, DVDMenuID_t menu_id):
        cdef dvdnav_status_t status
        status = dvdnav_menu_call(self.dvdnav, menu_id)
        if status != DVDNAV_STATUS_OK:
            raise RuntimeError("Error calling menu %s: %s" % (
                menu_id, dvdnav_err_to_string(self.dvdnav)))

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
        self.dvdnav = stream.dvdnav

    def __repr__(self):
        return "Event: % 30s at Title: % 3i Chaper: % 3i - Pos % 8i / % 8i" % (self.event_type, self.title, self.chapter, self.position, self.length)

    def complete(self):
        return

cdef class BlockReadEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        cdef np.ndarray[np.uint8_t, ndim=1] buffer
        self.buffer = buffer = np.empty(stream.last_length, dtype="u1")
        for i in range(stream.last_length):
            buffer[i] = stream.buf[i]
        # This doesn't work, I'm sure there's a better way, I feel silly that I
        # don't know it, but whatever.
        #buffer[:] = <np.uint8_t[:]> stream.buf[:stream.last_length]


cdef class NavigationEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        cdef btni_t *btni = NULL
        self.pci = dvdnav_get_current_nav_pci(stream.dvdnav)
        self.button_info = {}
        if self.pci.hli.hl_gi.btn_ns > 0:
            for button in range(self.pci.hli.hl_gi.btn_ns):
                btni = &(self.pci.hli.btnit[button])
                self.button_info[button + 1] = (btni.x_start, btni.y_start, btni.x_end, btni.y_end, btni.auto_action_mode)

    def select_button(self, int button_id):
        dvdnav_button_select_and_activate(self.dvdnav, self.pci, button_id)

    def complete(self):
        if len(self.button_info) > 0:
            self.select_button(1)

cdef class StillEvent(Event):
    def __cinit__(self, event_type, DVDStream stream):
        self.still_length = (<dvdnav_still_event_t*> stream.buf).length

    def still_skip(self):
        dvdnav_still_skip(self.dvdnav)

    def complete(self):
        self.still_skip()

cdef class WaitEvent(Event):
    def wait_skip(self):
        dvdnav_wait_skip(self.dvdnav)

    def complete(self):
        self.wait_skip()

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
        cdef dvdnav_vts_change_event_t *change_event
        change_event = <dvdnav_vts_change_event_t *> stream.buf
        self.old_vtsN = change_event.old_vtsN
        self.old_domain = change_event.old_domain
        self.new_vtsN = change_event.new_vtsN
        self.new_domain = change_event.new_domain

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

