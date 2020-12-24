from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, \
    int8_t, int16_t, int32_t, int64_t

from .dvd_types cimport dvdnav_highlight_area_t, DVDMenuID_t
from .nav_types cimport pci_t, btni_t

cdef extern from "dvdnav.h":
    ctypedef void* dvdnav_t
    ctypedef int32_t dvdnav_status_t
    ctypedef void* dvdnav_stream_cb
    ctypedef void* vm_cmd_t

    # Some opaque types we will not need to modify:
    ctypedef void* dsi_t
    ctypedef void* user_ops_t
    ctypedef void* audio_attr_t
    ctypedef void* subp_attr_t

    enum:
        DVD_VIDEO_LB_LEN

    enum:
        DVDNAV_STATUS_ERR
        DVDNAV_STATUS_OK

    enum dvd_logger_level_t:
        DVDNAV_LOGGER_LEVEL_INFO
        DVDNAV_LOGGER_LEVEL_ERROR
        DVDNAV_LOGGER_LEVEL_WARN
        DVDNAV_LOGGER_LEVEL_DEBUG

    ctypedef struct dvdnav_logger_cb:
        void (*pf_log) (void *, dvdnav_logger_level_t, char *, va_list)

    dvdnav_status_t dvdnav_open(dvdnav_t **dest, const char *path)
    dvdnav_status_t dvdnav_open_stream(dvdnav_t **dest, void *priv, dvdnav_stream_cb *stream_cb)

    dvdnav_status_t dvdnav_open2(dvdnav_t **dest,
                                 void *, const dvdnav_logger_cb *,
                                 const char *path)
    dvdnav_status_t dvdnav_open_stream2(dvdnav_t **dest,
                                        void *priv, const dvdnav_logger_cb *,
                                        dvdnav_stream_cb *stream_cb)

    # Initialization and housekeeping functions
    dvdnav_status_t dvdnav_dup(dvdnav_t **dest, dvdnav_t *src)
    dvdnav_status_t dvdnav_free_dup(dvdnav_t * _this)
    dvdnav_status_t dvdnav_close(dvdnav_t *self)
    dvdnav_status_t dvdnav_reset(dvdnav_t *self)
    dvdnav_status_t dvdnav_path(dvdnav_t *self, const char **path)
    const char* dvdnav_err_to_string(dvdnav_t *self)
    const char* dvdnav_version()

    # Changing and reading DVD player characteristics
    dvdnav_status_t dvdnav_set_region_mask(dvdnav_t *self, int32_t region_mask)
    dvdnav_status_t dvdnav_get_region_mask(dvdnav_t *self, int32_t *region_mask)
    dvdnav_status_t dvdnav_set_readahead_flag(dvdnav_t *self, int32_t read_ahead_flag)
    dvdnav_status_t dvdnav_get_readahead_flag(dvdnav_t *self, int32_t *read_ahead_flag)
    dvdnav_status_t dvdnav_set_PGC_positioning_flag(dvdnav_t *self, int32_t pgc_based_flag)
    dvdnav_status_t dvdnav_get_PGC_positioning_flag(dvdnav_t *self, int32_t *pgc_based_flag)

    # Reading data
    dvdnav_status_t dvdnav_get_next_block(dvdnav_t *self, uint8_t *buf,
                                          int32_t *event, int32_t *len)
    dvdnav_status_t dvdnav_get_next_cache_block(dvdnav_t *self, uint8_t **buf,
                                                int32_t *event, int32_t *len)
    dvdnav_status_t dvdnav_free_cache_block(dvdnav_t *self, unsigned char *buf)
    dvdnav_status_t dvdnav_still_skip(dvdnav_t *self)
    dvdnav_status_t dvdnav_wait_skip(dvdnav_t *self)
    uint32_t dvdnav_get_next_still_flag(dvdnav_t *self)
    dvdnav_status_t dvdnav_stop(dvdnav_t *self)

    # Title/part navigation
    dvdnav_status_t dvdnav_get_number_of_titles(dvdnav_t *self, int32_t *titles)
    dvdnav_status_t dvdnav_get_number_of_parts(dvdnav_t *self, int32_t title, int32_t *parts)
    dvdnav_status_t dvdnav_get_number_of_angles(dvdnav_t *self, int32_t title, int32_t *angles)
    dvdnav_status_t dvdnav_title_play(dvdnav_t *self, int32_t title)
    dvdnav_status_t dvdnav_part_play(dvdnav_t *self, int32_t title, int32_t part)
    dvdnav_status_t dvdnav_program_play(dvdnav_t *self, int32_t title, int32_t pgcn, int32_t pgn)
    uint32_t dvdnav_describe_title_chapters(dvdnav_t *self, int32_t title, uint64_t **times, uint64_t *duration)
    dvdnav_status_t dvdnav_part_play_auto_stop(dvdnav_t *self, int32_t title,
                                               int32_t part, int32_t parts_to_play)
    dvdnav_status_t dvdnav_time_play(dvdnav_t *self, int32_t title,
                                     uint64_t time)
    dvdnav_status_t dvdnav_menu_call(dvdnav_t *self, DVDMenuID_t menu)
    dvdnav_status_t dvdnav_current_title_info(dvdnav_t *self, int32_t *title,
                                              int32_t *part)
    dvdnav_status_t dvdnav_current_title_program(dvdnav_t *self, int32_t *title,
                                              int32_t *pgcn, int32_t *pgn)
    dvdnav_status_t dvdnav_get_position_in_title(dvdnav_t *self,
                                                 uint32_t *pos,
                                                 uint32_t *len)
    dvdnav_status_t dvdnav_part_search(dvdnav_t *self, int32_t part)

    # program chain/program navigation
    dvdnav_status_t dvdnav_sector_search(dvdnav_t *self,
                                         int64_t offset, int32_t origin)
    int64_t dvdnav_get_current_time(dvdnav_t *self)
    dvdnav_status_t dvdnav_time_search(dvdnav_t *self,
                                       uint64_t time)
    dvdnav_status_t dvdnav_go_up(dvdnav_t *self)
    dvdnav_status_t dvdnav_prev_pg_search(dvdnav_t *self)
    dvdnav_status_t dvdnav_top_pg_search(dvdnav_t *self)
    dvdnav_status_t dvdnav_next_pg_search(dvdnav_t *self)
    dvdnav_status_t dvdnav_get_position(dvdnav_t *self, uint32_t *pos,
                                        uint32_t *len)

    # Menu highlights
    dvdnav_status_t dvdnav_get_current_highlight(dvdnav_t *self, int32_t *button)
    pci_t* dvdnav_get_current_nav_pci(dvdnav_t *self)
    dsi_t* dvdnav_get_current_nav_dsi(dvdnav_t *self)
    dvdnav_status_t dvdnav_get_highlight_area(pci_t *nav_pci , int32_t button, int32_t mode,
                                              dvdnav_highlight_area_t *highlight)
    dvdnav_status_t dvdnav_upper_button_select(dvdnav_t *self, pci_t *pci)
    dvdnav_status_t dvdnav_lower_button_select(dvdnav_t *self, pci_t *pci)
    dvdnav_status_t dvdnav_right_button_select(dvdnav_t *self, pci_t *pci)
    dvdnav_status_t dvdnav_left_button_select(dvdnav_t *self, pci_t *pci)
    dvdnav_status_t dvdnav_button_activate(dvdnav_t *self, pci_t *pci)
    dvdnav_status_t dvdnav_button_select(dvdnav_t *self, pci_t *pci, int32_t button)
    dvdnav_status_t dvdnav_button_select_and_activate(dvdnav_t *self, pci_t *pci, int32_t button)
    dvdnav_status_t dvdnav_button_activate_cmd(dvdnav_t *self, int32_t button, vm_cmd_t *cmd)
    dvdnav_status_t dvdnav_mouse_select(dvdnav_t *self, pci_t *pci, int32_t x, int32_t y)
    dvdnav_status_t dvdnav_mouse_activate(dvdnav_t *self, pci_t *pci, int32_t x, int32_t y)

    # Languages
    dvdnav_status_t dvdnav_menu_language_select(dvdnav_t *self,
                                               char *code)
    dvdnav_status_t dvdnav_audio_language_select(dvdnav_t *self,
                                                char *code)
    dvdnav_status_t dvdnav_spu_language_select(dvdnav_t *self,
                                              char *code)

    # obtaining stream attributes
    dvdnav_status_t dvdnav_get_title_string(dvdnav_t *self, const char **title_str)
    dvdnav_status_t dvdnav_get_serial_string(dvdnav_t *self, const char **serial_str)
    uint8_t dvdnav_get_video_aspect(dvdnav_t *self)
    dvdnav_status_t dvdnav_get_video_resolution(dvdnav_t *self, uint32_t *width, uint32_t *height)
    uint8_t dvdnav_get_video_scale_permission(dvdnav_t *self)
    uint16_t dvdnav_audio_stream_to_lang(dvdnav_t *self, uint8_t stream)
    uint16_t dvdnav_audio_stream_format(dvdnav_t *self, uint8_t stream)
    uint16_t dvdnav_audio_stream_channels(dvdnav_t *self, uint8_t stream)
    uint16_t dvdnav_spu_stream_to_lang(dvdnav_t *self, uint8_t stream)
    int8_t dvdnav_get_audio_logical_stream(dvdnav_t *self, uint8_t audio_num)
    dvdnav_status_t dvdnav_get_audio_attr(dvdnav_t *self, uint8_t audio_mum, audio_attr_t *audio_attr)
    int8_t dvdnav_get_spu_logical_stream(dvdnav_t *self, uint8_t subp_num)
    dvdnav_status_t dvdnav_get_spu_attr(dvdnav_t *self, uint8_t audio_mum, subp_attr_t *subp_attr)
    int8_t dvdnav_get_active_audio_stream(dvdnav_t *self)
    int8_t dvdnav_get_active_spu_stream(dvdnav_t *self)
    user_ops_t dvdnav_get_restrictions(dvdnav_t *self)

    # angles
    dvdnav_status_t dvdnav_angle_change(dvdnav_t *self, int32_t angle)

    dvdnav_status_t dvdnav_get_angle_info(dvdnav_t *self, int32_t *current_angle,
                                      int32_t *number_of_angles)

    # domain queries
    int8_t dvdnav_is_domain_fp(dvdnav_t *self)
    int8_t dvdnav_is_domain_vmgm(dvdnav_t *self)
    int8_t dvdnav_is_domain_vtsm(dvdnav_t *self)
    int8_t dvdnav_is_domain_vts(dvdnav_t *self)

