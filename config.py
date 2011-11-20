#! /usr/bin/env python

import os.path as path
import tagbuilder as tb

builder = tb.Builder()

builder.set_root("~/data/code/public-clones/gish")
builder.set_working_root('game')

builder.add_working_set('.')

builder.add_other_set('audio')
builder.add_other_set('input')
builder.add_other_set('math')
builder.add_other_set('menu')
builder.add_other_set('parser')
builder.add_other_set('physics')
builder.add_other_set('sdl')
builder.add_other_set('video')

builder.build_cpp()








