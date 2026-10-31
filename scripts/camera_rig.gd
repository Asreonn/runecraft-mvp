extends Node3D
## Orthographic ground camera. All screen coordinates are viewport pixels.
## Bounds containment takes precedence over cursor anchoring at map edges.

@export var pitch_deg: float = 45.0
@export var min_size: float = 7.0
@export var max_size: float = 40.0
@export var pan_speed: float = 1.15
@export var pan_accel: float = 9.0
@export var pan_damp: float = 7.0
@export var zoom_step: float = 1.15
@export var zoom_smooth: float = 12.0
@export var rotate_time: float = 0.16
@export var edge_margin: float = 0.0
@export var distance: float = 60.0

var yaw_index: int = 0

var _cam: Camera3D
var _bounds: Rect2
var _target: Vector3 = Vector3.ZERO
var _focus_target: Vector3 = Vector3.ZERO
var _focusing: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _wanted_size: float = 7.0
var _smooth_size: float = 7.0
var _yaw: float = 0.0
var _yaw_from: float = 0.0
var _yaw_goal: float = 0.0
var _rotate_elapsed: float = 0.0
var _rotating: bool = false
var _zoom_anchored: bool = false
var _zoom_world: Vector3 = Vector3.ZERO
var _zoom_cursor: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_world: Vector3 = Vector3.ZERO
var _drag_cursor: Vector2 = Vector2.ZERO

# A small inward numerical guard, in world units, against ray rounding at edges.
const FIT_GUARD: float = 0.0001


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(cam: Camera3D, bounds: Rect2, target: Vector3, size: float) -> void:
	assert(is_inside_tree(), "Add the rig to the scene tree before setup().")
	assert(bounds.size.x > 0.0 and bounds.size.y > 0.0, "Bounds must have positive area.")
	_cam = cam
	if _cam == null:
		_cam = Camera3D.new()
		add_child(_cam)
	assert(_cam.is_inside_tree(), "Add the supplied camera to the scene tree before setup().")
	_bounds = bounds
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 1.0
	_cam.far = 200.0
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0
	_cam.make_current()
	_target = Vector3(target.x, 0.0, target.z)
	_focus_target = _target
	_focusing = false
	_dragging = false
	_zoom_anchored = false
	yaw_index = posmod(yaw_index, 4)
	_wanted_size = _limit_wanted_size(size)
	_yaw_goal = float(posmod(yaw_index, 4)) * PI * 0.5
	snap_now()


func handle_input(ev: InputEvent) -> bool:
	if not is_instance_valid(_cam):
		return false
	if ev is InputEventMouseButton:
		var button: InputEventMouseButton = ev as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				var wheel_factor: float = pow(maxf(zoom_step, 1.001), maxf(button.factor, 0.01))
				zoom_at(1.0 / wheel_factor if button.button_index == MOUSE_BUTTON_WHEEL_UP else wheel_factor, button.global_position)
			return true
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = false
			if button.pressed:
				var hit: Variant = screen_to_ground(button.global_position)
				if hit is Vector3:
					_dragging = true
					_drag_world = hit
					_drag_cursor = button.global_position
					# Grab takes over immediately, including an in-flight zoom/focus.
					_zoom_anchored = false
					_focusing = false
					_velocity = Vector3.ZERO
					_wanted_size = _cam.size
					_smooth_size = _cam.size
			return true
	if ev is InputEventMouseMotion and _dragging:
		_drag_cursor = (ev as InputEventMouseMotion).global_position
		_apply_view()
		return true
	if ev is InputEventKey:
		var key: InputEventKey = ev as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		if key.pressed and not key.echo and (code == KEY_Q or code == KEY_E):
			rotate_step(-1 if code == KEY_Q else 1)
			return true
	return false


func _unhandled_input(ev: InputEvent) -> void:
	if handle_input(ev):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_dragging = false
		_velocity = Vector3.ZERO


func _process(dt: float) -> void:
	if not is_instance_valid(_cam):
		return
	var real_dt: float = dt / Engine.time_scale if Engine.time_scale > 0.0 else float(Performance.get_monitor(Performance.TIME_PROCESS))
	if real_dt <= 0.0 or not is_finite(real_dt):
		real_dt = 1.0 / 60.0
	if _rotating:
		_rotate_elapsed += real_dt
		var t: float = clampf(_rotate_elapsed / maxf(rotate_time, 0.000001), 0.0, 1.0)
		_yaw = lerpf(_yaw_from, _yaw_goal, 1.0 - pow(1.0 - t, 3.0))
		if t >= 1.0:
			_rotating = false
			_yaw = _yaw_goal
	_smooth_size = lerpf(_smooth_size, _wanted_size, 1.0 - exp(-maxf(zoom_smooth, 0.0) * real_dt))
	if absf(_smooth_size - _wanted_size) < 0.00001:
		_smooth_size = _wanted_size
	if not _dragging:
		var axes: Vector2 = _pan_axes()
		var right: Vector3 = Vector3(cos(_yaw), 0.0, -sin(_yaw))
		var up: Vector3 = Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var desired: Vector3 = (right * axes.x + up * (axes.y / sin(_pitch()))) * pan_speed * _cam.size
		var rate: float = pan_accel if not axes.is_zero_approx() else pan_damp
		# Integrate the exponential velocity analytically, avoiding frame-rate-dependent travel.
		var old_velocity: Vector3 = _velocity
		var decay: float = exp(-maxf(rate, 0.0) * real_dt)
		_velocity = desired + (old_velocity - desired) * decay
		var travel: Vector3 = _velocity * real_dt
		if rate > 0.000001:
			travel = desired * real_dt + (old_velocity - desired) * ((1.0 - decay) / rate)
		if not axes.is_zero_approx() or _velocity.length_squared() > 0.000001:
			_zoom_anchored = false
			_focusing = false
			_target += travel
		elif _focusing:
			var reachable: Vector3 = _clamp_point(_focus_target, minf(_smooth_size, _fit_size()))
			_target = _target.lerp(reachable, 1.0 - exp(-maxf(pan_accel, 0.0) * real_dt))
			if _target.distance_squared_to(reachable) < 0.00000001:
				_target = reachable
				_focusing = _smooth_size != _wanted_size or _rotating
	_apply_view()
	if _zoom_anchored and _smooth_size == _wanted_size and not _rotating:
		_zoom_anchored = false


func rotate_step(dir: int) -> void:
	if dir == 0:
		return
	yaw_index = posmod(yaw_index + dir, 4)
	_yaw_from = _yaw
	_yaw_goal += float(dir) * PI * 0.5
	_rotate_elapsed = 0.0
	_rotating = true
	_zoom_anchored = false


func zoom_at(factor: float, screen_pos: Vector2) -> void:
	if not is_instance_valid(_cam) or not is_finite(factor) or factor <= 0.0:
		return
	var hit: Variant = screen_to_ground(screen_pos)
	if hit is Vector3:
		_zoom_world = hit
		_zoom_cursor = screen_pos
		_zoom_anchored = true
	_focusing = false
	# Keep a reachable nominal target: wheel-out cannot accumulate hidden overshoot
	# beyond the current yaw's fit and make subsequent wheel-in appear unresponsive.
	var reachable_size: float = minf(_wanted_size, _fit_size())
	_wanted_size = minf(_limit_wanted_size(reachable_size * factor), _fit_size())
	if _dragging:
		_zoom_anchored = false


func focus(point: Vector3, size: float = -1.0) -> void:
	_focus_target = Vector3(point.x, 0.0, point.z)
	_focusing = true
	_zoom_anchored = false
	_dragging = false
	_velocity = Vector3.ZERO
	if size > 0.0:
		_wanted_size = _limit_wanted_size(size)


func snap_now() -> void:
	_target = _focus_target if _focusing else _target
	_focusing = false
	_smooth_size = _wanted_size
	_yaw = _yaw_goal
	_rotating = false
	_velocity = Vector3.ZERO
	_apply_view()
	_zoom_anchored = false


func screen_to_ground(screen_pos: Vector2, plane_y: float = 0.0) -> Variant:
	if not is_instance_valid(_cam) or not _cam.is_inside_tree():
		return null
	var origin: Vector3 = _cam.project_ray_origin(screen_pos)
	var normal: Vector3 = _cam.project_ray_normal(screen_pos)
	if absf(normal.y) < 0.000001:
		return null
	var ray_t: float = (plane_y - origin.y) / normal.y
	if ray_t < 0.0:
		return null
	return origin + normal * ray_t


func _pan_axes() -> Vector2:
	var axes: Vector2 = Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)))
	if edge_margin > 0.0 and DisplayServer.window_is_focused() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var mouse: Vector2 = _cam.get_viewport().get_mouse_position()
		var rect: Rect2 = _cam.get_viewport().get_visible_rect()
		if rect.has_point(mouse):
			axes.x += clampf((mouse.x - (rect.end.x - edge_margin)) / edge_margin, 0.0, 1.0) - clampf((edge_margin - mouse.x) / edge_margin, 0.0, 1.0)
			axes.y += clampf((edge_margin - mouse.y) / edge_margin, 0.0, 1.0) - clampf((mouse.y - (rect.end.y - edge_margin)) / edge_margin, 0.0, 1.0)
	return axes.limit_length(1.0)


func _limit_wanted_size(value: float) -> float:
	return clampf(value, maxf(min_size, 0.001), maxf(max_size, maxf(min_size, 0.001)))


func _aspect() -> float:
	var viewport_size: Vector2 = _cam.get_viewport().get_visible_rect().size
	return maxf(viewport_size.x, 1.0) / maxf(viewport_size.y, 1.0)


func _pitch() -> float:
	return deg_to_rad(clampf(pitch_deg, 1.0, 89.9))


func _fit_size() -> float:
	var c: float = absf(cos(_yaw))
	var s: float = absf(sin(_yaw))
	var inv_sin_pitch: float = 1.0 / sin(_pitch())
	return maxf(0.000001, minf(
		maxf(_bounds.size.x - 2.0 * FIT_GUARD, 0.000001) / (_aspect() * c + inv_sin_pitch * s),
		maxf(_bounds.size.y - 2.0 * FIT_GUARD, 0.000001) / (_aspect() * s + inv_sin_pitch * c)))


func _write_camera() -> void:
	global_position = _target
	var view_basis: Basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, -_pitch())
	_cam.global_transform = Transform3D(view_basis, _target + view_basis.z * distance)


func _clamp_point(point: Vector3, view_size: float) -> Vector3:
	var a: float = _aspect() * view_size * 0.5
	var b: float = view_size / (2.0 * sin(_pitch()))
	var hx: float = a * absf(cos(_yaw)) + b * absf(sin(_yaw))
	var hz: float = a * absf(sin(_yaw)) + b * absf(cos(_yaw))
	var low_x: float = _bounds.position.x + hx
	var high_x: float = _bounds.end.x - hx
	var low_z: float = _bounds.position.y + hz
	var high_z: float = _bounds.end.y - hz
	return Vector3(
		clampf(point.x, low_x, high_x) if low_x <= high_x else _bounds.get_center().x,
		0.0,
		clampf(point.z, low_z, high_z) if low_z <= high_z else _bounds.get_center().y)


func _apply_view() -> void:
	if not is_instance_valid(_cam):
		return
	_cam.size = minf(_smooth_size, _fit_size())
	_write_camera()
	if _dragging or _zoom_anchored:
		var cursor: Vector2 = _drag_cursor if _dragging else _zoom_cursor
		var anchor: Vector3 = _drag_world if _dragging else _zoom_world
		var hit: Variant = screen_to_ground(cursor)
		if hit is Vector3:
			_target += anchor - (hit as Vector3)
			_target.y = 0.0
	var before: Vector3 = _target
	_target = _clamp_point(_target, _cam.size)
	if (before.x < _target.x and _velocity.x < 0.0) or (before.x > _target.x and _velocity.x > 0.0):
		_velocity.x = 0.0
	if (before.z < _target.z and _velocity.z < 0.0) or (before.z > _target.z and _velocity.z > 0.0):
		_velocity.z = 0.0
	_write_camera()
	if _dragging and not before.is_equal_approx(_target):
		# Rebase a saturated grab so reversing the cursor responds immediately.
		var clamped_hit: Variant = screen_to_ground(_drag_cursor)
		if clamped_hit is Vector3:
			_drag_world = clamped_hit
