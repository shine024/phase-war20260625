import pathlib
p = pathlib.Path(r'F:\godot fair duet\create\phase-war\scripts\card_grid_buff_strip.gd')
t = p.read_text('utf-8')
t += '''

func _draw_carrier_icon(cx: float