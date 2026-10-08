-- Explicit bindings keep these shortcuts readable by the DMS cheatsheet.
hl.bind("SUPER + CTRL + H", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize left --notify"), { description = "Grow left to next fraction" })
hl.bind("SUPER + CTRL + SHIFT + H", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize right --shrink --notify"), { description = "Shrink toward left to next fraction" })
hl.bind("SUPER + CTRL + ALT + H", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize left --take-all --notify"), { description = "Take neighbour space left" })

hl.bind("SUPER + CTRL + J", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize down --notify"), { description = "Grow down to next fraction" })
hl.bind("SUPER + CTRL + SHIFT + J", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize up --shrink --notify"), { description = "Shrink toward down to next fraction" })
hl.bind("SUPER + CTRL + ALT + J", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize down --take-all --notify"), { description = "Take neighbour space down" })

hl.bind("SUPER + CTRL + K", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize up --notify"), { description = "Grow up to next fraction" })
hl.bind("SUPER + CTRL + SHIFT + K", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize down --shrink --notify"), { description = "Shrink toward up to next fraction" })
hl.bind("SUPER + CTRL + ALT + K", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize up --take-all --notify"), { description = "Take neighbour space up" })

hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize right --notify"), { description = "Grow right to next fraction" })
hl.bind("SUPER + CTRL + SHIFT + L", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize left --shrink --notify"), { description = "Shrink toward right to next fraction" })
hl.bind("SUPER + CTRL + ALT + L", hl.dsp.exec_cmd("/home/phirios/.local/bin/hypr-smart-resize right --take-all --notify"), { description = "Take neighbour space right" })
