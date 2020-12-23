from libc.stdint cimport uint8_t, uint16_t, uint32_t

cdef extern from "nav_types.h":
    ctypedef void* dvd_time_t
    ctypedef void* vm_cmd_t
    ctypedef void* user_ops_t

    ctypedef struct pci_gi_t:
        uint32_t nv_pck_lbn
        uint16_t vobu_cat
        uint16_t zero1
        user_ops_t vobu_uop_ctl
        uint32_t vobu_s_ptm
        uint32_t vobu_e_ptm
        uint32_t vobu_se_e_ptm
        dvd_time_t e_eltm
        char vobu_isrc[32]

    ctypedef struct nsml_agli_t:
        uint32_t nsml_agl_dsta[9]

    ctypedef struct hl_gi_t:
        uint16_t hli_ss
        uint32_t hli_s_ptm
        uint32_t hli_e_ptm
        uint32_t btn_se_e_ptm
        unsigned int zero1
        unsigned int btngr_ns
        unsigned int zero2
        unsigned int btngr1_dsp_ty
        unsigned int zero3
        unsigned int btngr2_dsp_ty
        unsigned int zero4
        unsigned int btngr3_dsp_ty
        uint8_t btn_ofn
        uint8_t btn_ns
        uint8_t nsl_btn_ns
        uint8_t zero5
        uint8_t fosl_btnn
        uint8_t foac_btnn

    ctypedef struct btn_colit_t:
        uint32_t btn_coli[3][2]

    ctypedef struct btni_t:
        unsigned int btn_coln
        unsigned int x_start
        unsigned int zero1
        unsigned int x_end

        unsigned int auto_action_mode
        unsigned int y_start
        unsigned int zero2
        unsigned int y_end

        unsigned int zero3
        unsigned int up
        unsigned int zero4
        unsigned int down
        unsigned int zero5
        unsigned int left
        unsigned int zero6
        unsigned int right
        vm_cmd_t cmd

    ctypedef struct hli_t:
        hl_gi_t hl_gi
        btn_colit_t btn_colit
        btni_t btnit[36]

    ctypedef struct pci_t:
        pci_gi_t pci_gi
        nsml_agli_t nsml_agli
        hli_t hli
        uint8_t zero1[189]
