# Utility

This repository contains utility type modules used in other projects that do not really require their own repository, yet need a home.

## rescan_fifo.sv
An asynchronous fifo. The primary use of this fifo is for buffering a video scan-line of pixels. Multiple pixels are buffered in strips which are written to and read from the fifo.
The fifo may be loaded up with values after a write-reset, then the values spit out by reads. The read pointer may be reset so that the same set of values may be spit out repeatedly.
Lower resolution video modes may read the same set of pixels from the fifo, without the video controller having to rescan main memory.
The fifo is deep enough to buffer a scan-line full of pixels.

## wb_to_fta_bridge.sv
This is a bus bridge bridging the synchronous WISHBONE bus to an asynchronous FTA bus.
While the FTA bus uses tran id's to identify transactions, they are not used by the bridge. The bridge assumes responses coming from the FTA bus are in order for the current WISHBONE bus cycle.
