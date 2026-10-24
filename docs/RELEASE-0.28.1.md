# Hard Play 0.28.1 — Seek Time Readout

The seek tooltip displays an explicit MIN:SEC label and zero-padded time (00:06, 01:00, 02:05). During native slider tracking it follows the bound scrub value and thumb position rather than relying on pointer-hover updates, which can stall while the slider owns the drag. Releasing hides the drag readout until the next hover update. Duration changes and disabled controls clear inspection state. Hover remains read-only.

Build/self/queue/style checks pass, including minute/second formatting and seek mapping at the start, middle and end. The native app was updated in Applications. A live drag tooltip capture has not been automated. Local release; GitHub publishing remains pending the ownership transfer.
