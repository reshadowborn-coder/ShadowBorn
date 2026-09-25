class_name MobileSafeArea
extends RefCounted

const BASE_EDGE_PADDING:=24.0

# Vector4 = left, top, right, bottom in logical viewport coordinates.
static func logical_margins(viewport_size:Vector2,window_size:Vector2,safe_rect:Rect2)->Vector4:
	if viewport_size.x<=0.0 or viewport_size.y<=0.0 or window_size.x<=0.0 or window_size.y<=0.0:
		return Vector4(BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING)
	if safe_rect.size.x<=0.0 or safe_rect.size.y<=0.0:
		return Vector4(BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING)

	var sx:=viewport_size.x/window_size.x
	var sy:=viewport_size.y/window_size.y
	var left:=maxf(0.0,safe_rect.position.x*sx)
	var top:=maxf(0.0,safe_rect.position.y*sy)
	var right_px:=maxf(0.0,window_size.x-(safe_rect.position.x+safe_rect.size.x))
	var bottom_px:=maxf(0.0,window_size.y-(safe_rect.position.y+safe_rect.size.y))
	return Vector4(
		maxf(BASE_EDGE_PADDING,left),
		maxf(BASE_EDGE_PADDING,top),
		maxf(BASE_EDGE_PADDING,right_px*sx),
		maxf(BASE_EDGE_PADDING,bottom_px*sy)
	)

static func current(viewport:Viewport)->Vector4:
	if viewport==null:
		return Vector4(BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING)
	var view_size:=viewport.get_visible_rect().size
	var window_size:=Vector2(DisplayServer.window_get_size())
	if OS.get_name() not in ["iOS","Android"]:
		return Vector4(BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING,BASE_EDGE_PADDING)
	var safe_i:=DisplayServer.get_display_safe_area()
	return logical_margins(view_size,window_size,Rect2(safe_i))
