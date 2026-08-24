#!/usr/bin/env bash

dir="$HOME/.config/rofi"
theme='style-1'

## Run
rofi -modi clipboard:~/.config/rofi/clipboard/cliphist-rofi -show clipboard -theme ${dir}/${theme}.rasi
