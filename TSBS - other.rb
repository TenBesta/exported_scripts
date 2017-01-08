# encoding: utf8
# [130] 32494879: TSBS - other
#==============================================================================
# ** Game_Party
#------------------------------------------------------------------------------
#  This class handles parties. Information such as gold and items is included.
# Instances of this class are referenced by $game_party.
#==============================================================================

class Game_Party < Game_Unit
  # --------------------------------------------------------------------------
  # Overwrite method : actor maximum battle members
  # --------------------------------------------------------------------------
  def max_battle_members
    TSBS::ActorPos.size
  end
end
#==============================================================================
# ** Game_BattleEvent
#------------------------------------------------------------------------------
#  This class handles common events call in battle scene. It's used within
# Scene_Base and TSBS script.
#==============================================================================

class Game_BattleEvent
  #--------------------------------------------------------------------------
  # * Initialize
  #--------------------------------------------------------------------------
  def initialize
  end
  #--------------------------------------------------------------------------
  # * Refresh
  #--------------------------------------------------------------------------
  def refresh
    if @event
      @interpreter = Game_Interpreter.new
      @interpreter.setup(@event.list) 
      @event = nil
    else
      @interpreter = nil
    end
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    if @interpreter
      @interpreter.update
      unless @interpreter.running?
        @interpreter = nil 
        SceneManager.scene.status_window.open
      end
    else
      update_tsbs_event
    end
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update_tsbs_event
    if $game_temp.tsbs_event > 0
      id = $game_temp.tsbs_event
      @event = $data_common_events[id]
      $game_temp.tsbs_event = 0
      refresh
    end
  end
  #--------------------------------------------------------------------------
  # * Active?
  #--------------------------------------------------------------------------
  def active?
    !@interpreter.nil? && @interpreter.running?
  end
end

#==============================================================================
# ** Sprite_Base
#------------------------------------------------------------------------------
#  A sprite class with animation display processing added.
#==============================================================================

class Sprite_Base
  # --------------------------------------------------------------------------
  # Alias method : Update Animation
  # --------------------------------------------------------------------------
  alias tsbs_update_anim update_animation
  def update_animation
    return if $game_temp.global_freeze
    tsbs_update_anim
  end
  
end

#==============================================================================
# ** Sprite_AnimState
#------------------------------------------------------------------------------
#  This sprite is used to display battlers state animation. It's a simply
# dummy sprite that created from Sprite_Base just for play an animation. Used
# within the Sprite_Battler class
#==============================================================================

class Sprite_AnimState < Sprite_Base
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(sprite_battler, viewport = nil)
    super(viewport)
    @spr_battler = sprite_battler
    update_position
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    super
    update_position
    src_rect.set(@spr_battler.src_rect)
    self.ox = width/2
    self.oy = height
    update_state_anim
    update_visibility
  end
  # --------------------------------------------------------------------------
  # * Update sprite position
  # --------------------------------------------------------------------------
  def update_position
    move_animation(diff_x, diff_y)
    self.x = @spr_battler.x
    self.y = @spr_battler.y
    self.z = @spr_battler.z + (anim_behind? ? -2 : 2)
  end
  # --------------------------------------------------------------------------
  # * Update state animation
  # --------------------------------------------------------------------------
  def update_state_anim
    return if !@spr_battler.battler || animation?
    anim = $data_animations[@spr_battler.battler.state_anim]
    start_animation(anim)
  end
  # --------------------------------------------------------------------------
  # * Update animation visibility
  # --------------------------------------------------------------------------
  def update_visibility
    @ani_sprites.each do |ani_spr|
      ani_spr.visible = visible_case
    end if @ani_sprites
  end
  # --------------------------------------------------------------------------
  # * Get difference of X position
  # --------------------------------------------------------------------------
  def diff_x
    @spr_battler.x - x
  end
  # --------------------------------------------------------------------------
  # * Get difference of Y position
  # --------------------------------------------------------------------------
  def diff_y
    @spr_battler.y - y
  end
  # --------------------------------------------------------------------------
  # * Move animation alongside battler
  # --------------------------------------------------------------------------
  def move_animation(dx, dy)
    if @animation && @animation.position != 3
      @ani_ox += dx
      @ani_oy += dy
      @ani_sprites.each do |sprite|
        sprite.x += dx
        sprite.y += dy
      end
    end
  end
  # --------------------------------------------------------------------------
  # * End animation
  # --------------------------------------------------------------------------
  def end_animation
    anim = $data_animations[@spr_battler.battler.state_anim]
    if anim == @animation
      @ani_duration = @animation.frame_max * @ani_rate + 1
      @ani_sprites.each {|s| s.dispose }
      make_animation_sprites
      animation_set_sprites(@animation.frames[0])
    elsif !anim.nil?
      start_animation(anim)
    else
      super
    end
  end
  # --------------------------------------------------------------------------
  # * Visibility case
  # --------------------------------------------------------------------------
  def visible_case
    @spr_battler.opacity > 0 && @spr_battler.visible
  end
  # --------------------------------------------------------------------------
  # * Overwrite animation set sprites
  # --------------------------------------------------------------------------
  def animation_set_sprites(frame)
    cell_data = frame.cell_data
    @ani_sprites.each_with_index do |sprite, i|
      next unless sprite
      pattern = cell_data[i, 0]
      if !pattern || pattern < 0
        sprite.visible = false
        next
      end
      sprite.bitmap = pattern < 100 ? @ani_bitmap1 : @ani_bitmap2
      sprite.visible = true
      sprite.src_rect.set(pattern % 5 * 192,
        pattern % 100 / 5 * 192, 192, 192)
      if @ani_mirror
        sprite.x = @ani_ox - cell_data[i, 1]
        sprite.y = @ani_oy + cell_data[i, 2]
        sprite.angle = (360 - cell_data[i, 4])
        sprite.mirror = (cell_data[i, 5] == 0)
      else
        sprite.x = @ani_ox + cell_data[i, 1]
        sprite.y = @ani_oy + cell_data[i, 2]
        sprite.angle = cell_data[i, 4]
        sprite.mirror = (cell_data[i, 5] == 1)
      end
      sprite.z = self.z + (anim_behind? ? -16 : 1)
      sprite.ox = 96
      sprite.oy = 96
      sprite.zoom_x = cell_data[i, 3] / 100.0
      sprite.zoom_y = cell_data[i, 3] / 100.0
      sprite.opacity = cell_data[i, 6] * @spr_battler.opacity / 255.0
      sprite.blend_type = cell_data[i, 7]
    end
  end
  # --------------------------------------------------------------------------
  # * Overwrite animation process timing
  # --------------------------------------------------------------------------
  def animation_process_timing(timing)
    timing.se.play unless @ani_duplicated
    case timing.flash_scope
    when 1
      @spr_battler.flash(timing.flash_color, timing.flash_duration * @ani_rate)
    when 2
      if viewport && !@ani_duplicated
        viewport.flash(timing.flash_color, timing.flash_duration * @ani_rate)
      end
    when 3
      @spr_battler.flash(nil, timing.flash_duration * @ani_rate)
    end
  end
  # --------------------------------------------------------------------------
  # * Anim Behind?
  # --------------------------------------------------------------------------
  def anim_behind?
    return false unless @spr_battler.battler
    return @spr_battler.battler.anim_behind?
  end
  
end

#==============================================================================
# ** Sprite_AnimGuard
#------------------------------------------------------------------------------
#  This sprite handles battler animation guard. It's a simply
# dummy sprite that created from Sprite_Base just for play an animation. Used
# within the Sprite_Battler class
#==============================================================================

class Sprite_AnimGuard < Sprite_Base
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(sprite_battler, viewport = nil)
    super(viewport)
    @spr_battler = sprite_battler
    update_position
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    super
    update_position
    src_rect.set(@spr_battler.src_rect)
    self.ox = width/2
    self.oy = height
    update_anim_guard
  end
  # --------------------------------------------------------------------------
  # * Update Position
  # --------------------------------------------------------------------------
  def update_position
    move_animation(diff_x, diff_y)
    self.x = @spr_battler.x
    self.y = @spr_battler.y
    self.z = @spr_battler.z + 2
  end
  # --------------------------------------------------------------------------
  # * Update Animation Guard
  # --------------------------------------------------------------------------
  def update_anim_guard
    if @spr_battler.battler && @spr_battler.battler.anim_guard != 0
      anim_guard = @spr_battler.battler.anim_guard
      anim_mirror = @spr_battler.battler.anim_guard_mirror
      start_animation($data_animations[anim_guard],anim_mirror)
      @spr_battler.battler.anim_guard = 0
      @spr_battler.battler.anim_guard_mirror = false
    end
  end
  # --------------------------------------------------------------------------
  # * Overwrite animation set sprites
  # --------------------------------------------------------------------------
  def animation_set_sprites(frame)
    cell_data = frame.cell_data
    @ani_sprites.each_with_index do |sprite, i|
      next unless sprite
      pattern = cell_data[i, 0]
      if !pattern || pattern < 0
        sprite.visible = false
        next
      end
      sprite.bitmap = pattern < 100 ? @ani_bitmap1 : @ani_bitmap2
      sprite.visible = true
      sprite.src_rect.set(pattern % 5 * 192,
        pattern % 100 / 5 * 192, 192, 192)
      if @ani_mirror
        sprite.x = @ani_ox - cell_data[i, 1]
        sprite.y = @ani_oy + cell_data[i, 2]
        sprite.angle = (360 - cell_data[i, 4])
        sprite.mirror = (cell_data[i, 5] == 0)
      else
        sprite.x = @ani_ox + cell_data[i, 1]
        sprite.y = @ani_oy + cell_data[i, 2]
        sprite.angle = cell_data[i, 4]
        sprite.mirror = (cell_data[i, 5] == 1)
      end
      sprite.z = self.z + 1 #+ i
      sprite.ox = 96
      sprite.oy = 96
      sprite.zoom_x = cell_data[i, 3] / 100.0
      sprite.zoom_y = cell_data[i, 3] / 100.0
      sprite.opacity = cell_data[i, 6] * @spr_battler.opacity / 255.0
      sprite.blend_type = cell_data[i, 7]
    end
  end
  # --------------------------------------------------------------------------
  # * Get difference of X position
  # --------------------------------------------------------------------------
  def diff_x
    @spr_battler.x - x
  end
  # --------------------------------------------------------------------------
  # * Get difference of Y position
  # --------------------------------------------------------------------------
  def diff_y
    @spr_battler.y - y
  end
  # --------------------------------------------------------------------------
  # * Move animation alongside battler
  # --------------------------------------------------------------------------
  def move_animation(dx, dy)
    if @animation && @animation.position != 3
      @ani_ox += dx
      @ani_oy += dy
      @ani_sprites.each do |sprite|
        sprite.x += dx
        sprite.y += dy
      end
    end
  end
  # --------------------------------------------------------------------------
  # * Overwrite animation process timing
  # --------------------------------------------------------------------------
  def animation_process_timing(timing)
    timing.se.play unless @ani_duplicated
    case timing.flash_scope
    when 1
      @spr_battler.flash(timing.flash_color, timing.flash_duration * @ani_rate)
    when 2
      if viewport && !@ani_duplicated
        viewport.flash(timing.flash_color, timing.flash_duration * @ani_rate)
      end
    when 3
      @spr_battler.flash(nil, timing.flash_duration * @ani_rate)
    end
  end
  
end

#==============================================================================
# ** Sprite_Battler
#------------------------------------------------------------------------------
#  This sprite is used to display battlers. It observes an instance of the
# Game_Battler class and automatically changes sprite states.
#==============================================================================

class Sprite_Battler < Sprite_Base
  include TSBS_AnimRewrite
  include TSBS
  # --------------------------------------------------------------------------
  # Alias method : Initialize
  # --------------------------------------------------------------------------
  alias tsbs_init initialize
  def initialize(*args)
    tsbs_init(*args)
    @balloon_duration = 0
    @used_bitmap = []
    @anim_state = Sprite_AnimState.new(self,viewport)
    @shadow = Sprite_BattlerShadow.new(self,viewport)
    @anim_guard = Sprite_AnimGuard.new(self,viewport)
    @anim_cell = -1
  end
  # --------------------------------------------------------------------------
  # Alias method : Start Animation
  # --------------------------------------------------------------------------
  alias tsbs_start_anim start_animation
  def start_animation(anim, mirror = false)
    @anim_top = $game_temp.anim_top
    @anim_follow = $game_temp.anim_follow
    $game_temp.anim_top = 0
    $game_temp.anim_follow = false
    tsbs_start_anim(anim, mirror)
  end
  # --------------------------------------------------------------------------
  # New method : Sprite is an actor?
  # --------------------------------------------------------------------------
  def actor?
    @battler && @battler.is_a?(Game_Actor)
  end
  # --------------------------------------------------------------------------
  # Alias method : bitmap=
  # --------------------------------------------------------------------------
  alias tsbs_bitmap= bitmap=
  def bitmap=(bmp)
    self.tsbs_bitmap = bmp
    @used_bitmap.push(bmp)
    @used_bitmap.uniq!
    return unless @battler && @battler.data_battler.use_sprite && bitmap
    wr = bitmap.width / self.class::MaxCol
    hr = bitmap.height / self.class::MaxRow
    yr = 0
    xr = 0
    src_rect.set(xr,yr,wr,hr)
    update_flip
  end
  # --------------------------------------------------------------------------
  # Overwrite method : update origin
  # --------------------------------------------------------------------------
  def update_origin
    if bitmap
      unless @battler && @battler.data_battler.use_sprite
        self.ox = bitmap.width / 2
        self.oy = bitmap.height
      else
        if @anim_cell != @battler.anim_cell
          @anim_cell = @battler.anim_cell
          src_rect.y = (@anim_cell / MaxCol) * height
          src_rect.x = (@anim_cell % MaxCol) * width
        end
        self.ox = src_rect.width/2
        self.oy = height
      end
    end
  end
  # --------------------------------------------------------------------------
  # Overwrite method : revert to normal
  # --------------------------------------------------------------------------
  def revert_to_normal
    self.blend_type = 0
    self.color.set(0, 0, 0, 0)
    self.opacity = 255
    update_origin
  end
  # --------------------------------------------------------------------------
  # Overwrite method : Init visibility
  # --------------------------------------------------------------------------
  def init_visibility
    return if actor? && !@battler.data_battler.dead_key.empty?
    @battler_visible = !@battler.hidden? && (@battler.enemy? ? 
      !@battler.collapsed : true)
    self.opacity = 0 unless @battler_visible
  end
  # --------------------------------------------------------------------------
  # Overwrite method : afterimage
  # --------------------------------------------------------------------------
  def afterimage
    super || @battler.afterimage rescue false
  end
  # --------------------------------------------------------------------------
  # New method : update afterimage info
  # --------------------------------------------------------------------------
  def update_afterimage_info
    if @battler
      @afterimage_opac = @battler.afopac
      @afterimage_rate = @battler.afrate
      return
    end
    @afterimage_opac = 20
    @afterimage_rate = 3
  end
  # --------------------------------------------------------------------------
  # Alias method : update
  # --------------------------------------------------------------------------
  alias theo_tsbs_update update
  def update
    theo_tsbs_update
    update_afterimage_info
    update_anim_state
    update_anim_guard
    update_shadow
    update_balloon
    if @battler
      update_anim_position
      update_visible
      update_flip
      update_tone
      update_start_balloon
      update_color unless effect?
      update_opacity if @battler.refresh_opacity
      update_blending if (@effect_type.nil? || @effect_type == :whiten)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Battler is busy?
  # --------------------------------------------------------------------------
  def busy?
    @battler && BusyPhases.any? do |phase|
      phase == @battler.battle_phase
    end && !@battler.finish || (@battler && @battler.moving?)
  end
  # --------------------------------------------------------------------------
  # New method : Battler is busy? (for skill)
  # --------------------------------------------------------------------------
  def skill_busy?
    @battler && (BusyPhases - [:collapse]).any? do |phase|
      phase == @battler.battle_phase
    end && !@battler.finish || (@battler && @battler.moving?)
  end
  # --------------------------------------------------------------------------
  # New method : update visibility
  # --------------------------------------------------------------------------
  def update_visible
    self.visible = @battler.visible
  end
  # --------------------------------------------------------------------------
  # New method : update flip
  # --------------------------------------------------------------------------
  def update_flip
    self.mirror = @battler.flip
  end
  # --------------------------------------------------------------------------
  # New method : update battler tone
  # --------------------------------------------------------------------------
  def update_tone
    self.tone.set(@battler.state_tone)
  end
  # --------------------------------------------------------------------------
  # New method : update battler color
  # --------------------------------------------------------------------------
  def update_color
    self.color.set(@battler.state_color) if @color_flash.alpha == 0
    # Note: @color_flash taken from my Basic Modules v1.5b (Clone image)
  end
  # --------------------------------------------------------------------------
  # New method : update battler opacity
  # --------------------------------------------------------------------------
  def update_opacity
    self.opacity = @battler.max_opac
    @battler.refresh_opacity = false
  end
  # --------------------------------------------------------------------------
  # New method : update battler blend
  # --------------------------------------------------------------------------
  def update_blending
    self.blend_type = @battler.blend
  end
  # --------------------------------------------------------------------------
  # New method : update anim aid
  # --------------------------------------------------------------------------
  def update_anim_state
    @anim_state.update
  end
  # --------------------------------------------------------------------------
  # New method : update anim guard
  # --------------------------------------------------------------------------
  def update_anim_guard
    @anim_guard.update
  end
  # --------------------------------------------------------------------------
  # New method : update shadow
  # --------------------------------------------------------------------------
  def update_shadow
    @shadow.update
  end
  # --------------------------------------------------------------------------
  # New method : update start balloon
  # --------------------------------------------------------------------------
  def update_start_balloon
    if !@balloon_sprite && @battler.balloon_id > 0
      @balloon_id = @battler.balloon_id
      start_balloon
    end
  end
  # --------------------------------------------------------------------------
  # Alias method : Opacity=
  # --------------------------------------------------------------------------
  alias tsbs_opacity= opacity=
  def opacity=(value)
    result = [value, max_opac].min
    self.tsbs_opacity = result
  end
  # --------------------------------------------------------------------------
  # New method : Maximum opacity
  # --------------------------------------------------------------------------
  def max_opac
    return @battler.max_opac if @battler
    return 255
  end
  # --------------------------------------------------------------------------
  # Alias method : update boss collapse
  # --------------------------------------------------------------------------
  alias tsbs_boss_collapse update_boss_collapse
  def update_boss_collapse
    return tsbs_boss_collapse unless @battler && @battler.use_sprite?
    alpha = (@effect_duration * 120 / height rescue 0)
    self.ox = width / 2 + @effect_duration % 2 * 4 - 2
    self.blend_type = 1
    self.color.set(255, 255, 255, 255 - alpha)
    self.opacity = alpha
    Sound.play_boss_collapse2 if @effect_duration % 20 == 19
  end
  # --------------------------------------------------------------------------
  # Alias method : dispose
  # --------------------------------------------------------------------------
  alias tsbs_dispose dispose
  def dispose
    tsbs_dispose
    @used_bitmap.compact.each do |bmp|
      bmp.dispose unless bmp.disposed?
    end
    @anim_state.dispose
    @anim_guard.dispose
    @shadow.dispose
    @balloon_sprite.dispose if @balloon_sprite
  end
  #--------------------------------------------------------------------------
  # New Method : Start Balloon
  #--------------------------------------------------------------------------
  def start_balloon
    dispose_balloon
    @balloon_duration = 8 * balloon_speed + balloon_wait
    @balloon_sprite = ::Sprite.new(viewport)
    @balloon_sprite.bitmap = Cache.system("Balloon")
    @balloon_sprite.ox = 16
    @balloon_sprite.oy = 32
    update_balloon
  end
  #--------------------------------------------------------------------------
  # New Method : Free Balloon Icon
  #--------------------------------------------------------------------------
  def dispose_balloon
    if @balloon_sprite
      @balloon_sprite.dispose
      @balloon_sprite = nil
    end
  end
  #--------------------------------------------------------------------------
  # New Method : Update Balloon Icon
  #--------------------------------------------------------------------------
  def update_balloon
    if @balloon_duration > 0
      @balloon_duration -= 1
      if @balloon_duration > 0
        @balloon_sprite.x = x
        @balloon_sprite.y = y - height
        @balloon_sprite.z = z + 200
        sx = balloon_frame_index * 32
        sy = (@balloon_id - 1) * 32
        @balloon_sprite.src_rect.set(sx, sy, 32, 32)
      else
        end_balloon
      end
    end
  end
  #--------------------------------------------------------------------------
  # New Method : End Balloon Icon
  #--------------------------------------------------------------------------
  def end_balloon
    dispose_balloon
    @battler.balloon_id = 0
  end
  #--------------------------------------------------------------------------
  # New Method : Balloon Icon Display Speed
  #--------------------------------------------------------------------------
  def balloon_speed
    return 4
  end
  #--------------------------------------------------------------------------
  # New Method : Wait Time for Last Frame of Balloon
  #--------------------------------------------------------------------------
  def balloon_wait
    return 3
  end
  #--------------------------------------------------------------------------
  # New Method : Frame Number of Balloon Icon
  #--------------------------------------------------------------------------
  def balloon_frame_index
    return 7 - [(@balloon_duration - balloon_wait) / balloon_speed, 0].max
  end
  # --------------------------------------------------------------------------
  # New Method : Get difference of X position
  # --------------------------------------------------------------------------
  def diff_x
    @battler.screen_x - x
  end
  # --------------------------------------------------------------------------
  # New Method : Get difference of Y position
  # --------------------------------------------------------------------------
  def diff_y
    @battler.screen_y - y
  end
  # --------------------------------------------------------------------------
  # New Method : Move animation alongside battler
  # --------------------------------------------------------------------------
  def move_animation(dx, dy)
    if @animation && @animation.position != 3
      @ani_ox += dx
      @ani_oy += dy
      @ani_sprites.each do |sprite|
        sprite.x += dx
        sprite.y += dy
      end
    end
  end
  # --------------------------------------------------------------------------
  # New Method : Update Animation Position
  # --------------------------------------------------------------------------
  def update_anim_position
    return unless @anim_follow
    move_animation(diff_x, diff_y)
    self.x = @battler.screen_x
    self.y = @battler.screen_y
  end
  # --------------------------------------------------------------------------
  # Alias Method : Flash
  # --------------------------------------------------------------------------
  alias tsbs_color_flash flash
  def flash(color, duration)
    self.color.set(EmptyColor)
    tsbs_color_flash(color, duration)
  end
  # --------------------------------------------------------------------------
  # New Method : Is collapsing?
  # --------------------------------------------------------------------------
  def collapsing?
    @effect_type == :collapse
  end
  # --------------------------------------------------------------------------
  # New Method : Update collapse opacity (to prevent rare case bug)
  # --------------------------------------------------------------------------
  def update_collapse_opacity
    self.opacity = 256 - (48 - @effect_duration) * 6
  end
  
end

#==============================================================================
# ** Sprite_Projectile
#------------------------------------------------------------------------------
#  This sprite is used to display projectile. This class is used within the
# Spriteset_Battle class
#==============================================================================

class Sprite_Projectile < Sprite_Base
  # --------------------------------------------------------------------------
  # * Public accessors
  # --------------------------------------------------------------------------
  attr_accessor :subject      # Battler subject
  attr_accessor :target       # Battler target
  attr_accessor :item         # Carried item / skill
  attr_accessor :angle_speed  # Angle speed rotation
  attr_accessor :target_aim   # Target Aim
  attr_accessor :boomerang    # Boomerang Flag
  # --------------------------------------------------------------------------
  # * Import TSBS constantas
  # --------------------------------------------------------------------------
  include TSBS
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(viewport = nil)
    super
    @angle = 0.0
    @return = false
    @afterimage_opac = 17
    @afterimage_rate = 1
    @afterimage_dispose = false
  end
  # --------------------------------------------------------------------------
  # * Set icon
  # --------------------------------------------------------------------------
  def icon=(icon_index)
    icon_bitmap = Cache.system("Iconset")
    rect = Rect.new(icon_index % 16 * 24, icon_index / 16 * 24, 24, 24)
    bmp = Bitmap.new(24,24)
    bmp.blt(0, 0, icon_bitmap, rect, 255)
    self.bitmap = bmp
    self.ox = width/2
    self.oy = height/2
  end
  # --------------------------------------------------------------------------
  # * Record last coordinate
  # --------------------------------------------------------------------------
  def update_last_coordinate
    @last_x = x
    @last_y = y
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    return if $game_temp.global_freeze
    super
    return afimg_dispose if @afterimage_dispose
    @angle += angle_speed
    self.angle = @angle
    process_dispose if need_dispose?
  end
  # --------------------------------------------------------------------------
  # * Alias method : update movement
  # --------------------------------------------------------------------------
  def update_move
    update_last_coordinate
    super
    move_animation(diff_x, diff_y)
  end
  # --------------------------------------------------------------------------
  # * Need dispose flag
  # --------------------------------------------------------------------------
  def need_dispose?
    !moving?
  end
  # --------------------------------------------------------------------------
  # * Disposing sprite
  # --------------------------------------------------------------------------
  def process_dispose
    if !target.is_a?(Array) && rand < target.item_mrf(@subject, item) && 
      !@return
      # If not multitargets and target has magic reflection
      target.animation_id = target.data_battler.reflect_anim
      target.result.reflected = true
      SceneManager.scene.damage.display_reflect(target)
      repel  # Repel the projectile back to caster
    else
      # If not ~
      if @return # If current projectile is back to caster
        dispose_method
      else
        # If multi targets
        if target.is_a?(Array)
          target.each {|trg| apply_item(trg, false)}
          handler = get_spriteset.one_anim
          size = target.size
          xpos = target.inject(0) {|r,battler| r + battler.screen_x}/size
          ypos = target.inject(0) {|r,battler| r + battler.screen_y}/size
          zpos = target.inject(0) {|r,battler| r + battler.screen_z}/size
          handler.set_position(xpos, ypos, zpos)
          sprites = target.collect {|t| get_spriteset.get_sprite(t)}
          handler.target_sprites = sprites
          anim_id = item.animation_id
          mirror = subject.flip
          $game_temp.one_animation_id = anim_id
          $game_temp.one_animation_flip = mirror
        else # If single target
          apply_item(target, true)
        end
        if boomerang
          @jump = @jump * -1
          @return = true
          repel
        else
          dispose_method
        end
      end
    end
  end
  # --------------------------------------------------------------------------
  # * Apply item
  # --------------------------------------------------------------------------
  def apply_item(trg, animation)
    SceneManager.scene.tsbs_apply_item(trg, item, subject) # Do damage
    anim_id = trg.anim_guard_id
    cond = anim_id > 0 && !item.damage.recover? && !item.ignore_anim_guard? && 
      !item.parallel_anim?
    if animation
      trg.animation_id = (cond ? anim_id : item.animation_id)
      trg.animation_mirror = subject.flip
    end
    if item.parallel_anim?
      trg.anim_guard = anim_id 
      trg.anim_guard_mirror = trg.flip
    end
  end
  # --------------------------------------------------------------------------
  # * Disposal method
  # --------------------------------------------------------------------------
  def dispose_method
    if @afterimage
       @afterimage = false
       @afterimage_dispose = true
    else
       dispose 
    end
  end
  # --------------------------------------------------------------------------
  # * Dispose self until afterimage is empty
  # --------------------------------------------------------------------------
  def afimg_dispose
    self.opacity = 0
    return unless @afterimages.empty?
    dispose
  end
  # --------------------------------------------------------------------------
  # * Difference from last X coordinate
  # --------------------------------------------------------------------------
  def diff_x
    self.x - @last_x
  end
  # --------------------------------------------------------------------------
  # * Difference from last Y coordinate
  # --------------------------------------------------------------------------
  def diff_y
    self.y - @last_y
  end
  # --------------------------------------------------------------------------
  # * Move animation
  # --------------------------------------------------------------------------
  def move_animation(dx, dy)
    if @animation && @animation.position != 3
      @ani_ox += dx
      @ani_oy += dy
      @ani_sprites.each do |sprite|
        sprite.x += dx
        sprite.y += dy
      end
    end
  end
  # --------------------------------------------------------------------------
  # * Repel projectiles for magic reflect
  # --------------------------------------------------------------------------
  def repel
    temp = subject
    if random_reflect? # Random target reflect if skill/item allow to do so
      temp = temp.friends_unit.alive_members.shuffle[0]
    end
    self.subject = target
    self.target = temp
    make_aim(@dur, @jump)
    start_animation(@animation, !@mirror)
  end
  # --------------------------------------------------------------------------
  # * Overwrite method : goto (Basic Module)
  # --------------------------------------------------------------------------
  def goto(xpos,ypos,dur=60,jump=0)
    super(xpos,ypos,dur,jump)
    @dur = dur
    @jump = jump
  end
  # --------------------------------------------------------------------------
  # * Make aim
  # --------------------------------------------------------------------------
  def make_aim(dur, jump)
    if target.is_a?(Array)
      size = target.size
      tx = target.inject(0) {|r,battler| r + battler.screen_x}/size
      ty = target.inject(0) {|r,battler| r + battler.screen_y}/size
    else
      spr_target = get_spriteset.get_sprite(target)
      tx = target.x
      case target_aim
      when :feet
        ty = target.screen_y
      when :middle
        ty = target.screen_y - spr_target.height/2
      when :head
        ty = target.screen_y - spr_target.height
      end
    end
    goto(tx,ty,dur,jump)
  end
  # --------------------------------------------------------------------------
  # * Start Animation
  # --------------------------------------------------------------------------
  def start_animation(anim, mirror = false)
    @mirror = mirror
    super(anim, mirror)
  end
  # --------------------------------------------------------------------------
  # * Make Animation Loops
  # --------------------------------------------------------------------------
  def end_animation
    @ani_duration = @animation.frame_max * @ani_rate + 1
  end
  # --------------------------------------------------------------------------
  # * Random Reflection?
  # --------------------------------------------------------------------------
  def random_reflect?
    item.random_reflect?
  end
  
end

#==============================================================================
# ** Sprite_BattlerShadow
#------------------------------------------------------------------------------
#  This sprite is used to display battler's shadow. 
#==============================================================================

class Sprite_BattlerShadow < Sprite
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(sprite_battler, viewport = nil)
    @sprite_battler = sprite_battler
    super(viewport)
    self.bitmap = Cache.system("Shadow")
    update
  end
  # --------------------------------------------------------------------------
  # * Update Size
  # --------------------------------------------------------------------------
  def update_size
    self.zoom_x = @sprite_battler.width.to_f / bitmap.width.to_f * 0.6
    self.zoom_y = @sprite_battler.height.to_f / bitmap.height.to_f 
    self.ox = width/2
    self.oy = height
  end
  # --------------------------------------------------------------------------
  # * Update position
  # --------------------------------------------------------------------------
  def update_position
    if @sprite_battler.battler
      self.x = @sprite_battler.battler.screen_x
      self.y = @sprite_battler.battler.shadow_y + shift_y
    end
    self.z = 3
  end
  # --------------------------------------------------------------------------
  # * Update opacity
  # --------------------------------------------------------------------------
  def update_opacity
    self.opacity = @sprite_battler.opacity
  end
  # --------------------------------------------------------------------------
  # * Update opacity
  # --------------------------------------------------------------------------
  def update_visible
    self.visible = (@sprite_battler.battler && 
      !@sprite_battler.battler.data_battler.no_shadow) && 
      @sprite_battler.visible && TSBS::UseShadow
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    super
    update_size
    update_position
    update_opacity
    update_visible
  end
  # --------------------------------------------------------------------------
  # * Shift Y
  # --------------------------------------------------------------------------
  def shift_y
    return 4
  end
end

#==============================================================================
# ** Sprite_BattlerIcon
#------------------------------------------------------------------------------
#  This sprite is used to display battler's Icon. It observes icon key from
# Game_Battler class and automatically changes sprite display when triggered.
#==============================================================================

class Sprite_BattlerIcon < Sprite_Base
  #============================================================================
  # Dummy Coordinate Class for icon movement
  #----------------------------------------------------------------------------
  class Dummy_Coordinate
    attr_accessor :x
    attr_accessor :y
    include THEO::Movement  # Import core movement
    
    def initialize
      @x = 0
      @y = 0
      set_obj(self)
    end
    
    alias screen_x x
    alias screen_y y
  end
  #============================================================================
  attr_reader :battler  # Battler
  include TSBS          # Import TSBS constantas
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(battler, viewport = nil)
    super(viewport)
    @battler = battler
    @afterimage_opac = 20
    @afterimage_rate = 3
    @dummy = Dummy_Coordinate.new
    @above_char = false
    @used_key = ""
    self.anchor = 0
    self.icon_index = 0
  end
  # --------------------------------------------------------------------------
  # * Set anchor origin
  # --------------------------------------------------------------------------
  def anchor=(value)
    @anchor_origin = value
    update_anchor(value)
  end
  # --------------------------------------------------------------------------
  # * Set icon index
  # --------------------------------------------------------------------------
  def icon_index=(index)
    @icon_index = index
    icon_bitmap = Cache.system("Iconset")
    rect = Rect.new(index % 16 * 24, index / 16 * 24, 24, 24)
    bmp = Bitmap.new(24,24)
    bmp.blt(0, 0, icon_bitmap, rect, 255)
    self.bitmap = bmp
  end
  # --------------------------------------------------------------------------
  # * Overwrite bitmap=
  # --------------------------------------------------------------------------
  def bitmap=(bmp)
    update_anchor(@anchor_origin)
    super
  end
  # --------------------------------------------------------------------------
  # * Update anchor origin
  # --------------------------------------------------------------------------
  def update_anchor(value)
    case value
    when 0 # Center
      self.ox = self.oy = 12
    when 1 # Upper Left
      self.ox = self.oy = 0
    when 2 # Upper Right
      self.ox = 24
      self.oy = 0
    when 3 # Bottom Left
      self.ox = 0
      self.oy = 24
    when 4 # Bottom Right
      self.ox = self.oy = 24
    else
      point = IconAnchor[value]
      self.ox = point[0]
      self.oy = point[1]
    end
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    super
    @dummy.update_move
    update_placement
    update_key unless battler.icon_key.empty?
  end
  # --------------------------------------------------------------------------
  # * Update placement related to battler
  # --------------------------------------------------------------------------
  def update_placement
    self.x = battler.screen_x + @dummy.screen_x
    self.y = battler.screen_y + @dummy.screen_y
    self.z = battler.screen_z + (@above_char ? 1 : -1)
    sprset = get_spriteset
    self.opacity = sprset.get_sprite(battler).opacity if sprset.class ==
      Spriteset_Battle rescue return
  end
  # --------------------------------------------------------------------------
  # * Update icon key
  # --------------------------------------------------------------------------
  def update_key
    actor = battler # Just make alias
    @used_key = battler.icon_key
    array = Icons[@used_key]
    return icon_error unless array
    self.anchor = array[0]
    @dummy.x = (battler.flip ? -array[1] : array[1])
    @dummy.y = array[2]
    @above_char = array[3]
    update_placement
    self.angle = array[4]
    target = array[5]
    duration = array[6]
    if array[7].is_a?(String)
      icon_index = (eval(array[7]) rescue 0)
    elsif array[7] >= 0
      icon_index = array[7]
    elsif !array[7].nil?
      if array[7] == -1 # First weapon ~
        icon_index = (battler.weapons[0].icon_index rescue 0)
      elsif array[7] == -2 # Second weapon ~
        icon_index = (battler.weapons[1].icon_index rescue 
          (battler.weapons[0].icon_index rescue 0))
      end
    end
    self.mirror = (array[8].nil? ? false : array[8])
    if array[9] && array[10] && array[11]
      @dummy.slide(array[9], array[10], array[11])
    end
    icon_index = icon_index || 0
    self.icon_index = icon_index
    change_angle(target, duration)
    battler.icon_key = ""
  end
  # --------------------------------------------------------------------------
  # * Icon Error Recognition
  # --------------------------------------------------------------------------
  def icon_error
    ErrorSound.play
    text = "Undefined icon key : #{@used_key}"
    msgbox text
    exit
  end
  
end
#==============================================================================
# ** Sprite_BattleCutin
#------------------------------------------------------------------------------
#  This sprite handles actor cutin graphic
#==============================================================================
class Sprite_BattleCutin < Sprite
  # --------------------------------------------------------------------------
  # * Start Cutin
  # --------------------------------------------------------------------------
  def start(file, x, y, opacity, zoom_x, zoom_y)
    self.bitmap = Cache.picture(file)
    self.x = x
    self.y = y
    self.opacity = opacity
    self.zoom_x = zoom_x
    self.zoom_y = zoom_y
  end
  
end
#==============================================================================
# ** Sprite_BattleCutin
#------------------------------------------------------------------------------
#  This sprite handles one animation display for area attack
#==============================================================================
class Sprite_OneAnim < Sprite_Base
  attr_accessor :target_sprites
  include TSBS_AnimRewrite
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(viewport)
    @multianimes = []
    @target_sprites = []
    super(viewport)
  end
  # --------------------------------------------------------------------------
  # * Start Animation
  # --------------------------------------------------------------------------
  def start_animation(anime, flip = false)
    if $imported[:TSBS_MultiAnime]
      spr_anim = Sprite_MultiAnime.new(viewport, self, anime, flip)
      @multianimes.push(spr_anim)
      return
    end
    @anim_top = $game_temp.anim_top
    $game_temp.anim_top = 0
    super(anime, flip)
  end
  # --------------------------------------------------------------------------
  # * Set Position
  # --------------------------------------------------------------------------
  def set_position(x,y,z)
    self.x = x
    self.y = y
    self.z = z
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    super
    update_one_anim
    @multianimes.delete_if do |anime|
      anime.update
      anime.disposed?
    end
  end
  # --------------------------------------------------------------------------
  # * Update one animation starting flag
  # --------------------------------------------------------------------------
  def update_one_anim
    if $game_temp.one_animation_id > 0
      anim = $data_animations[$game_temp.one_animation_id]
      flip = $game_temp.one_animation_flip
      start_animation(anim, flip)
      $game_temp.one_animation_id = 0
      $game_temp.one_animation_flip = false
    end
  end
  # --------------------------------------------------------------------------
  # * Dispose
  # --------------------------------------------------------------------------
  def dispose
    super
    @multianimes.each do |anime|
      anime.dispose
    end
  end
  # --------------------------------------------------------------------------
  # * Animation?
  # --------------------------------------------------------------------------
  def animation?
    return !@multianimes.empty? if $imported[:TSBS_MultiAnime]
    return super
  end
  # --------------------------------------------------------------------------
  # * Update animation
  # --------------------------------------------------------------------------
  def update_animation
    return if $imported[:TSBS_MultiAnime]
    super
  end  
  # --------------------------------------------------------------------------
  # * Overwrite flash
  # --------------------------------------------------------------------------
  def flash(*args)
    @target_sprites.each {|trg| trg.flash(*args)}
  end
  
end
#==============================================================================
# ** Battle_Plane
#------------------------------------------------------------------------------
#  This class handles single plane to display plane (fog/parallax) in battle
# arena. It is used within Spriteset_Battle
#==============================================================================
class Battle_Plane < Plane
  attr_accessor :scroll_ox
  attr_accessor :scroll_oy
  # --------------------------------------------------------------------------
  # * Import Core fade from Basic Module
  # --------------------------------------------------------------------------
  include THEO::FADE
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(viewport)
    super(viewport)
    init_fade_members
    setfade_obj(self)
    @scroll_ox = 0.0
    @scroll_oy = 0.0
    reset_oxoy
  end
  # --------------------------------------------------------------------------
  # * Reset ori oxoy
  # --------------------------------------------------------------------------
  def reset_oxoy
    @ori_ox = 0.0
    @ori_oy = 0.0
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    update_fade
    @ori_ox += @scroll_ox
    @ori_oy += @scroll_oy
    self.ox = @ori_ox
    self.oy = @ori_oy
  end
  # --------------------------------------------------------------------------
  # * Set data
  # --------------------------------------------------------------------------
  def set(file, sox, soy, z, show_dur, max_opac = 255)
    self.bitmap = Cache.picture(file)
    reset_oxoy
    @scroll_ox = sox
    @scroll_oy = soy
    self.z = z
    self.opacity = 0
    fade(max_opac, show_dur)
  end
  
end
#==============================================================================
# ** Spriteset_Battle
#------------------------------------------------------------------------------
#  This class brings together battle screen sprites. It's used within the
# Scene_Battle class.
#==============================================================================
class Spriteset_Battle
  # --------------------------------------------------------------------------
  # Public instance method
  # --------------------------------------------------------------------------
  attr_reader :projectiles    # Projectiles array
  attr_reader :focus_bg       # Focus background
  attr_reader :cutin          # Cutin sprite
  attr_reader :battle_plane   # Battle Planes
  attr_reader :one_anim       # One Animation Sprite
  # --------------------------------------------------------------------------
  # Alias method : Initialize
  # --------------------------------------------------------------------------
  alias tsbs_init initialize
  def initialize
    @projectiles = []
    tsbs_init
  end
  # --------------------------------------------------------------------------
  # Alias method : Create viewports
  # --------------------------------------------------------------------------
  alias tsbs_icon_create_viewport create_viewports
  def create_viewports
    tsbs_icon_create_viewport
    create_battler_icon
    create_focus_sprite
    create_cutin_sprite
    create_battle_planes
    create_oneanim_sprite
  end
  # --------------------------------------------------------------------------
  # New method : Create battler icon
  # --------------------------------------------------------------------------  
  def create_battler_icon
    @icons = []
    battlers = $game_party.battle_members + $game_troop.members
    battlers.each do |battler|
      icon = Sprite_BattlerIcon.new(battler, @viewport1)
      @icons.push(icon)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Create focus sprite
  # --------------------------------------------------------------------------  
  def create_focus_sprite
    @focus_bg = Sprite_Screen.new(@viewport1)
    @focus_bg.bitmap.fill_rect(@focus_bg.bitmap.rect, Color.new(255,255,255))
    @focus_bg.z = 3
    @focus_bg.opacity = 0
  end
  # --------------------------------------------------------------------------
  # New method : Create cutin sprite
  # --------------------------------------------------------------------------  
  def create_cutin_sprite
    @cutin = Sprite_BattleCutin.new(@viewport2)
    @cutin.z = 999
  end
  # --------------------------------------------------------------------------
  # New method : Create cutin sprite
  # --------------------------------------------------------------------------  
  def create_battle_planes
    @battle_plane = Battle_Plane.new(@viewport1)
  end
  # --------------------------------------------------------------------------
  # New method : Create one animation dummy sprite (for handler)
  # --------------------------------------------------------------------------  
  def create_oneanim_sprite
    @one_anim = Sprite_OneAnim.new(@viewport1)
  end
  # --------------------------------------------------------------------------
  # New method : spriteset is busy?
  # --------------------------------------------------------------------------
  def busy?
    (@enemy_sprites + @actor_sprites).any? do |sprite|
      sprite.busy?
    end
  end
  # --------------------------------------------------------------------------
  # New method : spriteset is busy? (for skill)
  # --------------------------------------------------------------------------
  def skill_busy?
    (@enemy_sprites + @actor_sprites).any? do |sprite|
      sprite.skill_busy?
    end
  end
  # --------------------------------------------------------------------------
  # Overwrite method : actor sprites
  # --------------------------------------------------------------------------
  def create_actors
    @actor_sprites = Array.new($game_party.max_battle_members) do 
      Sprite_Battler.new(@viewport1)
    end
  end
  # --------------------------------------------------------------------------
  # Alias method : update
  # --------------------------------------------------------------------------
  alias tsbs_update update
  def update
    tsbs_update
    update_tsbs_extra
    update_projectiles
    update_icons
  end
  # --------------------------------------------------------------------------
  # New method : update tsbs extra graphics
  # --------------------------------------------------------------------------
  def update_tsbs_extra
    @focus_bg.update
    @cutin.update
    @battle_plane.update
    @one_anim.update
  end
  # --------------------------------------------------------------------------
  # New method : update projectiles
  # --------------------------------------------------------------------------
  def update_projectiles
    @projectiles.delete_if do |proj|
      proj.update
      proj.disposed?
    end
  end
  # --------------------------------------------------------------------------
  # New method : update icons
  # --------------------------------------------------------------------------
  def update_icons
    @icons.each do |icon|
      icon.update
    end
  end
  # --------------------------------------------------------------------------
  # New method : add projectiles
  # --------------------------------------------------------------------------
  def add_projectile(proj)
    proj.viewport = @viewport1
    proj.z = 300
    @projectiles.push(proj)
  end
  # --------------------------------------------------------------------------
  # New method : is projectile avalaible?
  # --------------------------------------------------------------------------
  def projectile?
    !projectiles.empty?
  end
  # --------------------------------------------------------------------------
  # New method : get battler sprite
  # --------------------------------------------------------------------------
  def get_sprite(battler)
    battler_sprites.each do |spr|
      return spr if spr.battler == battler
    end
    return nil
  end
  # --------------------------------------------------------------------------
  # Alias method : Dispose
  # --------------------------------------------------------------------------
  alias tsbs_dispose dispose
  def dispose
    (@icons + [@focus_bg, @cutin, @one_anim]).each do |extra|
      extra.dispose unless extra.disposed?
    end
    @battle_plane.dispose
    tsbs_dispose
  end
  # --------------------------------------------------------------------------
  # New method : Prevent collapse glitch for slow motion effect
  # --------------------------------------------------------------------------
  def prevent_collapse_glitch
    battler_sprites.each do |spr|
      next unless spr.collapsing?
      spr.update_collapse_opacity
    end
  end
  # --------------------------------------------------------------------------
  # Alias method : Animation?
  # --------------------------------------------------------------------------
  alias tsbs_animation? animation?
  def animation?
    tsbs_animation? || @one_anim.animation?
  end
  
end
#==============================================================================
# ** Scene_Battle
#------------------------------------------------------------------------------
#  This class performs battle screen processing.
#==============================================================================
class Scene_Battle < Scene_Base
  attr_reader :damage
  attr_reader :log_window
  attr_reader :status_window
  # --------------------------------------------------------------------------
  # Alias method : start
  # --------------------------------------------------------------------------
  alias tsbs_start start
  def start
    tsbs_start
    @damage = DamageResults.new(@viewport)
    @battle_event = Game_BattleEvent.new
  end
  # --------------------------------------------------------------------------
  # New method : Is event running?
  # --------------------------------------------------------------------------
  def event_running?
    @battle_event.active?
  end
  # --------------------------------------------------------------------------
  # Alias method : post_start
  # --------------------------------------------------------------------------
  alias tsbs_post_start post_start
  def post_start
    all_battle_members.each do |batt_member|
      if batt_member.actor? && $game_party.battle_members.include?(batt_member) 
        batt_member.init_oripost 
        unless batt_member.intro_key.empty? 
          batt_member.reset_pos(1)                            
          batt_member.update_move
          batt_member.battle_phase = :intro 
          batt_member.update
        end
      end
    end
    @spriteset.update
    tsbs_post_start
  end
  # --------------------------------------------------------------------------
  # New method : Perform slowmotion
  # Why no Graphics.frame_rate = n ? It makes the graphics screen not 
  # responsive. So, I decided to make this one
  # --------------------------------------------------------------------------
  def perform_slowmotion
    if $game_temp.slowmotion_frame > 0
      ($game_temp.slowmotion_rate - 1).times do
        @spriteset.prevent_collapse_glitch 
        # Just kill weird glitch for collapse effect
        Graphics.update
      end
      $game_temp.slowmotion_frame -= 1
    end
  end
  # --------------------------------------------------------------------------
  # Alias method : update basic
  # --------------------------------------------------------------------------
  alias theo_tsbs_update_basic update_basic
  def update_basic
    perform_slowmotion
    all_battle_members.each do |batt_member|
      if batt_member.actor? && !$game_party.battle_members.include?(batt_member)
        next
      end
      Kernel.catch_error(:error2, { 
        "batt_member" => batt_member,
        "$game_party" => $game_party
      }) do
        batt_member.update
      end
    end 
    theo_tsbs_update_basic
    @damage.update
  end
  # --------------------------------------------------------------------------
  # Overwrite method : use item
  # Compatibility? I will think that later ~
  # --------------------------------------------------------------------------
  def use_item
    item = @subject.current_action.item
    @log_window.display_use_item(@subject, item)
    @subject.use_item(item)
    refresh_status
    targets = @subject.current_action.make_targets.compact
    show_action_sequences(targets, item)
  end
  # --------------------------------------------------------------------------
  # New method : Wait method exclusively for TSBS
  # --------------------------------------------------------------------------
  def tsbs_wait_update
    update_for_wait
    @battle_event.update
  end
  # --------------------------------------------------------------------------
  # New method : wait for sequence
  # --------------------------------------------------------------------------
  def wait_for_sequence
    tsbs_wait_update
    tsbs_wait_update while @spriteset.busy?
  end
  # --------------------------------------------------------------------------
  # New method : wait for sequence
  # --------------------------------------------------------------------------
  def wait_for_skill_sequence
    tsbs_wait_update
    tsbs_wait_update while @spriteset.skill_busy?
  end
  # --------------------------------------------------------------------------
  # New method : show action sequence
  # --------------------------------------------------------------------------
  def show_action_sequences(targets, item, subj = @subject)
    tsbs_action_init(targets, item, subj)
    tsbs_action_pre(targets, item, subj)
    tsbs_action_main(targets, item, subj)
    tsbs_action_post(targets, item, subj)
    tsbs_action_end(targets, item, subj)
    wait(tsbs_wait_dur)
  end
  # --------------------------------------------------------------------------
  # New method : wait duration
  # --------------------------------------------------------------------------
  def tsbs_wait_dur
    return 30
  end
  # --------------------------------------------------------------------------
  # New method : action initialize
  # --------------------------------------------------------------------------
  def tsbs_action_init(targets, item, subj)
    $game_temp.battler_targets = targets.clone
    subj.target_array = targets
    subj.item_in_use = copy(item)
  end
  # --------------------------------------------------------------------------
  # New method : action preparation sequence
  # --------------------------------------------------------------------------
  def tsbs_action_pre(targets, item, subj)
    # Show preparation sequence ~
    if !item.prepare_key.empty?
      subj.target = targets[0] if targets.size == 1
      subj.battle_phase = :prepare
      wait_for_sequence
    end    
  end
  # --------------------------------------------------------------------------
  # New method : main action sequence
  # --------------------------------------------------------------------------
  def tsbs_action_main(targets, item, subj)
    # Determine if item is not AoE ~
    if !item.area?
      subj.area_flag = false
      # Repeat item sequence for target number times
      targets.each do |target|
        # Change target if the target is currently dead
        if target.dead? && !item.for_dead_friend? 
          target = subj.opponents_unit.random_target
          break if target.nil? # Break if there is no target avalaible
        end
        # Do sequence
        subj.target = target
        subj.battle_phase = :skill
        wait_for_skill_sequence
        break if [:forced, :idle].include?(subj.battle_phase)
      end
    # If item is area of effect damage. Do sequence skill only once
    else
      subj.area_flag = true
      subj.battle_phase = :skill
      wait_for_skill_sequence
      subj.area_flag = false
    end
  end
  # --------------------------------------------------------------------------
  # New method : post action execution
  # --------------------------------------------------------------------------
  def tsbs_action_post(targets, item, subj)
    # Determine if item has no return sequence
    unless item.no_return? || subj.battle_phase == :forced
      subj.battle_phase = :return 
    else
      subj.battle_phase = :idle
    end
    wait_for_sequence
  end
  # --------------------------------------------------------------------------
  # New method : action ending
  # --------------------------------------------------------------------------
  def tsbs_action_end(targets, item, subj)
    # Clear pointer
    subj.item_in_use = nil
    subj.target = nil
    # Compatibility with YEA Lunatic Object
    if $imported["YEA-LunaticObjects"]
      lunatic_object_effect(:after, item, subj, subj)
    end
    # Show message log if sequence has been finished
    $game_temp.battler_targets += [subj]
    $game_temp.battler_targets.uniq.compact.each do |target|
      @log_window.display_action_results(target, item)
      target.reset_pos(15) # Reset battler to current position
      target.result.clear
      next if target.actor?
      check_collapse(target)
    end
    # Reset damage value
    @damage.reset_value
  end
  # --------------------------------------------------------------------------
  # New method : check collapse
  # --------------------------------------------------------------------------
  def check_collapse(target)
    return if target.actor? && target.collapse_key.empty?
    if target.state?(target.death_state_id) || 
      ($imported["YEA-BattleEngine"] && target.can_collapse?)
      target.target = @subject
      target.perform_collapse_effect 
    end
  end
  # --------------------------------------------------------------------------
  # New method : Invoke item for TSBS
  # --------------------------------------------------------------------------
  def tsbs_invoke_item(target, item, subj = @subject)
    if rand < target.item_cnt(subj, item)
      tsbs_invoke_counter(target, item)
    elsif rand < target.item_mrf(subj, item)
      tsbs_invoke_mreflect(target, item)
    else
      tsbs_apply_item(target, item, subj) # doesn't support subtitue for now
#~       tsbs_apply_item(apply_substitute(target, item), item, subj)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Invoke counter for TSBS
  # --------------------------------------------------------------------------
  def tsbs_invoke_counter(target, item)
    if !target.data_battler.counter_key.empty?
      target.target_array = [@subject]
      target.target = @subject
      target.item_in_use = copy(target.make_counter_skill)
      target.battle_phase = :counter
    end
    @damage.display_counter(target)
    if $imported["YEA-BattleEngine"]
      status_redraw_target(@subject)
      status_redraw_target(target) unless target == @subject
    else
      refresh_status
    end
  end
  # --------------------------------------------------------------------------
  # New method : Invoke reflect for TSBS
  # --------------------------------------------------------------------------
  def tsbs_invoke_mreflect(target, item)
    item = copy(item)
    if item.random_reflect?
      target = target.friends_unit.members.shuffle[0]
    end
    @subject.magic_reflection = true
    target.result.reflected = true
    target.animation_id = target.data_battler.reflect_anim
    # ------------------------------------------------------
    # Convert drain damage to normal damage
    # Well, I don't like the original idea of magic reflect.
    # So, deal with it
    # ------------------------------------------------------
    item.damage.type = 1 if item.damage.type == 5
    item.damage.type = 2 if item.damage.type == 6
    # ------------------------------------------------------
    tsbs_apply_item(@subject, item, target)
    @damage.display_reflect(target)
    @subject.animation_id = item.reflect_anim
    @subject.magic_reflection = false
    if @subject.actor?
      @status_window.refresh 
    end
    if $imported["YEA-BattleEngine"]
      status_redraw_target(@subject)
      status_redraw_target(target) unless target == @subject
    else
      refresh_status
    end
  end
  # --------------------------------------------------------------------------
  # New method : Apply item for TSBS
  # --------------------------------------------------------------------------
  def tsbs_apply_item(target, item, subj = @subject)
    if $imported["YEA-LunaticObjects"]
      lunatic_object_effect(:prepare, item, subj, target)
      target.item_apply(subj, item)
      lunatic_object_effect(:during, item, subj, target)
    else
      target.item_apply(subj, item)
    end
    return if (item.is_a?(RPG::Skill) && item.id == target.guard_skill_id)
    check_skill_guard(target, item) unless item.is_a?(RPG::Item)
    @damage.start(target.result)
    if target.actor?
      @status_window.refresh 
    end
    if $imported["YEA-BattleEngine"]
      status_redraw_target(subj)
      status_redraw_target(target) unless target == subj
    else
      refresh_status
    end
  end
  # --------------------------------------------------------------------------
  # New method : Check skill guard
  # --------------------------------------------------------------------------
  def check_skill_guard(target, item)
    return unless @subject
    return if target == @subject
    return if @subject.friends_unit.members.include?(target)
    return if item.ignore_skill_guard?
    target.skills_guard.each do |skill|
      @subject.item_apply(target, skill)
    end
  end
  # --------------------------------------------------------------------------
  # Alias method : terminate
  # --------------------------------------------------------------------------
  alias tsbs_terminate terminate
  def terminate
    tsbs_terminate
    @damage.dispose
    $game_temp.clear_tsbs
  end
  # --------------------------------------------------------------------------
  # For future features
  # --------------------------------------------------------------------------
  if $imported["YEA-CommandEquip"]
  alias tsbs_command_equip command_equip
  def command_equip
    tsbs_command_equip
    $game_party.battle_members[@status_window.index].battle_phase = :idle
  end
  end
end
#==============================================================================
# ** DamageResult
#------------------------------------------------------------------------------
#  This sprite is used to display damage counter result. It's used inside
# Scene_Battle. Automatically appear when triggered
#==============================================================================
class DamageResult < Sprite
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(viewport = nil)
    super
    self.bitmap = Bitmap.new(200,100)
    bitmap.font.size = 30
    set_anchor
    @value = 0
    self.opacity = 0
    @show = 0
    self.z = 250
  end
  # --------------------------------------------------------------------------
  # * Set anchor origin
  # --------------------------------------------------------------------------
  def set_anchor
    self.ox = width/2
    self.oy = height/2
  end
  # --------------------------------------------------------------------------
  # * Start showing number / Text
  # --------------------------------------------------------------------------
  def start(value)
    @value = value
    @show = 60
    self.opacity = 255
    self.zoom_x = 1.5
    self.zoom_y = 1.5
    bitmap.clear
    bitmap.draw_text(bitmap.rect, value, 1)
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    @show -= 1
    self.zoom_x = [zoom_x - 0.1, 1.0].max
    self.zoom_y = [zoom_x - 0.1, 1.0].max
    if @show < 0
      self.opacity -= 24
    end
  end
  # --------------------------------------------------------------------------
  # * Update position related to battler
  # --------------------------------------------------------------------------
  def update_position(battler)
    sprite = get_spriteset.get_sprite(battler)
    self.x = sprite.x
    self.y = sprite.y - sprite.height
  end
end

#==============================================================================
# ** DamageResults
#------------------------------------------------------------------------------
#  This class brings DamageResult instance object together in Scene_Battle
#==============================================================================

class DamageResults
  # --------------------------------------------------------------------------
  # * Initialize
  # --------------------------------------------------------------------------
  def initialize(viewport)
    @value = 0
    @hit_count = 0
  # ---------------------------------------------------------------
  # * Make damage counter
  # ---------------------------------------------------------------
    @damage_text = Sprite.new(viewport)
    @damage_text.bitmap = Bitmap.new(100,200)
    @damage_text.bitmap.font.color = TSBS::TotalDamage_Color
    @damage_text.bitmap.draw_text(0,0,100,TSBS::TotalDamage_Size,
      TSBS::TotalDamage_Vocab)
    @damage_text.y = TSBS::TotalDamage_Pos[0][0]
    @damage_text.x = TSBS::TotalDamage_Pos[0][1]
    @damage_text.opacity = 0
    @damage = DamageResult.new(viewport)
    @damage.x = TSBS::TotalDamage_Pos[1][0]
    @damage.y = TSBS::TotalDamage_Pos[1][1]
  # ---------------------------------------------------------------  
  # * Make hit counter
  # ---------------------------------------------------------------
    @hit_text = Sprite.new(viewport)
    @hit_text.bitmap = Bitmap.new(100,200)
    @hit_text.bitmap.font.color = TSBS::TotalHit_Color
    @hit_text.bitmap.draw_text(0,0,100,TSBS::TotalHit_Size,
      TSBS::TotalHit_Vocab)
    @hit_text.y = TSBS::TotalHit_Pos[0][0]
    @hit_text.x = TSBS::TotalHit_Pos[0][1]
    @hit = DamageResult.new(viewport)
    @hit.x = TSBS::TotalHit_Pos[1][0]
    @hit.y = TSBS::TotalHit_Pos[1][1]
  # ---------------------------------------------------------------
  # * Make special text result
  # ---------------------------------------------------------------
    @result_text = DamageResult.new(viewport)
    @result_text.bitmap.font.size = 24
    @result_text.bitmap.font.italic = true
  # ---------------------------------------------------------------
    update
  end
  # --------------------------------------------------------------------------
  # * Start showing number
  # --------------------------------------------------------------------------
  def start(result)
    @value += result.hp_damage
    @value += result.mp_damage
    @hit_count += 1 if result.hit?
    @damage.start(@value) if @value > 0
    @hit.start(@hit_count)
  end
  # --------------------------------------------------------------------------
  # * Start showing number
  # --------------------------------------------------------------------------
  def display_counter(battler)
    reset_value
    @result_text.update_position(battler)
    @result_text.start(TSBS::CounterAttack)
  end
  # --------------------------------------------------------------------------
  # * Start showing number
  # --------------------------------------------------------------------------
  def display_reflect(battler)
    @result_text.update_position(battler)
    @result_text.start(TSBS::Magic_Reflect)
  end
  # --------------------------------------------------------------------------
  # * Update
  # --------------------------------------------------------------------------
  def update
    @damage.update
    @hit.update
    @damage_text.opacity = @damage.opacity
    @hit_text.opacity = @hit.opacity
    @result_text.update
  end
  # --------------------------------------------------------------------------
  # * Dispose
  # --------------------------------------------------------------------------
  def dispose
    @damage.bitmap.dispose
    @damage.dispose
    @damage_text.bitmap.dispose
    @damage_text.dispose
    @hit.bitmap.dispose
    @hit.dispose
    @hit_text.bitmap.dispose
    @hit_text.dispose
    @result_text.bitmap.dispose
    @result_text.dispose
  end
  # --------------------------------------------------------------------------
  # * Reset value
  # --------------------------------------------------------------------------
  def reset_value
    @value = 0
    @hit_count = 0
  end
end
