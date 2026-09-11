"""Rasterize the code-native SVG launcher icon using system librsvg/cairo."""
import ctypes as c

r = c.CDLL('librsvg-2.so.2')
a = c.CDLL('libcairo.so.2')
r.rsvg_handle_new_from_file.argtypes = [c.c_char_p, c.c_void_p]
r.rsvg_handle_new_from_file.restype = c.c_void_p
r.rsvg_handle_render_cairo.argtypes = [c.c_void_p, c.c_void_p]
a.cairo_image_surface_create.argtypes = [c.c_int, c.c_int, c.c_int]
a.cairo_image_surface_create.restype = c.c_void_p
a.cairo_create.argtypes = [c.c_void_p]
a.cairo_create.restype = c.c_void_p
a.cairo_surface_write_to_png.argtypes = [c.c_void_p, c.c_char_p]
handle = r.rsvg_handle_new_from_file(b'resources/drawables/LauncherIcon.svg', None)
assert handle
surface = a.cairo_image_surface_create(0, 65, 65)
context = a.cairo_create(surface)
assert r.rsvg_handle_render_cairo(handle, context)
assert a.cairo_surface_write_to_png(surface, b'resources/drawables/LauncherIcon.png') == 0
