extends Node3D
# =============================================================================
#  MINI GTA — 3D-игра в стиле GTA для Android (движок Godot 4).
#
#  ВСЁ В ОДНОМ ФАЙЛЕ: мир, игрок, машины, пешеходы, пули, HUD и миникарта
#  создаются прямо в коде. Внешние ассеты не нужны — только примитивы Godot
#  (кубы, капсулы, цилиндры, сферы).
#
#  УПРАВЛЕНИЕ НА ПК:
#    WASD — ходьба, Shift — бег, Space — прыжок, мышь — обзор,
#    ЛКМ — выстрел, E — сесть в машину / выйти.
#    В машине: W/S — газ и тормоз, A/D — руль.
#
#  УПРАВЛЕНИЕ НА ANDROID:
#    Джойстик слева внизу — движение, свайп справа — обзор,
#    кнопки справа: выстрел, прыжок, машина.
#    В машине: кнопки газ / тормоз / руль влево-вправо.
#
#  ВАЖНО ПРО ТИПЫ: в Godot 4 предупреждение «тип выведен из Variant»
#  считается ошибкой при сборке. Поэтому там, где значение берётся из
#  нетипизированного источника (например, узел из группы), тип указывается
#  явно, а не через ":=".
# =============================================================================

# ----------------------------- НАСТРОЙКИ МИРА --------------------------------
const BLOCK := 20.0                 # размер одного квартала (м)
const GRID := 10                    # мир 10x10 кварталов (~200x200 м)
const ROAD_W := 7.0                 # ширина дороги (м)
const WORLD_SIZE := GRID * BLOCK    # полный размер мира (200 м)

var player = null                   # ссылка на игрока (создаётся ниже)


func _ready() -> void:
    randomize()
    _build_environment()   # небо и солнце
    _build_ground()        # газон-основание с коллизией
    _build_roads()         # сетка дорог
    _build_buildings()     # здания-коробки в кварталах
    _build_props()         # деревья и фонари
    _spawn_player()        # игрок
    _spawn_cars()          # машины (движутся по дорогам)
    _spawn_peds()          # пешеходы
    _build_ui()            # здоровье, оружие, джойстик, миникарта


# ---------------------------- ОКРУЖЕНИЕ --------------------------------------
func _build_environment() -> void:
    # Небо + мягкий свет окружения
    var we := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.30, 0.55, 0.95)
    sky_mat.sky_horizon_color = Color(0.80, 0.87, 0.95)
    sky_mat.ground_bottom_color = Color(0.25, 0.28, 0.25)
    sky_mat.ground_horizon_color = Color(0.80, 0.87, 0.95)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.7
    we.environment = env
    add_child(we)

    # Солнце с тенями
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.light_energy = 1.1
    sun.shadow_enabled = true
    add_child(sun)


# ---------------------------- ЗЕМЛЯ И ДОРОГИ ---------------------------------
func _mat(color: Color) -> StandardMaterial3D:
    # Вспомогательная функция: простой материал нужного цвета
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    return m


func _build_ground() -> void:
    # Сплошная плита-газон под всем городом. Есть коллизия — по ней ходят.
    var body := StaticBody3D.new()
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(WORLD_SIZE, 1.0, WORLD_SIZE)
    mesh.mesh = box
    mesh.material_override = _mat(Color(0.28, 0.5, 0.26))
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box.size
    col.shape = shape
    body.add_child(mesh)
    body.add_child(col)
    body.position.y = -0.5
    add_child(body)


func _build_roads() -> void:
    # Асфальтовые полосы по границам кварталов: получается сетка дорог.
    var road_mat := _mat(Color(0.13, 0.13, 0.15))
    for k in range(GRID + 1):
        var p := (k - GRID / 2.0) * BLOCK

        # Горизонтальная дорога (тянется вдоль оси X)
        var h := MeshInstance3D.new()
        var hb := BoxMesh.new()
        hb.size = Vector3(WORLD_SIZE, 0.1, ROAD_W)
        h.mesh = hb
        h.material_override = road_mat
        h.position = Vector3(0.0, 0.05, p)
        add_child(h)

        # Вертикальная дорога (тянется вдоль оси Z)
        var v := MeshInstance3D.new()
        var vb := BoxMesh.new()
        vb.size = Vector3(ROAD_W, 0.1, WORLD_SIZE)
        v.mesh = vb
        v.material_override = road_mat
        v.position = Vector3(p, 0.05, 0.0)
        add_child(v)


# ---------------------------- ЗДАНИЯ -----------------------------------------
func _build_buildings() -> void:
    # В каждом квартале — здание-коробка случайной высоты и цвета.
    # Здание меньше квартала, поэтому вокруг остаются «тротуары».
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261007
    for i in range(GRID):
        for j in range(GRID):
            var h := rng.randf_range(6.0, 26.0)
            var w := rng.randf_range(4.0, 7.0)
            var d := rng.randf_range(4.0, 7.0)

            var body := StaticBody3D.new()
            var mesh := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(w, h, d)
            mesh.mesh = box
            mesh.material_override = _mat(Color.from_hsv(rng.randf(), 0.25, 0.85))

            var col := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = box.size
            col.shape = shape

            body.add_child(mesh)
            body.add_child(col)
            body.position = Vector3(
                (i - GRID / 2.0 + 0.5) * BLOCK,
                h / 2.0,
                (j - GRID / 2.0 + 0.5) * BLOCK)
            body.add_to_group("buildings")
            add_child(body)


# ---------------------------- ДЕРЕВЬЯ И ФОНАРИ -------------------------------
func _tree(pos: Vector3, trunk_mat: StandardMaterial3D, crown_mat: StandardMaterial3D) -> void:
    # Дерево = ствол-цилиндр + крона-сфера (без коллизии, для красоты)
    var trunk := MeshInstance3D.new()
    var tb := CylinderMesh.new()
    tb.top_radius = 0.25
    tb.bottom_radius = 0.35
    tb.height = 3.0
    trunk.mesh = tb
    trunk.material_override = trunk_mat
    trunk.position = pos + Vector3(0.0, 1.5, 0.0)
    add_child(trunk)

    var crown := MeshInstance3D.new()
    var cb := SphereMesh.new()
    cb.radius = 1.4
    cb.height = 2.8
    crown.mesh = cb
    crown.material_override = crown_mat
    crown.position = pos + Vector3(0.0, 3.6, 0.0)
    add_child(crown)


func _lamp(pos: Vector3, pole_mat: StandardMaterial3D, bulb_mat: StandardMaterial3D) -> void:
    # Фонарь = столб + светящийся шар + точечный свет
    var pole := MeshInstance3D.new()
    var pb := CylinderMesh.new()
    pb.top_radius = 0.08
    pb.bottom_radius = 0.12
    pb.height = 5.0
    pole.mesh = pb
    pole.material_override = pole_mat
    pole.position = pos + Vector3(0.0, 2.5, 0.0)
    add_child(pole)

    var bulb := MeshInstance3D.new()
    var sb := SphereMesh.new()
    sb.radius = 0.22
    sb.height = 0.44
    bulb.mesh = sb
    bulb.material_override = bulb_mat
    bulb.position = pos + Vector3(0.0, 5.1, 0.0)
    add_child(bulb)

    var light := OmniLight3D.new()
    light.position = pos + Vector3(0.0, 5.0, 0.0)
    light.light_energy = 1.0
    light.omni_range = 11.0
    light.shadow_enabled = false   # экономим производительность на телефоне
    add_child(light)


func _build_props() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 555
    var trunk_mat := _mat(Color(0.35, 0.22, 0.12))
    var crown_mat := _mat(Color(0.13, 0.45, 0.16))
    var pole_mat := _mat(Color(0.25, 0.25, 0.28))
    var bulb_mat := _mat(Color(1.0, 0.95, 0.7))
    bulb_mat.emission_enabled = true
    bulb_mat.emission = Color(1.0, 0.9, 0.6)

    for i in range(GRID):
        for j in range(GRID):
            if (i + j) % 2 != 0:
                continue   # застраиваем через квартал — так легче телефону
            var c := Vector3(
                (i - GRID / 2.0 + 0.5) * BLOCK,
                0.0,
                (j - GRID / 2.0 + 0.5) * BLOCK)
            _tree(c + Vector3(6.5, 0.0, 0.0), trunk_mat, crown_mat)
            _tree(c + Vector3(-6.5, 0.0, 0.0), trunk_mat, crown_mat)
            _lamp(c + Vector3(8.0, 0.0, 8.0), pole_mat, bulb_mat)


# ---------------------------- СПАВН ОБЪЕКТОВ ---------------------------------
func _spawn_player() -> void:
    player = PlayerBody.new()
    player.position = Vector3(0.0, 1.2, 0.0)   # центральный перекрёсток
    add_child(player)


func _spawn_cars() -> void:
    # Позиция + угол поворота (машина всегда едет вперёд по своей оси -Z)
    var spots = [
        [Vector3(1.8, 0.5, -60.0), -PI / 2.0],   # едет по +X
        [Vector3(-1.8, 0.5, 60.0), PI / 2.0],    # едет по -X
        [Vector3(60.0, 0.5, 1.8), 0.0],          # едет по -Z
        [Vector3(-60.0, 0.5, -1.8), PI],         # едет по +Z
        [Vector3(30.0, 0.5, 1.8), 0.0],
        [Vector3(-30.0, 0.5, -1.8), PI],
        [Vector3(1.8, 0.5, 20.0), -PI / 2.0],
        [Vector3(-40.0, 0.5, 80.0), PI / 2.0],
    ]
    for s in spots:
        var c := CarBody.new()
        c.position = s[0]
        c.rotation.y = s[1]
        add_child(c)


func _spawn_peds() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 31415
    for n in range(16):
        var ci := rng.randi_range(0, GRID - 1)
        var cj := rng.randi_range(0, GRID - 1)
        var base := Vector3(
            (ci - GRID / 2.0 + 0.5) * BLOCK,
            1.2,
            (cj - GRID / 2.0 + 0.5) * BLOCK)
        var side := rng.randi_range(0, 3)
        var off := Vector3.ZERO
        if side == 0:
            off = Vector3(6.5, 0.0, 0.0)
        elif side == 1:
            off = Vector3(-6.5, 0.0, 0.0)
        elif side == 2:
            off = Vector3(0.0, 0.0, 6.5)
        else:
            off = Vector3(0.0, 0.0, -6.5)
        var p := PedBody.new()
        p.position = base + off
        add_child(p)


# ---------------------------- ИНТЕРФЕЙС --------------------------------------
func _build_ui() -> void:
    var hud := GameHUD.new()
    add_child(hud)


# =============================================================================
#  ВНУТРЕННИЕ КЛАССЫ — вся игровая логика
# =============================================================================

# ------------------------------- ИГРОК ---------------------------------------
class PlayerBody extends CharacterBody3D:
    const SPEED := 6.0          # скорость ходьбы, м/с
    const SPRINT := 10.0        # скорость бега
    const JUMP := 6.0           # сила прыжка
    const GRAVITY := 20.0
    const MAX_HEALTH := 100.0
    const SHOOT_CD := 0.22      # перезарядка оружия (патроны бесконечны)
    const SENS := 0.0035        # чувствительность обзора

    var health := MAX_HEALTH
    var cooldown := 0.0
    var camera: Camera3D
    var cam_pitch := -0.18      # наклон камеры вверх/вниз
    var current_car = null      # машина, в которой сидит игрок (или null)
    var mobile_move := Vector2.ZERO   # вектор с экранного джойстика

    func _ready() -> void:
        add_to_group("player")

        # --- физика: капсула высотой 1.8 м ---
        var col := CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.4
        cap.height = 1.8
        col.shape = cap
        col.position.y = 0.9
        add_child(col)

        # --- внешний вид: синяя капсула + «лицо» ---
        var body := MeshInstance3D.new()
        var bm := CapsuleMesh.new()
        bm.radius = 0.4
        bm.height = 1.8
        body.mesh = bm
        body.material_override = _local_mat(Color(0.20, 0.45, 0.95))
        body.position.y = 0.9
        add_child(body)

        var nose := MeshInstance3D.new()
        var nm := BoxMesh.new()
        nm.size = Vector3(0.2, 0.2, 0.3)
        nose.mesh = nm
        nose.material_override = _local_mat(Color(1.0, 0.85, 0.2))
        nose.position = Vector3(0.0, 1.5, -0.45)
        add_child(nose)

        # --- камера от третьего лица ---
        camera = Camera3D.new()
        camera.position = Vector3(0.0, 2.4, 5.0)
        camera.rotation = Vector3(cam_pitch, 0.0, 0.0)
        camera.current = true
        add_child(camera)

        # На ПК захватываем мышь для обзора
        if not OS.has_feature("mobile"):
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    func _local_mat(c: Color) -> StandardMaterial3D:
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        return m

    func _input(event: InputEvent) -> void:
        # E — вход/выход из машины (работает всегда)
        if event is InputEventKey and event.pressed and not event.echo:
            if event.keycode == KEY_E:
                toggle_car()
                return
            if event.keycode == KEY_SPACE and current_car == null and is_on_floor():
                velocity.y = JUMP
                return

        if current_car != null:
            return   # за рулём обзор не крутим — камера привязана к машине

        # --- обзор: мышь на ПК ---
        if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            rotate_y(-event.relative.x * SENS)
            cam_pitch = clamp(cam_pitch - event.relative.y * SENS, -0.85, 0.45)
        # --- выстрел: левая кнопка мыши ---
        elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            shoot()
        # --- обзор: свайп по правой части экрана (Android) ---
        elif event is InputEventScreenDrag:
            var vw: float = get_viewport().get_visible_rect().size.x
            if event.position.x > vw * 0.6:
                rotate_y(-event.relative.x * SENS * 1.6)
                cam_pitch = clamp(cam_pitch - event.relative.y * SENS * 1.6, -0.85, 0.45)

    func _process(_delta: float) -> void:
        # Держим наклон камеры там, куда её повернул игрок
        if camera:
            camera.rotation.x = cam_pitch

    func _physics_process(delta: float) -> void:
        if current_car != null:
            return   # за рулём игрок не ходит
        cooldown = max(0.0, cooldown - delta)

        # Гравитация
        if not is_on_floor():
            velocity.y -= GRAVITY * delta

        # Направление движения: клавиатура + экранный джойстик
        var ix := 0.0
        var iz := 0.0
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            ix += 1.0
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            ix -= 1.0
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            iz += 1.0
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            iz -= 1.0
        if mobile_move.length() > 0.15:
            ix = mobile_move.x
            iz = mobile_move.y

        var dir := global_transform.basis * Vector3(ix, 0.0, iz)
        dir.y = 0.0
        if dir.length() > 0.01:
            dir = dir.normalized()
        else:
            dir = Vector3.ZERO

        var spd := SPRINT if Input.is_key_pressed(KEY_SHIFT) else SPEED
        velocity.x = dir.x * spd
        velocity.z = dir.z * spd

        move_and_slide()

    # Стрельба: пуля из позиции игрока в сторону взгляда камеры
    func shoot() -> void:
        if cooldown > 0.0 or current_car != null:
            return
        cooldown = SHOOT_CD
        var b := BulletBody.new()
        get_tree().current_scene.add_child(b)
        var aim := -camera.global_transform.basis.z.normalized()
        b.global_position = global_position + Vector3(0.0, 1.4, 0.0) + aim * 1.0
        b.direction = aim
        b.shooter = self

    # Сесть в ближайшую машину / выйти из текущей
    func toggle_car() -> void:
        if current_car != null:
            current_car.exit_car(self)
            return
        var best = null
        var best_d := 5.0
        for c in get_tree().get_nodes_in_group("cars"):
            # Тип указываем явно: значение приходит из нетипизированного списка
            var d: float = global_position.distance_to(c.global_position)
            if d < best_d:
                best_d = d
                best = c
        if best != null:
            best.enter_car(self)

    # Урон (например, наезд машины). При нуле здоровья — возрождение.
    func take_damage(amount: float) -> void:
        health = max(0.0, health - amount)
        if health <= 0.0:
            health = MAX_HEALTH
            if current_car != null:
                current_car.exit_car(self)
            global_position = Vector3(0.0, 1.5, 0.0)
            velocity = Vector3.ZERO


# ------------------------------- МАШИНА --------------------------------------
class CarBody extends CharacterBody3D:
    const MAX_SPEED := 20.0     # максимальная скорость, м/с
    const REVERSE_SPEED := 7.0  # максимальная скорость назад
    const ACCEL := 14.0         # разгон
    const BRAKE := 26.0         # торможение
    const TURN := 1.7           # скорость поворота руля, рад/с
    const GRAVITY := 20.0
    const EDGE := 96.0          # граница мира для разворота ИИ

    var speed := 0.0
    var driver = null            # игрок за рулём (или null)
    var mobile_throttle := 0.0   # газ/тормоз с экранных кнопок
    var mobile_steer := 0.0      # руль с экранных кнопок
    var hit_cd := 0.0            # задержка между наездами на игрока

    func _ready() -> void:
        add_to_group("cars")

        # Коллизия: коробка 2 x 1.2 x 4 (ширина, высота, длина)
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(2.0, 1.2, 4.0)
        col.shape = shape
        col.position.y = 0.6
        add_child(col)

        # Кузов случайного цвета
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(2.0, 0.9, 4.0)
        body.mesh = bm
        var bmat := StandardMaterial3D.new()
        bmat.albedo_color = Color.from_hsv(randf(), 0.65, 0.85)
        body.material_override = bmat
        body.position.y = 0.65
        add_child(body)

        # Кабина
        var cabin := MeshInstance3D.new()
        var cm := BoxMesh.new()
        cm.size = Vector3(1.7, 0.7, 1.8)
        cabin.mesh = cm
        var cmat := StandardMaterial3D.new()
        cmat.albedo_color = Color(0.15, 0.18, 0.25)
        cabin.material_override = cmat
        cabin.position = Vector3(0.0, 1.25, 0.1)
        add_child(cabin)

        # 4 колеса
        var wmat := StandardMaterial3D.new()
        wmat.albedo_color = Color(0.08, 0.08, 0.08)
        var wheels = [
            Vector3(-0.95, 0.4, 1.35), Vector3(0.95, 0.4, 1.35),
            Vector3(-0.95, 0.4, -1.35), Vector3(0.95, 0.4, -1.35)]
        for wp in wheels:
            var w := MeshInstance3D.new()
            var cyl := CylinderMesh.new()
            cyl.top_radius = 0.4
            cyl.bottom_radius = 0.4
            cyl.height = 0.3
            w.mesh = cyl
            w.material_override = wmat
            w.rotation_degrees = Vector3(0.0, 0.0, 90.0)
            w.position = wp
            add_child(w)

    func _physics_process(delta: float) -> void:
        hit_cd = max(0.0, hit_cd - delta)

        # Гравитация
        if not is_on_floor():
            velocity.y -= GRAVITY * delta
        else:
            velocity.y = 0.0

        var throttle := 0.0
        var steer := 0.0

        if driver != null:
            # ---------- МАШИНОЙ УПРАВЛЯЕТ ИГРОК ----------
            if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
                throttle += 1.0
            if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
                throttle -= 1.0
            if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
                steer += 1.0
            if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
                steer -= 1.0
            throttle = clamp(throttle + mobile_throttle, -1.0, 1.0)
            steer = clamp(steer + mobile_steer, -1.0, 1.0)

            if throttle > 0.05:
                speed = move_toward(speed, MAX_SPEED, ACCEL * delta)
            elif throttle < -0.05:
                speed = move_toward(speed, -REVERSE_SPEED, BRAKE * delta)
            else:
                speed = move_toward(speed, 0.0, BRAKE * 0.4 * delta)
        else:
            # ---------- ПРОСТОЙ ИИ: едем прямо, объезжаем препятствия ----------
            var forward := -global_transform.basis.z
            var space := get_world_3d().direct_space_state
            var from := global_position + Vector3(0.0, 0.7, 0.0)
            var query := PhysicsRayQueryParameters3D.create(from, from + forward * 8.0)
            query.exclude = [get_rid()]
            var hit := space.intersect_ray(query)
            if not hit.is_empty():
                # Впереди стена, машина или игрок — тормозим и поворачиваем
                speed = move_toward(speed, 0.0, BRAKE * delta)
                steer = 1.0
            else:
                speed = move_toward(speed, MAX_SPEED * 0.45, ACCEL * delta)
                steer = 0.0
            # У края мира — разворот, чтобы машина не уехала в пустоту
            if abs(global_position.x) > EDGE or abs(global_position.z) > EDGE:
                rotate_y(PI)

        # Поворот руля (эффективность зависит от скорости)
        if abs(speed) > 0.15 and abs(steer) > 0.01:
            var grip := clamp(abs(speed) / MAX_SPEED, 0.3, 1.0)
            rotate_y(steer * TURN * grip * delta * sign(speed))

        # Едем вперёд по своей оси -Z
        var fwd := -global_transform.basis.z
        velocity.x = fwd.x * speed
        velocity.z = fwd.z * speed

        move_and_slide()

        # Столкновение: гасим скорость, ИИ слегка отскакивает
        if get_slide_collision_count() > 0:
            if driver == null and abs(speed) > 8.0:
                speed = -speed * 0.3
            else:
                speed = move_toward(speed, 0.0, 40.0 * delta)

        # Наезд на игрока уменьшает его здоровье
        if driver == null and hit_cd <= 0.0:
            var pl = get_tree().get_first_node_in_group("player")
            if pl != null and global_position.distance_to(pl.global_position) < 3.0 and abs(speed) > 6.0:
                pl.take_damage(30.0)
                hit_cd = 1.5

    # Игрок садится за руль: его камера переезжает к машине
    func enter_car(p) -> void:
        driver = p
        p.current_car = self
        p.global_position = global_position      # прячем игрока внутри машины
        p.visible = false
        p.set_physics_process(false)
        # Тип не выводим через ":=" — p приходит как Variant
        var cam = p.camera
        cam.reparent(self, false)
        cam.position = Vector3(0.0, 3.4, 7.5)    # камера сзади-сверху
        cam.rotation = Vector3(-0.25, 0.0, 0.0)
        p.cam_pitch = -0.25

    # Игрок выходит из машины
    func exit_car(p) -> void:
        driver = null
        p.current_car = null
        speed = 0.0
        # Тип не выводим через ":=" — p приходит как Variant
        var cam = p.camera
        cam.reparent(p, false)
        cam.position = Vector3(0.0, 2.4, 5.0)
        cam.rotation = Vector3(p.cam_pitch, 0.0, 0.0)
        p.global_position = global_position + Vector3(2.6, 1.0, 0.0)
        p.velocity = Vector3.ZERO
        p.visible = true
        p.set_physics_process(true)


# ------------------------------- ПУЛЯ ----------------------------------------
class BulletBody extends Node3D:
    const SPEED := 70.0    # скорость пули, м/с
    const LIFE := 2.0      # время жизни, с

    var direction := Vector3.FORWARD
    var shooter = null
    var life := LIFE

    func _ready() -> void:
        var mi := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.12
        sm.height = 0.24
        mi.mesh = sm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(1.0, 0.9, 0.2)
        mat.emission_enabled = true
        mat.emission = Color(1.0, 0.8, 0.1)
        mi.material_override = mat
        add_child(mi)

    func _physics_process(delta: float) -> void:
        life -= delta
        if life <= 0.0:
            queue_free()
            return

        # Луч из текущей позиции в следующую — так пуля не «проскакивает» цели
        var from := global_position
        var to := from + direction * SPEED * delta
        var query := PhysicsRayQueryParameters3D.create(from, to)
        if shooter is CollisionObject3D:
            query.exclude = [(shooter as CollisionObject3D).get_rid()]
        var hit := get_world_3d().direct_space_state.intersect_ray(query)

        if hit.is_empty():
            global_position = to
        else:
            _impact(hit.get("collider"))

    func _impact(obj) -> void:
        if obj != null and obj is Node:
            if obj.is_in_group("peds"):
                obj.hit()              # пешеход реагирует на выстрел
            elif obj.is_in_group("cars"):
                obj.speed *= 0.6       # машину пуля слегка тормозит
        queue_free()


# ------------------------------ ПЕШЕХОД --------------------------------------
class PedBody extends CharacterBody3D:
    const SPEED := 1.5
    const GRAVITY := 20.0

    var dir := Vector3.FORWARD
    var timer := 0.0
    var health := 10

    func _ready() -> void:
        add_to_group("peds")

        var col := CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.3
        cap.height = 1.7
        col.shape = cap
        col.position.y = 0.85
        add_child(col)

        var mi := MeshInstance3D.new()
        var bm := CapsuleMesh.new()
        bm.radius = 0.3
        bm.height = 1.7
        mi.mesh = bm
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color.from_hsv(randf(), 0.5, 0.95)
        mi.material_override = mat
        mi.position.y = 0.85
        add_child(mi)

        timer = randf_range(0.5, 3.0)

    func _physics_process(delta: float) -> void:
        if not is_on_floor():
            velocity.y -= GRAVITY * delta

        # Раз в несколько секунд выбираем новое направление
        timer -= delta
        if timer <= 0.0:
            timer = randf_range(2.0, 6.0)
            dir = Vector3.FORWARD.rotated(Vector3.UP, randf_range(0.0, TAU))

        velocity.x = dir.x * SPEED
        velocity.z = dir.z * SPEED
        move_and_slide()

        # Упёрлись в здание — поворачиваем
        if get_slide_collision_count() > 0:
            dir = dir.rotated(Vector3.UP, PI * 0.6)

        look_at(global_position + dir, Vector3.UP)

    # Попадание пули: пешеход исчезает после двух попаданий
    func hit() -> void:
        health -= 5
        if health <= 0:
            queue_free()
        else:
            scale = Vector3(0.9, 1.15, 0.9)


# --------------------------- ЭКРАННЫЙ ДЖОЙСТИК -------------------------------
class JoyPad extends Control:
    var value := Vector2.ZERO   # x: влево-вправо, y: вперёд-назад
    var radius := 95.0
    var active := -1
    var origin := Vector2.ZERO
    var knob := Vector2.ZERO

    func _ready() -> void:
        size = Vector2(radius * 2.0, radius * 2.0)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var c := Vector2(radius, radius)
        draw_circle(c, radius, Color(1, 1, 1, 0.15))
        draw_arc(c, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
        draw_circle(c + knob * (radius * 0.55), radius * 0.38, Color(1, 1, 1, 0.45))

    func _input(event: InputEvent) -> void:
        if event is InputEventScreenTouch:
            if event.pressed and active == -1 and get_global_rect().has_point(event.position):
                active = event.index
                origin = get_global_rect().get_center()
                _update(event.position - origin)
            elif not event.pressed and event.index == active:
                _reset()
        elif event is InputEventScreenDrag and event.index == active:
            _update(event.position - origin)

    func _update(offset: Vector2) -> void:
        var d := offset / radius
        if d.length() > 1.0:
            d = d.normalized()
        knob = d
        value = d
        queue_redraw()

    func _reset() -> void:
        active = -1
        knob = Vector2.ZERO
        value = Vector2.ZERO
        queue_redraw()


# ------------------------------ МИНИКАРТА ------------------------------------
class MiniMap extends Control:
    const MAP := 180.0
    const WORLD := 200.0

    func _ready() -> void:
        size = Vector2(MAP, MAP)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _process(_delta: float) -> void:
        queue_redraw()

    func _draw() -> void:
        # Фон и рамка
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.08, 0.55), true)
        draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)

        # Ориентиры: здания
        for b in get_tree().get_nodes_in_group("buildings"):
            _dot(b.global_position, Color(0.6, 0.6, 0.65), 1.6)
        # Машины
        for c in get_tree().get_nodes_in_group("cars"):
            _dot(c.global_position, Color(1.0, 0.35, 0.35), 3.0)
        # Пешеходы
        for p in get_tree().get_nodes_in_group("peds"):
            _dot(p.global_position, Color(0.4, 1.0, 0.4), 2.0)
        # Игрок — голубая точка
        var pl = get_tree().get_first_node_in_group("player")
        if pl != null:
            _dot(pl.global_position, Color(0.3, 0.9, 1.0), 4.0)

    func _dot(pos: Vector3, col: Color, r: float) -> void:
        var v := Vector2(pos.x / WORLD + 0.5, pos.z / WORLD + 0.5) * MAP
        draw_circle(v, r, col)


# -------------------------------- HUD ----------------------------------------
class GameHUD extends CanvasLayer:
    var player = null
    var health_bar: ProgressBar
    var weapon_label: Label
    var hint: Label
    var joy: JoyPad
    var minimap: MiniMap
    var btn_shoot: Button
    var btn_jump: Button
    var btn_car: Button
    var btn_gas: Button
    var btn_brake: Button
    var btn_left: Button
    var btn_right: Button

    func _ready() -> void:
        # --- Полоса здоровья ---
        health_bar = ProgressBar.new()
        health_bar.position = Vector2(20, 16)
        health_bar.size = Vector2(280, 26)
        health_bar.max_value = 100
        health_bar.value = 100
        health_bar.show_percentage = false
        var fill := StyleBoxFlat.new()
        fill.bg_color = Color(0.20, 0.85, 0.30)
        health_bar.add_theme_stylebox_override("fill", fill)
        var bg := StyleBoxFlat.new()
        bg.bg_color = Color(0, 0, 0, 0.45)
        health_bar.add_theme_stylebox_override("background", bg)
        add_child(health_bar)

        # --- Индикатор оружия и патронов ---
        weapon_label = Label.new()
        weapon_label.position = Vector2(22, 48)
        weapon_label.text = "Оружие: бесконечно"
        weapon_label.add_theme_font_size_override("font_size", 24)
        weapon_label.add_theme_color_override("font_color", Color(1, 1, 1))
        weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
        weapon_label.add_theme_constant_override("shadow_offset_x", 2)
        weapon_label.add_theme_constant_override("shadow_offset_y", 2)
        add_child(weapon_label)

        # --- Подсказка управления (для ПК) ---
        hint = Label.new()
        hint.position = Vector2(20, 686)
        hint.text = "WASD — идти   Shift — бег   Space — прыжок   ЛКМ — огонь   E — машина"
        hint.add_theme_font_size_override("font_size", 18)
        hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
        add_child(hint)

        # --- Джойстик слева внизу ---
        joy = JoyPad.new()
        joy.position = Vector2(60, 420)
        add_child(joy)

        # --- Миникарта справа вверху ---
        minimap = MiniMap.new()
        minimap.position = Vector2(1080, 20)
        add_child(minimap)

        # --- Кнопки пешеходного режима ---
        btn_shoot = _make_button("Огонь", Vector2(1100, 380), Vector2(140, 140))
        btn_shoot.pressed.connect(_on_shoot)

        btn_jump = _make_button("Прыжок", Vector2(930, 560), Vector2(110, 110))
        btn_jump.pressed.connect(_on_jump)

        # --- Кнопки режима вождения ---
        btn_gas = _make_button("Газ", Vector2(1150, 400), Vector2(120, 120))
        btn_gas.button_down.connect(_on_gas_down)
        btn_gas.button_up.connect(_on_gas_up)

        btn_brake = _make_button("Тормоз", Vector2(1150, 540), Vector2(120, 120))
        btn_brake.button_down.connect(_on_brake_down)
        btn_brake.button_up.connect(_on_brake_up)

        btn_left = _make_button("Влево", Vector2(930, 590), Vector2(105, 105))
        btn_left.button_down.connect(_on_left_down)
        btn_left.button_up.connect(_on_steer_up)

        btn_right = _make_button("Вправо", Vector2(1045, 620), Vector2(105, 105))
        btn_right.button_down.connect(_on_right_down)
        btn_right.button_up.connect(_on_steer_up)

        # --- Кнопка «сесть в машину / выйти» (видна всегда) ---
        btn_car = _make_button("Машина", Vector2(1100, 230), Vector2(110, 110))
        btn_car.pressed.connect(_on_car)

    func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
        var b := Button.new()
        b.text = text
        b.position = pos
        b.size = sz
        b.modulate = Color(1, 1, 1, 0.5)
        b.add_theme_font_size_override("font_size", 22)
        add_child(b)
        return b

    func _process(_delta: float) -> void:
        if player == null:
            player = get_tree().get_first_node_in_group("player")
            return

        # Здоровье и оружие
        health_bar.value = player.health
        weapon_label.text = "Перезарядка…" if player.cooldown > 0.0 else "Оружие: бесконечно"

        # Передаём вектор джойстика игроку
        player.mobile_move = joy.value

        # Показываем нужный набор кнопок
        var driving: bool = player.current_car != null
        joy.visible = not driving
        btn_shoot.visible = not driving
        btn_jump.visible = not driving
        btn_gas.visible = driving
        btn_brake.visible = driving
        btn_left.visible = driving
        btn_right.visible = driving

    # ----------------------------- ОБРАБОТЧИКИ -------------------------------
    func _on_shoot() -> void:
        if player != null:
            player.shoot()

    func _on_jump() -> void:
        if player != null and player.current_car == null and player.is_on_floor():
            player.velocity.y = 6.0     # сила прыжка

    func _on_car() -> void:
        if player != null:
            player.toggle_car()

    func _on_gas_down() -> void:
        if player != null and player.current_car != null:
            player.current_car.mobile_throttle = 1.0

    func _on_gas_up() -> void:
        if player != null and player.current_car != null:
            player.current_car.mobile_throttle = 0.0

    func _on_brake_down() -> void:
        if player != null and player.current_car != null:
            player.current_car.mobile_throttle = -1.0

    func _on_brake_up() -> void:
        if player != null and player.current_car != null:
            player.current_car.mobile_throttle = 0.0

    func _on_left_down() -> void:
        if player != null and player.current_car != null:
            player.current_car.mobile_steer = 1.0

    func _on_right_down() -> void:
        if player != null and player.current_car != null:
            player.current_car.mobile_steer = -1.0

    func _on_steer_up() -> void:
        if player != null and player.current_car != null:
            player.current_car.mobile_steer = 0.0
