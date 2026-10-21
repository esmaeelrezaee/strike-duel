extends Node3D
# STRIKE DUEL v0.3: procedural arena, two-player ENet direct-IP prototype.
# NOT a production-grade authoritative multiplayer shooter.
const PORT := 27670
const SPEED := 7.0
var player: CharacterBody3D
var camera: Camera3D
var opponent: Node3D
var opponent_target := Vector3(0, 1, -10)
var yaw := 0.0
var pitch := 0.0
var cooldown := 0.0
var ammo := 30
var hits := 0
var health := 100
var score := 0
var hud: Label
var status_label: Label
var address_field: LineEdit
var network: ENetMultiplayerPeer
var touch_move := Vector2.ZERO
var touch_look_id := -1
var touch_move_id := -1
var move_start := Vector2.ZERO
var touch_fire := false
var touch_reload := false
var mobile := OS.has_feature("mobile")
var send_timer := 0.0
var enemy_mat: StandardMaterial3D

func _ready() -> void:
    _arena()
    _player()
    _interface()
    multiplayer.peer_connected.connect(_peer_connected)
    multiplayer.peer_disconnected.connect(_peer_disconnected)
    multiplayer.connected_to_server.connect(func(): _set_status("Connected to host"))
    multiplayer.connection_failed.connect(func(): _set_status("Connection failed"))
    multiplayer.server_disconnected.connect(func(): _set_status("Host disconnected"))
    if not mobile: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func mat(c: Color, metal := 0.0, rough := 0.7, emission := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metal
    m.roughness = rough
    if emission:
        m.emission_enabled = true
        m.emission = c
        m.emission_energy_multiplier = 2.0
    return m

func cube(p: Vector3, s: Vector3, m: Material, solid := true) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = s
    mesh.mesh = box
    mesh.material_override = m
    mesh.position = p
    add_child(mesh)
    if solid:
        var body := StaticBody3D.new()
        body.position = p
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = s
        collision.shape = shape
        body.add_child(collision)
        add_child(body)
    return mesh

func _arena() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("657b90")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b8c8d8")
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.ssao_enabled = not mobile
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-53, -38, 0)
    sun.light_energy = 1.6
    sun.shadow_enabled = true
    add_child(sun)
    var concrete := mat(Color("555b61"))
    var light_concrete := mat(Color("82858a"))
    var steel := mat(Color("323e48"), 0.72, 0.3)
    var rust := mat(Color("7c422d"), 0.25)
    var yellow := mat(Color("dfaa37"), 0.22)
    var glass := mat(Color("60a8c0"), 0.25, 0.14)
    cube(Vector3(0,-0.4,0), Vector3(76,0.8,76), concrete)
    for i in range(19):
        cube(Vector3(-36 + i * 4,0.015,-8), Vector3(1.8,0.025,0.12), yellow, false)
        cube(Vector3(-36 + i * 4,0.015,8), Vector3(1.8,0.025,0.12), yellow, false)
    for x in [-37.0,37.0]:
        cube(Vector3(x,6,0), Vector3(1,12,74), light_concrete)
        for z in range(-30,31,10):
            cube(Vector3(x + (0.55 if x < 0 else -0.55),7,z), Vector3(0.12,3.4,5), steel, false)
    for z in [-37.0,37.0]:
        cube(Vector3(0,6,z), Vector3(74,12,1), light_concrete)
    for i in range(26):
        var x := float((i * 19) % 61 - 30)
        var z := float((i * 31) % 59 - 29)
        if absf(x) < 7 and absf(z) < 13: continue
        var h := float(2 + i % 3)
        cube(Vector3(x,h/2,z), Vector3(3.7,h,2.7), rust if i % 3 == 0 else steel)
        for rib in range(3):
            cube(Vector3(x - 1.4 + rib * 1.4,h/2,z+1.37),Vector3(0.08,h,0.08),light_concrete,false)
        cube(Vector3(x,h+0.1,z),Vector3(3.9,0.2,2.9),steel)
    for x in [-24.0,-8.0,8.0,24.0]:
        for z in [-24.0,0.0,24.0]:
            cube(Vector3(x,5,z),Vector3(0.5,10,0.5),steel)
            cube(Vector3(x,10,z),Vector3(7,0.4,0.6),steel)
            cube(Vector3(x,8.8,z),Vector3(2.2,1.1,0.12),glass,false)
    for i in range(10):
        var z := -32.0 + i * 7
        cube(Vector3(-34,2,z),Vector3(0.18,4,0.18),yellow,false)
    for x in [-20.0,0.0,20.0]:
        var lamp := OmniLight3D.new()
        lamp.position = Vector3(x,8,-18)
        lamp.light_color = Color("ffdfaa")
        lamp.light_energy = 0.9
        lamp.omni_range = 16
        lamp.shadow_enabled = not mobile
        add_child(lamp)

func _player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0,1.4,14)
    add_child(player)
    var capsule := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.8
    capsule.shape = shape
    player.add_child(capsule)
    camera = Camera3D.new()
    camera.position.y = 0.62
    camera.current = true
    player.add_child(camera)
    var gun := Node3D.new()
    gun.position = Vector3(0.32,-0.3,-0.65)
    camera.add_child(gun)
    var black := mat(Color("171d23"),0.75,0.24)
    var grip := mat(Color("34383b"),0.18,0.82)
    _gun_piece(gun,Vector3(0,0,-0.22),Vector3(0.16,0.15,0.55),black)
    _gun_piece(gun,Vector3(0,-0.15,-0.04),Vector3(0.09,0.3,0.14),grip)
    _gun_piece(gun,Vector3(0,0.1,-0.24),Vector3(0.08,0.1,0.3),black)
    _gun_piece(gun,Vector3(0,-0.11,-0.27),Vector3(0.12,0.24,0.12),grip)
    _gun_piece(gun,Vector3(0,0,-0.57),Vector3(0.08,0.08,0.3),black)
    enemy_mat = mat(Color("b64c43"),0.1)
    opponent = Node3D.new()
    opponent.position = opponent_target
    add_child(opponent)
    var torso := MeshInstance3D.new()
    var torso_mesh := CapsuleMesh.new()
    torso_mesh.radius = 0.43
    torso_mesh.height = 1.7
    torso.mesh = torso_mesh
    torso.material_override = enemy_mat
    opponent.add_child(torso)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.29
    head_mesh.height = 0.58
    head.mesh = head_mesh
    head.position.y = 1.08
    head.material_override = mat(Color("d3b69a"))
    opponent.add_child(head)
    opponent.visible = false

func _gun_piece(parent: Node3D, p: Vector3, s: Vector3, m: Material) -> void:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = s
    part.mesh = mesh
    part.material_override = m
    part.position = p
    parent.add_child(part)

func _interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)
    hud = Label.new()
    hud.position = Vector2(18,16)
    hud.add_theme_font_size_override("font_size",24)
    root.add_child(hud)
    var cross := Label.new()
    cross.text = "+"
    cross.add_theme_font_size_override("font_size",32)
    cross.set_anchors_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-9,-20)
    root.add_child(cross)
    var panel := HBoxContainer.new()
    panel.position = Vector2(18,55)
    root.add_child(panel)
    var host := Button.new()
    host.text = "HOST"
    host.pressed.connect(_host)
    panel.add_child(host)
    address_field = LineEdit.new()
    address_field.custom_minimum_size.x = 210
    address_field.placeholder_text = "Host IP (LAN / public IP)"
    panel.add_child(address_field)
    var join := Button.new()
    join.text = "JOIN"
    join.pressed.connect(_join)
    panel.add_child(join)
    var release := Button.new()
    release.text = "PLAY / LOCK MOUSE"
    release.pressed.connect(func(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
    panel.add_child(release)
    status_label = Label.new()
    status_label.position = Vector2(18,94)
    status_label.text = "Offline | HOST on one device, JOIN by IP on another"
    root.add_child(status_label)
    if mobile:
        var shoot_button := Button.new()
        shoot_button.text = "FIRE"
        shoot_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        shoot_button.position = Vector2(-135,-150)
        shoot_button.custom_minimum_size = Vector2(120,100)
        shoot_button.button_down.connect(func(): touch_fire = true)
        shoot_button.button_up.connect(func(): touch_fire = false)
        root.add_child(shoot_button)
        var reload_button := Button.new()
        reload_button.text = "RELOAD"
        reload_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        reload_button.position = Vector2(-140,-210)
        reload_button.pressed.connect(func(): ammo = 30)
        root.add_child(reload_button)
    _refresh_hud()

func _set_status(s: String) -> void:
    status_label.text = s

func _host() -> void:
    network = ENetMultiplayerPeer.new()
    var err := network.create_server(PORT, 1)
    if err != OK:
        _set_status("HOST failed: %s" % err)
        return
    multiplayer.multiplayer_peer = network
    _set_status("HOST listening on UDP %d. Share your IP." % PORT)
    opponent.visible = false

func _join() -> void:
    if address_field.text.strip_edges().is_empty():
        _set_status("Enter host IP first")
        return
    network = ENetMultiplayerPeer.new()
    var err := network.create_client(address_field.text.strip_edges(), PORT)
    if err != OK:
        _set_status("JOIN failed: %s" % err)
        return
    multiplayer.multiplayer_peer = network
    _set_status("Connecting...")

func _peer_connected(_id: int) -> void:
    opponent.visible = true
    _set_status("Opponent connected! 1v1 ready")

func _peer_disconnected(_id: int) -> void:
    opponent.visible = false
    _set_status("Opponent disconnected")

@rpc("any_peer", "call_remote", "unreliable")
func opponent_state(pos: Vector3, facing: float) -> void:
    opponent_target = pos
    opponent.rotation.y = facing
    opponent.visible = true

@rpc("any_peer", "call_remote", "reliable")
func opponent_hit() -> void:
    health = maxi(0, health - 20)
    if health == 0:
        health = 100
        player.global_position = Vector3(0,1.4,14 if multiplayer.is_server() else -14)
    _refresh_hud()

func _refresh_hud() -> void:
    hud.text = "STRIKE DUEL  |  HP %d  |  AMMO %d/30  |  HITS %d" % [health,ammo,hits]

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        if event.keycode == KEY_R: ammo = 30; _refresh_hud()
    if not mobile and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _look(event.relative)
    if mobile and event is InputEventScreenTouch:
        if event.pressed and event.position.y > get_viewport().get_visible_rect().size.y * 0.48:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.48 and touch_move_id == -1:
                touch_move_id = event.index
                move_start = event.position
            elif touch_look_id == -1:
                touch_look_id = event.index
        elif not event.pressed:
            if event.index == touch_move_id: touch_move_id = -1; touch_move = Vector2.ZERO
            if event.index == touch_look_id: touch_look_id = -1
    if mobile and event is InputEventScreenDrag:
        if event.index == touch_move_id: touch_move = (event.position - move_start).limit_length(90) / 90.0
        if event.index == touch_look_id: _look(event.relative * 1.25)

func _look(relative: Vector2) -> void:
    yaw -= relative.x * 0.002
    pitch = clampf(pitch - relative.y * 0.002, -1.35, 1.35)
    player.rotation.y = yaw
    camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
    var move := Vector2.ZERO
    if Input.is_action_pressed("move_forward"): move.y -= 1
    if Input.is_action_pressed("move_back"): move.y += 1
    if Input.is_action_pressed("move_left"): move.x -= 1
    if Input.is_action_pressed("move_right"): move.x += 1
    if mobile: move += touch_move
    move = move.limit_length(1.0)
    var direction := player.global_transform.basis * Vector3(move.x,0,move.y)
    player.velocity.x = direction.x * SPEED
    player.velocity.z = direction.z * SPEED
    player.velocity.y -= 22.0 * delta
    player.move_and_slide()
    cooldown = maxf(0.0,cooldown - delta)
    if (touch_fire or (Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)) and cooldown <= 0 and ammo > 0:
        _fire()
    if opponent.visible:
        opponent.position = opponent.position.lerp(opponent_target,minf(1.0,delta*12.0))
    send_timer += delta
    if send_timer > 0.05 and multiplayer.multiplayer_peer != null:
        send_timer = 0.0
        opponent_state.rpc(player.global_position, yaw)

func _fire() -> void:
    cooldown = 0.13
    ammo -= 1
    var start := camera.global_position
    var end := start - camera.global_transform.basis.z * 110.0
    var query := PhysicsRayQueryParameters3D.create(start,end)
    query.exclude = [player.get_rid()]
    var collision := get_world_3d().direct_space_state.intersect_ray(query)
    var distance := 110.0
    if not collision.is_empty(): distance = start.distance_to(collision.position)
    if opponent.visible:
        var to_enemy := opponent.global_position + Vector3(0,0.5,0) - start
        var aim := -camera.global_transform.basis.z
        if to_enemy.length() < distance and to_enemy.length() < 110 and aim.dot(to_enemy.normalized()) > 0.985:
            hits += 1
            if multiplayer.multiplayer_peer != null: opponent_hit.rpc()
    _refresh_hud()
