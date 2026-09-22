extends RefCounted
const INK=Color("e4ead7")
const MUTED=Color("abc5b5")
const BRASS=Color("d5b777")
static func panel(radius: int=12) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color("142e28");box.border_color=Color("466052");box.set_border_width_all(1);box.set_corner_radius_all(radius)
	box.set_content_margin_all(16);return box
static func theme() -> Theme:
	var t:=Theme.new();t.default_font_size=21
	for kind in ["Label","Button","CheckButton","LineEdit","SpinBox","ItemList"]:
		t.set_color("font_color",kind,INK)
		t.set_color("font_hover_color",kind,Color("fff2cc"))
		t.set_color("font_focus_color",kind,INK)
		t.set_color("font_pressed_color",kind,Color("102a24"))
		t.set_color("font_disabled_color",kind,Color("72877a"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var s:=panel(8);s.set_content_margin_all(10)
		s.bg_color=Color("23473a") if state=="normal" else Color("3b6350") if state=="hover" else BRASS if state=="pressed" else Color("192f29")
		if state=="focus":s.bg_color=Color(0,0,0,0);s.border_color=BRASS;s.set_border_width_all(2)
		t.set_stylebox(state,"Button",s)
	for kind in ["LineEdit","ItemList"]:
		t.set_stylebox("normal" if kind=="LineEdit" else "panel",kind,panel(8))
		t.set_stylebox("focus",kind,t.get_stylebox("focus","Button"))
		t.set_color("font_selected_color",kind,Color("102a24"))
	var selected:=panel(6);selected.bg_color=Color("a2c9ad");selected.set_content_margin_all(5)
	t.set_stylebox("selected","ItemList",selected);t.set_stylebox("selected_focus","ItemList",selected)
	t.set_constant("v_separation","ItemList",12)
	t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_stylebox("panel","PanelContainer",panel())
	return t
