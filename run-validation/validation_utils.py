#!/usr/bin/env python-3.10-ibdsel

import h5py
from matplotlib.axes import Axes
import time
import functools
from typing import Callable


_old_axes_init = Axes.__init__


def _new_axes_init(self, *a, **kw):
    _old_axes_init(self, *a, **kw)
    # https://matplotlib.org/stable/gallery/misc/zorder_demo.html
    # 3 => leave text and legends vectorized
    self.set_rasterization_zorder(3)


def rasterize_plots():
    Axes.__init__ = _new_axes_init


def vectorize_plots():
    Axes.__init__ = _old_axes_init


def print_contents(flow_h5: h5py.File):
    print('\n----------------- File content -----------------')
    print('File:',flow_h5.filename)
    print('Keys in file:',list(flow_h5.keys()))
    for key in flow_h5.keys():
        print('Number of',key,'entries in file:', len(flow_h5[key]))
        if isinstance(flow_h5[key],h5py.Group):
            for key2 in flow_h5[key].keys():
                full_key = key+'/'+key2+'/data'
                try:
                    print('  ** ',full_key,'entries in file:', len(flow_h5[full_key]))
                except:
                    print(f'Error getting size of {full_key}')
    print('------------------------------------------------\n')


def defplot(label: str):
    def decorator(func: Callable):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            print(f'Plotting {label}...')
            start = time.time()
            result = func(*args, **kwargs)
            elapsed = time.time() - start
            print(f'Plotting {label} took {elapsed:.2f} seconds\n')
            return result
        return wrapper
    return decorator
