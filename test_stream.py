from collections import Counter
from pydvdnav.dvd_stream import DVDStream
import numpy as np

ds = DVDStream("example.iso", cache=False)

count = Counter()
ncount = 0

# Let's try to implement some reads!
event_types = Counter()

nav_info = []

highlights = []

ds.current_title = 1
ds.menu_call(0)
e = None
while getattr(e, 'event_type', None) != "BLOCK_OK":
    e = ds.read()
    event_types[e.event_type] += 1

buffer = []
while e.event_type in ("BLOCK_OK", "NAV_PACKET"):
    if e.event_type == "BLOCK_OK":
        buffer.append(e.buffer)
    else:
        print(e, ds.last_length)
        nav_info.append(len(e.button_info))
    e = ds.read()
    event_types[e.event_type] += 1

buffer = np.concatenate(buffer)
open("out.mpg", "wb").write(buffer)
