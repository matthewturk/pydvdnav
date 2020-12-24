from collections import Counter
from pydvdnav.dvd_stream import DVDStream

ds = DVDStream("example.iso", cache=True)

count = Counter()
ncount = 0

for event in ds:
    if event.event_type == "Navigation" and len(event.button_info) == 0:
        pass
    else:
        print(event)
    if event.event_type == "Cell Change":
        ds.set_outstream("hello_%03i_%03i_%03i.mpg" % (event.title,
                                                       event.chapter,
                                                       count[event.title,
                                                             event.chapter]),
                         clobber=True)
        count[event.title, event.chapter] += 1
    elif event.event_type == "Highlight":
        print(event.display, event.palette, event.sx, event.sy, event.ex, event.ey, event.pts, event.buttonN)
    elif event.event_type == "Navigation" and len(event.button_info) > 0:
        if ncount == 100:
            event.select_button(ds, 2)
            ncount = 0
        else:
            ncount += 1
