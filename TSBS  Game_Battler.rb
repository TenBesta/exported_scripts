# encoding: utf8
# [128] 75619931: TSBS  Game_Battler
#==============================================================================
# ** Game_Battler
#------------------------------------------------------------------------------
#  A battler class with methods for sprites and actions added. This class 
# is used as a super class of the Game_Actor class and Game_Enemy class.
#==============================================================================

class Game_Battler < Game_BattlerBase
  # --------------------------------------------------------------------------
  # Basic modules
  # --------------------------------------------------------------------------
  include THEO::Movement  # Import basic module for battler movements
  include TSBS            # Import constants
  include Smooth_Slide    # Import smooth sliding module
  # --------------------------------------------------------------------------
  # New public attributes
  # --------------------------------------------------------------------------
  attr_accessor :animation_array    # Store animation sequence
  attr_accessor :battler_index      # Store battler filename index
  attr_accessor :anim_index         # Pointer for animation array
  attr_accessor :anim_cell          # Battler image index
  attr_accessor :item_in_use        # Currently used item
  attr_accessor :visible            # Visible flag
  attr_accessor :flip               # Mirror flag
  attr_accessor :area_flag          # Area damage flag
  attr_accessor :afterimage         # Afterimage flag
  attr_accessor :refresh_opacity    # Refresh opacity flag
  attr_accessor :icon_key           # Store icon key
  attr_accessor :lock_z             # Lock Z flag
  attr_accessor :balloon_id         # Balloon ID for battler
  attr_accessor :anim_guard         # Anim Guard ID
  attr_accessor :anim_guard_mirror  # Mirror Flag
  attr_accessor :afopac             # Afterimage opacity fade speed
  attr_accessor :afrate             # Afterimage show rate
  attr_accessor :forced_act         # Force action
  attr_accessor :force_hit          # Force always hit flag
  # --------------------------------------------------------------------------
  # New public attributes (access only)
  # --------------------------------------------------------------------------
  attr_reader :target         # Current target
  attr_reader :target_array   # Overall target
  attr_reader :battle_phase   # Battle Phase
  attr_reader :finish         # Sequence finish flag
  attr_reader :blend          # Blend
  attr_reader :acts           # Used action
  # --------------------------------------------------------------------------
  # Alias method : initialize
  # --------------------------------------------------------------------------
  alias theo_tsbs_batt_init initialize
  def initialize(*args)
    theo_tsbs_batt_init(*args)
    set_obj(self)
    clear_tsbs
  end
  # --------------------------------------------------------------------------
  # New method : default flip
  # --------------------------------------------------------------------------
  def default_flip
    return false
  end
  # --------------------------------------------------------------------------
  # New method : Store targets in array
  # --------------------------------------------------------------------------
  def target_array=(targets)
    @target_array = targets
    @ori_targets = targets.clone
  end
  # --------------------------------------------------------------------------
  # New method : Store current target
  # --------------------------------------------------------------------------
  def target=(target)
    @target = target
    @ori_target = target
  end
  # --------------------------------------------------------------------------
  # New method : Reset to original position
  # --------------------------------------------------------------------------
  def reset_pos(dur = 30, jump = 0)
    goto(@ori_x, @ori_y, dur, jump)
  end
  # --------------------------------------------------------------------------
  # New method : Clear TSBS infos
  # --------------------------------------------------------------------------
  def clear_tsbs
    @animation_array = []
    @finish = false
    @anim_index = 0
    @anim_cell = 0
    @battler_index = 1
    @battle_phase = nil
    @target = nil
    @ori_target = nil # Store original target. Do not change!
    @target_array = []
    @ori_targets = [] # Store original target array. Do not change!
    @item_in_use = nil  
    @visible = true
    @flip = default_flip
    @area_flag = false
    @afterimage = false
    @proj_start = :middle
    @proj_end = :middle
    @proj_icon = 0
    @refresh_opacity = false
    @screen_z = 0
    @lock_z = false
    @icon_key = ""
    @timed_hit = false
    @timed_hit_count = 0
    @acts = []
    @blend = 0
    @used_sequence = "" # Record the used sequence for error handling
    @sequence_stack = []  # Used sequence stack trace for error handling
    @boomerang = false
    @proj_afimg = false
    @balloon_id = 0
    @anim_guard = 0
    @anim_guard_mirror =  false
    @forced_act = ""
    @force_hit = false
    @proj_scale = 1.0
    reset_aftinfo
  end
  # --------------------------------------------------------------------------
  # New method : Reset afterimage info
  # --------------------------------------------------------------------------
  def reset_aftinfo
    @afopac = 20
    @afrate = 3
  end
  # --------------------------------------------------------------------------
  # New method : Battler update
  # --------------------------------------------------------------------------
  def update
    return if $game_temp.global_freeze && battle_phase != :skill 
    update_move           # Update movements (Basic Module)
    update_smove          # Update smooth movement (Basic Module)
    # Kernel.catch_error(:error1, { "fiber_obj" => fiber_obj }) do
      fiber_obj.resume if fiber_obj
    # end
  end
  # --------------------------------------------------------------------------
  # New method : Fiber object
  # --------------------------------------------------------------------------
  def fiber_obj
    return nil 
  end
  # --------------------------------------------------------------------------
  # New method : Force change battle phase
  # --------------------------------------------------------------------------
  def force_change_battle_phase(phase)
    @battle_phase = phase
    @used_sequence = phase_sequence[phase].call
    @sequence_stack = [@used_sequence]
    @anim_index = 0
    @anim_index = rand(get_animloop_array.size - 1) if phase == :idle
    @finish = false
    @animation_array = get_animloop_array.dup
    fiber = Fiber.new { update_anim_index }
    insert_fiber(fiber)
  end
  # --------------------------------------------------------------------------
  # New method : Set battle phase
  # --------------------------------------------------------------------------
  def battle_phase=(phase)
    return if (phase == :idle || phase == :hurt) && 
      [:evade, :counter].any? { |temp| battle_phase == temp }
    return if phase == :hurt && (dead? || battle_phase == :forced)
    force_change_battle_phase(phase)
  end
  # --------------------------------------------------------------------------
  # Alias method : On battle start
  # --------------------------------------------------------------------------
  alias theo_on_bs_start on_battle_start
  def on_battle_start
    theo_on_bs_start
    @screen_z = screen_z_formula
    self.battle_phase = :idle unless battle_phase == :intro
  end
  # --------------------------------------------------------------------------
  # New method : Store fiber in $game_temp
  # --------------------------------------------------------------------------
  def insert_fiber(fiber)
    if actor?
      $game_temp.actors_fiber[id] = fiber
    else
      $game_temp.enemies_fiber[index] = fiber
    end
  end
  # --------------------------------------------------------------------------
  # New method : Refers to battler database
  # --------------------------------------------------------------------------
  def data_battler
    return nil
  end
  # --------------------------------------------------------------------------
  # New method : Determine if battler is in critical condition
  # --------------------------------------------------------------------------
  def critical?
    hp_rate <= Critical_Rate
  end
  # --------------------------------------------------------------------------
  # New method : Phase sequence key
  # --------------------------------------------------------------------------
  def phase_sequence
    hash = {
      :idle => method(:idle),
      :victory => method(:victory),
      :hurt => method(:hurt),
      :skill => method(:skill),
      :evade => method(:evade),
      :return => method(:return),
      :escape => method(:escape_key),
      :prepare => method(:prepare_key),
      :intro => method(:intro_key),
      :counter => method(:counter_key),
      :collapse => method(:collapse_key),
      :forced => method(:forced_act)
    }
    return hash
  end
  # --------------------------------------------------------------------------
  # New method : Idle sequence key
  # --------------------------------------------------------------------------
  # Idle key sequence contains several sequence keys. Include dead sequence,
  # state sequence, critical sequence,and normal sequence. Dead key sequence
  # has the top priority over others. Just look at the below
  # --------------------------------------------------------------------------
  def idle
    return data_battler.dead_key if dead? && actor?
    return state_sequence if state_sequence
    return data_battler.critical_key if critical? && 
      !data_battler.critical_key.empty?
    return data_battler.idle_key
  end
  # --------------------------------------------------------------------------
  # New method : Escape sequence key
  # --------------------------------------------------------------------------
  def escape_key
    return data_battler.escape_key
  end
  # --------------------------------------------------------------------------
  # New method : Victory sequence key
  # --------------------------------------------------------------------------
  def victory
    return data_battler.victory_key
  end
  # --------------------------------------------------------------------------
  # New method : Hurt sequence key
  # --------------------------------------------------------------------------
  def hurt
    return data_battler.hurt_key
  end
  # --------------------------------------------------------------------------
  # New method : Skill sequence key
  # Must be called when item_in_use isn't nil
  # --------------------------------------------------------------------------
  def skill
    return item_in_use.seq_key[rand(item_in_use.seq_key.size)]
  end
  # --------------------------------------------------------------------------
  # New method : Evade sequence key
  # --------------------------------------------------------------------------
  def evade
    return data_battler.evade_key
  end
  # --------------------------------------------------------------------------
  # New method : Return sequence key
  # Must be called when item_in_use isn't nil
  # --------------------------------------------------------------------------
  def return
    return item_in_use.return_key if !item_in_use.return_key.empty?
    return data_battler.return_key
  end
  # --------------------------------------------------------------------------
  # New method : Preparation key
  # Must be called when item_in_use isn't nil
  # --------------------------------------------------------------------------
  def prepare_key
    return item_in_use.prepare_key
  end
  # --------------------------------------------------------------------------
  # New method : Intro sequence key
  # --------------------------------------------------------------------------
  def intro_key
    return data_battler.intro_key
  end
  # --------------------------------------------------------------------------
  # New method : Counter sequence key
  # --------------------------------------------------------------------------
  def counter_key
    return data_battler.counter_key
  end
  # --------------------------------------------------------------------------
  # New method : Collapse sequence key
  # --------------------------------------------------------------------------
  def collapse_key
    return data_battler.collapse_key
  end
  # --------------------------------------------------------------------------
  # Debug only : print current action sequence
  # --------------------------------------------------------------------------
  def print_current_action
    p phase_sequence[battle_phase].call
  end
  # --------------------------------------------------------------------------
  # Main animation sequence goes here
  # --------------------------------------------------------------------------
  def update_anim_index
    
    # ----- Start ------ #
    @finish = false
    @proj_scale = 1.0
    unless @animation_array[0].all?{|init| [nil,false,true,:ori].include?(init)}
      ErrorSound.play
      text = "Sequence : #{@used_sequence}\nYou miss the initial setup"
      msgbox text
      exit
    end
    flip_val = @animation_array[0][2] # Flip Value
    @flip = flip_val if !flip_val.nil?
    @flip = default_flip if flip_val == :ori || (flip_val.nil? && 
      battle_phase != :skill)
    # If battle phase isn't :skill, nil flip value will return the battler
    # flip into default one
    
    @afterimage = @animation_array[0][1]
    @timed_hit = false    # Timed hit flag
    @timed_hit_count = 0  # Timed hit count
    reset_aftinfo
    setup_instant_reset if battle_phase == :intro
    # ----- Start ---- #
    
    tsbs_battler_post_start
    
    # --- Main Loop thread --- #
    loop do
      @acts = animloop
      @screen_z = screen_z_formula unless @lock_z  # update screen z
      execute_sequence # Execute sequence array
      end_phase  # Do end ~
    end
    # --- Main Loop thread --- #
  end
  # --------------------------------------------------------------------------
  # New method : Post Start (empty)
  # --------------------------------------------------------------------------
  def tsbs_battler_post_start
  end
  # --------------------------------------------------------------------------
  # New method : Execute Sequence array
  # --------------------------------------------------------------------------
  def execute_sequence
    case @acts[0]
    when SEQUENCE_POSE;               setup_pose
    when SEQUENCE_MOVE;               setup_move
    when SEQUENCE_SLIDE;              setup_slide
    when SEQUENCE_RESET;              setup_reset
    when SEQUENCE_MOVE_TO_TARGET;     setup_move_to_target
    when SEQUENCE_SCRIPT;             setup_eval_script
    when SEQUENCE_WAIT;               @acts[1].times { method_wait }
    when SEQUENCE_DAMAGE;             setup_damage
    when SEQUENCE_CAST;               setup_cast
    when SEQUENCE_VISIBLE;            @visible = @acts[1]
    when SEQUENCE_SHOW_ANIMATION;     setup_anim
    when SEQUENCE_AFTERIMAGE;         @afterimage = @acts[1]
    when SEQUENCE_FLIP;               setup_flip
    when SEQUENCE_ACTION;             setup_action
    when SEQUENCE_PROJECTILE_SETUP;   setup_projectile
    when SEQUENCE_PROJECTILE;         show_projectile
    when SEQUENCE_USER_DAMAGE;        setup_user_damage
    when SEQUENCE_LOCK_Z;             @lock_z = @acts[1]
    when SEQUENCE_ICON;               setup_icon
    when SEQUENCE_SOUND;              setup_sound
    when SEQUENCE_IF;                 setup_branch
    when SEQUENCE_TIMED_HIT;          setup_timed_hit
    when SEQUENCE_SCREEN;             setup_screen
    when SEQUENCE_ADD_STATE;          setup_add_state
    when SEQUENCE_REM_STATE;          setup_rem_state  
    when SEQUENCE_CHANGE_TARGET;      setup_change_target
    when SEQUENCE_SHOW_PICTURE;       setup_show_picture
    when SEQUENCE_TARGET_MOVE;        setup_target_move
    when SEQUENCE_TARGET_SLIDE;       setup_target_slide
    when SEQUENCE_TARGET_RESET;       setup_target_reset
    when SEQUENCE_BLEND;              @blend = @acts[1]
    when SEQUENCE_FOCUS;              setup_focus
    when SEQUENCE_UNFOCUS;            setup_unfocus
    when SEQUENCE_TARGET_LOCK_Z;      setup_target_z
      # New update list v1.1
    when SEQUENCE_ANIMTOP;            $game_temp.anim_top = 1
    when SEQUENCE_FREEZE;             $game_temp.global_freeze = @acts[1]
    when SEQUENCE_CSTART;             setup_cutin
    when SEQUENCE_CFADE;              setup_cutin_fade
    when SEQUENCE_CMOVE;              setup_cutin_slide
    when SEQUENCE_TARGET_FLIP;        setup_targets_flip
    when SEQUENCE_PLANE_ADD;          setup_add_plane
    when SEQUENCE_PLANE_DEL;          setup_del_plane
    when SEQUENCE_BOOMERANG;          @boomerang = true
    when SEQUENCE_PROJ_AFTERIMAGE;    @proj_afimg = true
    when SEQUENCE_BALLOON;            self.balloon_id = @acts[1]
      # New update list v1.2
    when SEQUENCE_LOGWINDOW;          setup_log_message
    when SEQUENCE_LOGCLEAR;           SceneManager.scene.log_window.clear
    when SEQUENCE_AFTINFO;            setup_aftinfo
    when SEQUENCE_SMMOVE;             setup_smooth_move
    when SEQUENCE_SMSLIDE;            setup_smooth_slide
    when SEQUENCE_SMTARGET;           setup_smooth_move_target
    when SEQUENCE_SMRETURN;           setup_smooth_return
      # New update list v1.3 + v1.3b + v1.3c
    when SEQUENCE_LOOP;               setup_loop
    when SEQUENCE_WHILE;              setup_while
    when SEQUENCE_COLLAPSE;           tsbs_perform_collapse_effect
    when SEQUENCE_FORCED;             setup_force_act
    when SEQUENCE_ANIMBOTTOM;         $game_temp.anim_top = -1
    when SEQUENCE_CASE;               setup_switch_case
    when SEQUENCE_INSTANT_RESET;      setup_instant_reset
    when SEQUENCE_ANIMFOLLOW;         $game_temp.anim_follow = true
    when SEQUENCE_CHANGE_SKILL;       setup_change_skill
    when SEQUENCE_CHECKCOLLAPSE;      setup_check_collapse
    when SEQUENCE_RESETCOUNTER;       SceneManager.scene.damage.reset_value
    when SEQUENCE_FORCEHIT;           @force_hit = true
    when SEQUENCE_SLOWMOTION;         setup_slow_motion
    when SEQUENCE_TIMESTOP;           setup_timestop
    when SEQUENCE_ONEANIM;            $game_temp.one_animation_flag = true
    when SEQUENCE_PROJ_SCALE;         setup_proj_scale
    when SEQUENCE_COMMON_EVENT;       setup_tsbs_common_event
    when SEQUENCE_GRAPHICS_FREEZE;    Graphics.freeze
    when SEQUENCE_GRAPHICS_TRANS;     setup_transition
      # Interesting on addons?
    else;                             custom_sequence_handler
    end
  end
  # --------------------------------------------------------------------------
  # New method : End fiber loop phase
  # --------------------------------------------------------------------------
  def end_phase
    next_anim_index
    @finish = @anim_index == 0
    if temporary_phase? && @finish
      self.force_change_battle_phase(:idle)
    end
    Fiber.yield while @finish && !loop? 
    # Forever wait if finished and not loop
  end
  # --------------------------------------------------------------------------
  # New method : Setup pose [:pose,]
  # --------------------------------------------------------------------------
  def setup_pose
    return TSBS.error(@acts[0], 3, @used_sequence) if @acts.size < 4
    @battler_index = @acts[1]         # Battler index
    @anim_cell = @acts[2]             # Change cell
    @icon_key = @acts[4] if @acts[4]  # Icon call
    @icon_key = @acts[5] if @acts[5] && flip  # Icon call
    @acts[3].times do                 # Wait time
      method_wait
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup movement [:move,]
  # --------------------------------------------------------------------------
  def setup_move
    return TSBS.error(@acts[0], 4, @used_sequence) if @acts.size < 5
    @move_obj.clear_move_info
    goto(@acts[1], @acts[2], @acts[3], @acts[4])
  end
  # --------------------------------------------------------------------------
  # New method : Setup slide [:slide,]
  # --------------------------------------------------------------------------
  def setup_slide
    return TSBS.error(@acts[0], 4, @used_sequence) if @acts.size < 5
    @move_obj.clear_move_info
    xpos = (flip ? -@acts[1] : @acts[1])
    ypos = @acts[2]
    slide(xpos, ypos, @acts[3], @acts[4])
  end
  # --------------------------------------------------------------------------
  # New method : Setup reset [:goto_oripost,]
  # --------------------------------------------------------------------------
  def setup_reset
    @move_obj.clear_move_info
    goto(@ori_x, @ori_y, @acts[1], @acts[2])
  end
  # --------------------------------------------------------------------------
  # New method : Setup move to target [:move_to_target,]
  # --------------------------------------------------------------------------
  def setup_move_to_target
    return TSBS.error(@acts[0], 4, @used_sequence) if @acts.size < 5
    @move_obj.clear_move_info
    if area_flag
      size = target_array.size
      xpos = target_array.inject(0) {|r,battler| r + battler.x}/size
      ypos = target_array.inject(0) {|r,battler| r + battler.y}/size
      xpos += @acts[1]
      xpos *= -1 if flip
      # Get the center coordinate of enemies
      goto(xpos, ypos + @acts[2], @acts[3], @acts[4])
      return
    end
    xpos = target.x + (flip ? -@acts[1] : @acts[1])
    ypos = target.y + @acts[2]
    goto(xpos, ypos, @acts[3], @acts[4])
  end
  # --------------------------------------------------------------------------
  # New method : Display Error
  # --------------------------------------------------------------------------
  def display_error(mode, err)
    ErrorSound.play
    id = data_battler.id
    seq_key = phase_sequence[battle_phase].call
    phase = (dead? ? :dead : battle_phase)
    klass = data_battler.class
    result = "Theolized SBS : "+
    "Error occured on #{klass} in ID #{id}\n" +
    "Sequence key \"#{seq_key}\" In script call #{mode}.\n\n " +
    "#{err.to_s}\n\n" +
    "Check your script call. If you still have no idea, ask for support " +
    "in RPG Maker forums"
    msgbox result
    exit
  end
  # --------------------------------------------------------------------------
  # New method : Setup eval script [:script,]
  # --------------------------------------------------------------------------
  def setup_eval_script
    begin
      eval(@acts[1])
    rescue StandardError => err
      display_error("[#{SEQUENCE_SCRIPT}, hello]",err)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup damage [:target_damage,]
  # --------------------------------------------------------------------------
  def setup_damage
    item = copy(item_in_use) 
    # Copy item. In case if you want to modify anything :P
    
    # ----- Evaluate skill ------- #
    if @acts[1].is_a?(String) # Change formula? No prob ~
      item.damage.formula = @acts[1]
    elsif @acts[1].is_a?(Integer) # Skill link? No prob ~
      item = $data_skills[@acts[1]]
    elsif @acts[1].is_a?(Float) # Rescale damage? No prob ~
      item.damage.formula = "(#{item.damage.formula}) * #{@acts[1]}"
    end
    
    # ------- Check target scope ------- #
    if area_flag && target_array
      # Damage to all targets ~
      target_array.uniq.each do |target|
        SceneManager.scene.tsbs_invoke_item(target, item, self)
        # Check animation guard
        if !item.ignore_anim_guard? && item.parallel_anim?
          target.anim_guard = target.anim_guard_id
          target.anim_guard_mirror = target.flip
        end
      end
    elsif target
      # Damage to single target
      SceneManager.scene.tsbs_invoke_item(target, item, self)
      # Check animation guard
      if !item.ignore_anim_guard? && item.parallel_anim?
        target.anim_guard = target.anim_guard_id
        target.anim_guard_mirror = target.flip
      end
    end
    @force_hit = false # Reset force hit
  end
  # --------------------------------------------------------------------------
  # New method : Setup cast [:cast,]
  # --------------------------------------------------------------------------
  def setup_cast
    self.animation_id = @acts[1] || item_in_use.animation_id
    self.animation_mirror = (@acts[2].nil? ? flip : @acts[2])
  end
  # --------------------------------------------------------------------------
  # New method : Setup animation [:show_anim,]
  # --------------------------------------------------------------------------
  def setup_anim
    if $game_temp.one_animation_flag || (@acts[1].nil? && item_in_use &&
        item_in_use.one_animation)
      handler = get_spriteset.one_anim
      size = target_array.size
      xpos = target_array.inject(0) {|r,battler| r + battler.screen_x}/size
      ypos = target_array.inject(0) {|r,battler| r + battler.screen_y}/size
      zpos = target_array.inject(0) {|r,battler| r + battler.screen_z}/size
      handler.set_position(xpos, ypos, zpos)
      sprites = target_array.collect {|t| get_spriteset.get_sprite(t)}
      handler.target_sprites = sprites
      anim_id = (@acts[1].nil? ? item_in_use.animation_id : @acts[1])
      anim_id = atk_animation_id1 if anim_id == -1 && actor?
      mirror = flip || @acts[2]
      $game_temp.one_animation_id = anim_id
      $game_temp.one_animation_flip = mirror
      $game_temp.one_animation_flag = false
    elsif area_flag
      target_array.uniq.each do |target|
        setup_target_anim(target, @acts)
      end
    else
      setup_target_anim(target, @acts)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup target animation
  # --------------------------------------------------------------------------
  def setup_target_anim(target, ary)
    return unless target
    anim_id = target.anim_guard_id  # Animation guard
    is_self = target == self        # Determine if self
    # ------------------------------------------------------------------------
    # Animation guard activation conditions
    # ------------------------------------------------------------------------
    condition = !is_self && anim_id > 0 && !item_in_use.damage.recover? &&
      !item_in_use.ignore_anim_guard? && !ary[3] && !item_in_use.parallel_anim?
    # ------------------------------------------------------------------------
    # Condition list :
    # > Animation guard won't be played to self targeting
    # > Animation guard won't be played if the index is 0 or less
    # > Animation guard won't be played if item/skill is recovery
    # > Animation guard won't be played if item/skill ignores it
    # > Animation guard won't be played if explicitly ignores in sequence
    # > Animation guard won't be played if item is parallel animation. Instead,
    #   it will be played simultaneously when [:target_damage,] is triggered
    # ------------------------------------------------------------------------
    # If anim_id explicitly given
    if ary[1]
      result_anim = (condition && ary[1] > 0 ? anim_id : ary[1])
      target.animation_id = result_anim
      target.animation_mirror = flip || ary[2]
    # If self is an Actor and skill/item use normal attack animation
    elsif self.is_a?(Game_Actor) && item_in_use.animation_id == -1
      result_anim = (condition ? anim_id : atk_animation_id1)
      target.animation_id = result_anim
      target.animation_mirror = flip || ary[2]
    # If anything ...
    else
      result_anim = (condition ? anim_id : item_in_use.animation_id)
      target.animation_id = result_anim
      target.animation_mirror = flip || ary[2]
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup battler flip [:flip,]
  # --------------------------------------------------------------------------
  def setup_flip
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    if @acts[1] == :toggle
      @flip = !@flip 
    elsif @acts[1] == :ori
      @flip = default_flip
    else
      @flip = @acts[1]
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup actions [:action,]
  # --------------------------------------------------------------------------
  def setup_action
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    actions = TSBS::AnimLoop[@acts[1]]
    if actions.nil?
      show_action_error(@acts[1])
    end
    @sequence_stack.push(@acts[1])
    @used_sequence = @acts[1]
    actions.each do |acts|
      @acts = acts
      execute_sequence
    end
    @sequence_stack.pop
    @used_sequence = @sequence_stack[-1]
  end
  # --------------------------------------------------------------------------
  # New method : Setup projectile [:proj_setup,]
  # --------------------------------------------------------------------------
  def setup_projectile
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    @proj_start = @acts[1]
    @proj_end = @acts[2]
  end
  # --------------------------------------------------------------------------
  # New method : Show projectile [:projectile,]
  # --------------------------------------------------------------------------
  def show_projectile
    return TSBS.error(@acts[0], 3, @used_sequence) if @acts.size < 4
    if $game_temp.one_animation_flag || item_in_use.one_animation
      get_spriteset.add_projectile(make_projectile(target_array))
      $game_temp.one_animation_flag = false
    elsif area_flag
      target_array.uniq.each do |target|
        get_spriteset.add_projectile(make_projectile(target))
      end
    else
      get_spriteset.add_projectile(make_projectile(target))
    end
    # Turn off extra projectile flag
    @boomerang = false
    @proj_afimg = false
  end
  # --------------------------------------------------------------------------
  # New method : Make Projectile
  # --------------------------------------------------------------------------
  def make_projectile(target)
    spr_self = get_spriteset.get_sprite(self)
    proj = Sprite_Projectile.new
    
    # Initialize the projectile position
    proj.x = self.screen_x
    case @proj_start
    when :feet
      proj.y = self.screen_y
    when :middle
      proj.y = self.screen_y - spr_self.height/2
    when :head
      proj.y = self.screen_y - spr_self.height
    end
    
    # Assign the basic carried information for projectile
    proj.subject = self
    proj.target = target
    proj_item = copy(item_in_use)
    
    # Modify carried item
    if @proj_scale.is_a?(String)
      proj_item.damage.formula = @proj_scale
    elsif @proj_scale.is_a?(Numeric)
      proj_item.damage.formula = "(#{proj_item.damage.formula})*#{@proj_scale}"
    end
    proj.item = proj_item
    
    # Check icon use
    ico = @acts[4]
    icon_index = 0
    begin
      icon_index = (ico.is_a?(String) ? eval(ico) : (ico.nil? ? 0 : ico))
    rescue StandardError => err
      display_error("[#{SEQUENCE_PROJECTILE},]",err)
    end
    proj.icon = icon_index
    
    # Add extra information before return
    anim = $data_animations[@acts[1]]
    dur = @acts[2]
    jump = @acts[3]
    proj.angle_speed = @acts[5] || 0
    proj.boomerang = @boomerang
    proj.afterimage = @proj_afimg
    proj.target_aim = @proj_end
    proj.make_aim(dur, jump)
    proj.start_animation(anim)
    
    # Returning the projectile sprite
    return proj
  end
  # --------------------------------------------------------------------------
  # New method : User damage [:user_damage]
  # TBH, I think it's not really necessary since you could change the target
  # to self by adding [:change_target, 11],  :/
  # --------------------------------------------------------------------------
  def setup_user_damage
    item = item_in_use
    if @acts[1].is_a?(String)
      item.damage.formula = @acts[1]
    elsif @acts[1].is_a?(Integer)
      item = $data_skills[@acts[1]]
    elsif @acts[1].is_a?(Float)
      item.damage.formula = "(#{item.damage.formula}) * #{@acts[1]}"
    end
    SceneManager.scene.tsbs_invoke_item(self, item, self)
  end
  # --------------------------------------------------------------------------
  # New method : Setup weapon icon [:icon,]
  # --------------------------------------------------------------------------
  def setup_icon
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    @icon_key = @acts[1]
    @icon_key = @acts[2] if @acts[2] && flip
  end
  # --------------------------------------------------------------------------
  # New method : Setup sound [:sound,]
  # --------------------------------------------------------------------------
  def setup_sound
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    name = @acts[1]
    vol = @acts[2] || 100
    pitch = @acts[3] || 100
    RPG::SE.new(name,vol,pitch).play
  end
  # --------------------------------------------------------------------------
  # New method : Setup conditional branch
  # --------------------------------------------------------------------------
  def setup_branch
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    act_true = @acts[2]
    act_false = @acts[3]
    bool = false
    begin # Test the script call condition
      bool = eval(@acts[1])
    rescue StandardError => err
      # Blame the script user if error :v
      display_error("[#{SEQUENCE_IF},]",err)
    end
    act_result = (bool ? act_true : (!act_false.nil? ? act_false: nil))
    if act_result
      is_array = act_result.is_a?(Array)
      if is_array && act_result[0].is_a?(Array)
        act_result.each do |action|
          next unless action.is_a?(Array)
          @acts = action
          execute_sequence
        end
      elsif is_array
        @acts = act_result
        execute_sequence
      else
        @acts = [:action, act_result]
        execute_sequence
      end
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup timed hit system (BETA)
  # Will expand it later. I hope ~
  # --------------------------------------------------------------------------
  def setup_timed_hit
    @timed_hit = false
    @timed_hit_count = @acts[1]
  end
  # --------------------------------------------------------------------------
  # New method : Setup screen
  # --------------------------------------------------------------------------
  def setup_screen
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    screen = $game_troop.screen
    case @acts[1]
    when Screen_Tone
      return TSBS.error(@acts[0], 3, @used_sequence) if @acts.size < 4
      tone = @acts[2]
      duration = @acts[3]
      screen.start_tone_change(tone, duration)
    when Screen_Shake
      return TSBS.error(@acts[0], 4, @used_sequence) if @acts.size < 5
      power = @acts[2]
      speed = @acts[3]
      duration = @acts[4]
      screen.start_shake(power, speed, duration)
    when Screen_Flash
      return TSBS.error(@acts[0], 3, @used_sequence) if @acts.size < 4
      color = @acts[2]
      duration = @acts[3]
      screen.start_flash(color, duration)
    when Screen_Normalize
      return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
      tone = Tone.new
      duration = @acts[2]
      screen.start_tone_change(tone, duration)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup add state [:add_state,]
  # --------------------------------------------------------------------------
  def setup_add_state
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    c = @acts[2] || 100
    c = c/100.0 if c.integer?
    if area_flag
      target_array.each do |t|
        cx = c # Chance extra
        if !@acts[3]
          cx *= target.state_rate(@acts[1]) if opposite?(self)
          cx *= target.luk_effect_rate(self) if opposite?(self)
        end
        t.add_state(@acts[1]) if chance(cx)
      end
      return
    end
    return unless target
    if !@acts[3]
      c *= target.state_rate(@acts[1]) if opposite?(self)
      c *= target.luk_effect_rate(self) if opposite?(self)
    end
    target.add_state(@acts[1]) if chance(c)
  end
  # --------------------------------------------------------------------------
  # New method : Setup remove state [:rem_state,]
  # --------------------------------------------------------------------------
  def setup_rem_state
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    c = @acts[2] || 100
    c = c/100.0 if c.integer?
    if area_flag
      target_array.each do |t|
        t.remove_state(@acts[1]) if chance(c)
      end
      return
    end
    target.remove_state(@acts[1]) if chance(c)
  end
  # --------------------------------------------------------------------------
  # New method : Setup change target [:change_target,]
  # --------------------------------------------------------------------------
  def setup_change_target
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    case @acts[1]
    # --------------------
    when 0  # Original Target
      self.area_flag = item_in_use.area?
      @target = @ori_target
      @target_array = @ori_targets.clone
    # -------------------
    when 1  # All Battler
      self.area_flag = true
      t = $game_party.alive_members + $game_troop.alive_members
      @target_array = t
      $game_temp.battler_targets += t
    # -------------------
    when 2  # All Battler except user
      self.area_flag = true
      t = $game_party.alive_members + $game_troop.alive_members
      t -= [self]
      @target_array = t
      $game_temp.battler_targets += t
    # -------------------
    when 3  # All Enemies
      self.area_flag = true
      t = opponents_unit.alive_members
      @target_array = t
      $game_temp.battler_targets += t
    # -------------------
    when 4  # All Enemies except current target
      self.area_flag = true
      t = opponents_unit.alive_members
      t -= [target]
      @target_array = t
      $game_temp.battler_targets += t
    # -------------------
    when 5  # All Allies
      self.area_flag = true
      t = friends_unit.alive_members
      @target_array = t
      $game_temp.battler_targets += t
    # -------------------
    when 6  # All Allies except user
      self.area_flag = true
      t = friends_unit.alive_members
      t -= [self]
      @target_array = t
      $game_temp.battler_targets += t
    # -------------------
    when 7  # Next random enemy
      self.area_flag = false
      @target = opponents_unit.random_target
      $game_temp.battler_targets += [@target]
    # -------------------
    when 8  # Next random ally
      self.area_flag = false
      @target = friends_unit.random_target
      $game_temp.battler_targets += [@target]
    # -------------------
    when 9  # Absolute Targets (Enemies)
      self.area_flag = true
      @target_array = opponents_unit.abs_target(@acts[2])
      @target_array -= [target] if @acts[3]
      $game_temp.battler_targets += @target_array
    # -------------------
    when 10 # Absolute Target (Allies)
      self.area_flag = true
      @target_array = friends_unit.abs_target(@acts[2])
      @target_array -= [target] if @acts[3]
      $game_temp.battler_targets += @target_array
    # -------------------
    when 11 # self
      self.area_flag = false
      @target = self
      $game_temp.battler_targets += [@target]
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup new picture (not tested) [:show_pic,]
  # Seriously, it's not tested yet. I just looked at the default script, how
  # to call picture. And I merely put the method here without testing
  # --------------------------------------------------------------------------
  def setup_show_picture
    pictures = $game_troop.screen.pictures
    id = @acts[1]
    name = @acts[2]
    ori = @acts[3]
    xpos = @acts[4]
    ypos = @acts[5]
    zx = @acts[6]
    zy = @acts[7]
    op = @acts[8]
    blend = @acts[9]
    args = [name, ori, xpos, ypos, zx, zy, op, blend]
    pictures[id].show(*args)
  end
  # --------------------------------------------------------------------------
  # New method : Setup target movement [:target_move,]
  # --------------------------------------------------------------------------
  def setup_target_move
    return TSBS.error(@acts[0], 4, @used_sequence) if @acts.size < 5
    args = [@acts[1], @acts[2], @acts[3], @acts[4]]
    if area_flag
      target_array.each do |target|
        target.goto(*args)
      end
      return
    end
    target.goto(*args)
  end
  # --------------------------------------------------------------------------
  # New method : Setup target slide [:target_slide,]
  # --------------------------------------------------------------------------
  def setup_target_slide
    return TSBS.error(@acts[0], 4, @used_sequence) if @acts.size < 5
    args = [@acts[1], @acts[2], @acts[3], @acts[4]]
    if area_flag
      target_array.each do |target|
        target.slide(*args)
      end
      return
    end
    target.slide(*args)
  end
  # --------------------------------------------------------------------------
  # New method : Setup target reset [:target_reset]
  # --------------------------------------------------------------------------
  def setup_target_reset
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    if area_flag
      target_array.each do |target|
        target.reset_pos(@acts[1],@acts[2])
      end
      return
    end
    target.reset_pos(@acts[1],@acts[2])
  end
  # --------------------------------------------------------------------------
  # New method : Setup focus [:focus,]
  # --------------------------------------------------------------------------
  def setup_focus
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    sprset = get_spriteset
    rect = sprset.focus_bg.bitmap.rect
    color = @acts[2] || Focus_BGColor
    sprset.focus_bg.bitmap.fill_rect(rect,color)  # Recolor focus background
    sprset.focus_bg.fadein(@acts[1])        # Trigger fadein
    sprset.battler_sprites.select do |spr|
      !spr.battler.nil? # Select avalaible battler
    end.each do |spr|
      if spr.battler != self && (spr.battler.actor? ? true : spr.battler.alive?)
        spr.fadeout(@acts[1]) if !target_array.include?(spr.battler)
        spr.fadein(@acts[1]) if target_array.include?(spr.battler)
      end
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup unfocus [:unfocus,]
  # --------------------------------------------------------------------------
  def setup_unfocus
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    sprset = get_spriteset
    sprset.focus_bg.fadeout(@acts[1])
    batch = sprset.battler_sprites.select do |spr|
      !spr.battler.nil? #&& !spr.collapsing? # Select avalaible battler
    end
    batch.each do |spr|
      spr.fadein(@acts[1]) if spr.battler.alive? || spr.battler.actor?
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup target lock Z [:target_lock_z,]
  # --------------------------------------------------------------------------
  def setup_target_z
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    if area_flag
      target_array.each do |target|
        target.lock_z = @acts[1]
      end
      return
    end
    target.lock_z = @acts[1]
  end
  # --------------------------------------------------------------------------
  # New method : Cutin Start [:cutin_start,]
  # --------------------------------------------------------------------------
  def setup_cutin
    return TSBS.error(@acts[0], 3, @used_sequence) if @acts.size < 4
    #-------------------------------------------------------------------------
    file = @acts[1]         # Filename
    x = @acts[2]            # X Position
    y = @acts[3]            # Y Position
    opa = @acts[4] || 255   # Opacity (default: 255)
    zx = @acts[5] || 1.0    # Zoom X  (default: 1.0)
    zy = @acts[6] || 1.0    # Zoom Y  (default: 1.0)
    #-------------------------------------------------------------------------
    get_spriteset.cutin.start(file,x,y,opa,zx,zy)
  end
  # --------------------------------------------------------------------------
  # New method : Cutin Fade [:cuitn_fade,]
  # --------------------------------------------------------------------------
  def setup_cutin_fade
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    get_spriteset.cutin.fade(@acts[1], @acts[2])
  end
  # --------------------------------------------------------------------------
  # New method : Cutin Slide [:cutin_slide,]
  # --------------------------------------------------------------------------
  def setup_cutin_slide
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    get_spriteset.cutin.slide(@acts[1], @acts[2], @acts[3])
  end
  # --------------------------------------------------------------------------
  # New method : Setup Targets flip [:target_flip,]
  # -------------------------------------------------------------------------- 
  def setup_targets_flip
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    if area_flag
      target_array.each do |target|
        target.flip = @acts[1]
      end
      return
    end
    target.flip = @acts[1]
  end
  # --------------------------------------------------------------------------
  # New method : Setup Add Plane [:plane_add,]
  # --------------------------------------------------------------------------
  def setup_add_plane
    return TSBS.error(@acts[0], 3, @used_sequence) if @acts.size < 3
    file = @acts[1]
    sox = @acts[2] # Scroll X
    soy = @acts[3] # Scroll Y 
    z = (@acts[4] ? 400 : 4)
    dur = @acts[5] || 2
    opac = @acts[6] || 255
    get_spriteset.battle_plane.set(file,sox,soy,z,dur,opac)
  end
  # --------------------------------------------------------------------------
  # New method : Setup Delete Plane [:plane_del,]
  # --------------------------------------------------------------------------
  def setup_del_plane
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    fade = @acts[1]
    get_spriteset.battle_plane.fadeout(fade)
  end
  # --------------------------------------------------------------------------
  # New method : Setup Log Message Window [:log,]
  # --------------------------------------------------------------------------
  def setup_log_message
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    text = @acts[1].gsub(/<name>/i) { self.name }
    text.gsub!(/<target>/) { target.name rescue "" }
    SceneManager.scene.log_window.add_text(text)
  end
  # --------------------------------------------------------------------------
  # New method : Setup Afterimage Information [:aft_info,]
  # --------------------------------------------------------------------------
  def setup_aftinfo
    @afrate = @acts[1] || 3
    @afopac = @acts[2] || 20
  end
  # --------------------------------------------------------------------------
  # New method : Smooth Moving [:sm_move,]
  # --------------------------------------------------------------------------
  def setup_smooth_move
    tx = @acts[1] || x
    ty = @acts[2] || y
    dur = @acts[3] || 25
    rev = @acts[4]
    rev = true if rev.nil?
    smooth_move(tx,ty,dur,rev)
  end
  # --------------------------------------------------------------------------
  # New method : Smooth Sliding [:sm_slide,]
  # --------------------------------------------------------------------------
  def setup_smooth_slide
    tx = @acts[1] + x || 0
    ty = @acts[2] + y || 0
    dur = @acts[3] || 25
    rev = @acts[4]
    rev = true if rev.nil?
    smooth_move(tx,ty,dur,rev)
  end
  # --------------------------------------------------------------------------
  # New method : Smooth Move to target [:sm_target,]
  # --------------------------------------------------------------------------
  def setup_smooth_move_target
    if area_flag
      size = target_array.size
      xpos = target_array.inject(0) {|r,battler| r + battler.x}/size
      ypos = target_array.inject(0) {|r,battler| r + battler.y}/size
      xpos += @acts[1]
      xpos *= -1 if flip
      rev = @acts[3]
      rev = true if rev.nil?
      smooth_move(xpos, ypos + @acts[2], @acts[3])
      return
    end
    return unless target
    tx = @acts[1] + target.x || 0
    ty = @acts[2] + target.y || 0
    tx *= -1 if flip
    dur = @acts[3] || 25
    rev = @acts[4]
    rev = true if rev.nil?
    smooth_move(tx,ty,dur,rev)
  end
  # --------------------------------------------------------------------------
  # New method : Smooth return [:sm_return,]
  # --------------------------------------------------------------------------
  def setup_smooth_return
    tx = @ori_x
    ty = @ori_y
    dur = @act[1] || 25
    rev = @acts[2]
    rev = true if rev.nil?
    smooth_move(tx,ty,dur,rev)
  end
  # --------------------------------------------------------------------------
  # New method : Setup loop [:loop,]
  # --------------------------------------------------------------------------
  def setup_loop
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    count = @acts[1]
    action_key = @acts[2]
    is_string = action_key.is_a?(String)
    count.times do
      if is_string
        @acts = [:action, action_key]
        execute_sequence
      else
        begin
          action_key.each do |action|
            @acts = action
            execute_sequence
          end
        rescue
          ErrorSound.play
          text = "Wrong [:loop] parameter!"
          msgbox text
          exit
        end
      end
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup 'while' mode loop [:while]
  # --------------------------------------------------------------------------
  def setup_while
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    cond = @acts[1]
    action_key = @acts[2]
    actions = TSBS::AnimLoop[action_key]
    if actions.nil?
      show_action_error(action_key)
    end
    begin
      while eval(cond)
        exe_act = actions.clone
        until exe_act.empty?
          @acts = exe_act.shift
          execute_sequence
        end
      end
    rescue StandardError => err
      display_error("[#{SEQUENCE_WHILE},]",err)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Force action [:forced,]
  # --------------------------------------------------------------------------
  def setup_force_act
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    act_key = @acts[1]
    target.forced_act = act_key
    target.force_change_battle_phase(:forced)
  end
  # --------------------------------------------------------------------------
  # New method : Setup Switch Case [:case,]
  # --------------------------------------------------------------------------
  def setup_switch_case
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    act_result = nil
    act_hash = @acts[1]
    
    # Get valid action key
    act_hash.each do |cond, action_key|
      bool = false
      begin
        # Try to evaluate script
        bool = eval(cond)
      rescue StandardError => err
        # Blame script user if error :v
        display_error("[#{SEQUENCE_CASE},]",err)
      end
      next unless bool # If condition valid
      act_result = action_key # Assign action key
      break # Break loop checking
    end
    
    # Evaluate action key
    return unless act_result
    is_array = act_result.is_a?(Array)
    
    # If nested array (triggered if first element is array)
    if is_array && act_result[0].is_a?(Array)
      act_result.each do |action|
        next unless action.is_a?(Array)
        @acts = action
        execute_sequence
      end
    # If normal array
    elsif is_array
      @acts = act_result
      execute_sequence
    else
      @acts = [:action, act_result]
      execute_sequence
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup Instant Reset [:instant_reset,]
  # --------------------------------------------------------------------------
  def setup_instant_reset
    reset_pos(1)  # Reset position
    update_move   # Update move as well
  end
  # --------------------------------------------------------------------------
  # New method : Setup change carried skill [:change_skill,]
  # --------------------------------------------------------------------------
  def setup_change_skill
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    skill = $data_skills[@acts[1]]
    return unless skill
    self.item_in_use = copy(skill)
  end
  # --------------------------------------------------------------------------
  # New method : Setup check collapse [:check_collapse,]
  # --------------------------------------------------------------------------
  def setup_check_collapse
    target_array.each do |tar|
      tar.target = self
      SceneManager.scene.check_collapse(tar)
    end
  end
  # --------------------------------------------------------------------------
  # New method : Setup check collapse [:slow_motion,]
  # --------------------------------------------------------------------------
  def setup_slow_motion
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    $game_temp.slowmotion_frame = @acts[1]
    $game_temp.slowmotion_rate = @acts[2]
  end
  # --------------------------------------------------------------------------
  # New method : Setup timestop [:timestop,]
  # --------------------------------------------------------------------------
  def setup_timestop
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    @acts[1].times { Graphics.update }
  end
  # --------------------------------------------------------------------------
  # New method : Setup Projectile Damage Scale [:proj_scale,]
  # --------------------------------------------------------------------------
  def setup_proj_scale
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    @proj_scale = @acts[1]
  end
  # --------------------------------------------------------------------------
  # New method : Setup common event [:com_event,]
  # --------------------------------------------------------------------------
  def setup_tsbs_common_event
    return TSBS.error(@acts[0], 1, @used_sequence) if @acts.size < 2
    @acts[1] = 0 unless @acts[1].is_a?(Numeric)
    $game_temp.tsbs_event = @acts[1]
    Fiber.yield
  end
  # --------------------------------------------------------------------------
  # New method : Setup graphics transition [:scr_trans,]
  # --------------------------------------------------------------------------
  def setup_transition
    return TSBS.error(@acts[0], 2, @used_sequence) if @acts.size < 3
    Fiber.yield
    name = "Graphics/Pictures/" + @acts[1]
    dur = @acts[2]
    vague = @acts[3] || 40
    Graphics.transition(dur, name, vague)
  end
  # --------------------------------------------------------------------------
  # New method : Method for wait [:wait,]
  # --------------------------------------------------------------------------
  def method_wait
    Fiber.yield
    @screen_z = screen_z_formula unless @lock_z
    update_timed_hit if @timed_hit_count > 0
  end
  # --------------------------------------------------------------------------
  # New method : Get next symbol (Outdated function in early ver. Not used)
  # --------------------------------------------------------------------------
  def next_is?(symbol)
    next_ary = animation_array[@anim_index + 2]
    return next_ary[0] == symbol
  end
  # --------------------------------------------------------------------------
  # New method : Forward sequence pointer
  # --------------------------------------------------------------------------
  def next_anim_index
    @anim_index = (@anim_index + 1) % (@animation_array.size - 1)
  end
  # --------------------------------------------------------------------------
  # New method : Update for timed hit
  # --------------------------------------------------------------------------
  def update_timed_hit
    if Input.trigger?(:C)
      @timed_hit = true
      @timed_hit_count = 1
      self.animation_id = TimedHit_Anim
      on_timed_hit_success
    end
    @timed_hit_count -= 1
  end
  # --------------------------------------------------------------------------
  # New method : On timed hit success ( I don't have any idea yet )
  # --------------------------------------------------------------------------
  def on_timed_hit_success
  end
  # --------------------------------------------------------------------------
  # New method : Determine if current phase is temporary phase
  # --------------------------------------------------------------------------
  def temporary_phase?
    Temporary_Phase.any? do |phase|
      battle_phase == phase
    end
  end
  # --------------------------------------------------------------------------
  # New method : Get animation sequence
  # --------------------------------------------------------------------------
  def get_animloop_array
    result = AnimLoop[phase_sequence[battle_phase].call]
    return result if result
    return rescued_error
  end
  # --------------------------------------------------------------------------
  # New method : Get current action
  # --------------------------------------------------------------------------
  def animloop
    animation_array[@anim_index + 1]
  end
  # --------------------------------------------------------------------------
  # New method : Loop?
  # --------------------------------------------------------------------------
  def loop?
    get_animloop_array[0][0]
  end
  # --------------------------------------------------------------------------
  # New method : Addons... if anyone is interested
  # --------------------------------------------------------------------------
  def custom_sequence_handler
    # For addon ...
  end
  # --------------------------------------------------------------------------
  # New method : User error handler
  # Because I don't want to be the one who is being blamed because if your
  # obvious fault
  # --------------------------------------------------------------------------
  def rescued_error
    ErrorSound.play
    id = data_battler.id
    seq_key = phase_sequence[battle_phase].call
    phase = (dead? ? :dead : battle_phase)
    klass = data_battler.class
    result = "Theolized SBS : \n"+
      "Error occured on #{klass} in ID #{id}\n" +
      "Undefined sequence key \"#{seq_key}\" for #{phase} phase\n\n" +
      "This is your fault. Not this script error!"
    msgbox result
    exit
  end
  # --------------------------------------------------------------------------
  # New method : Action call error handler
  # --------------------------------------------------------------------------
  def show_action_error(string)
    ErrorSound.play
    text = "Sequence key : #{phase_sequence[battle_phase].call}\n" + 
    "Uninitalized Constant for #{string} in :action mode"
    msgbox text
    exit
  end
  # --------------------------------------------------------------------------
  # New method : Determine if battler is busy
  # --------------------------------------------------------------------------
  def busy?
    BusyPhases.any? {|phase| battle_phase == phase }
  end
  # --------------------------------------------------------------------------
  # Alias method : Make base result (Basic Module - Core Result)
  # --------------------------------------------------------------------------
  alias tsbs_make_base_result make_base_result
  def make_base_result(user, item)
    tsbs_make_base_result(user, item)
    return unless data_battler.use_sprite
    return if user == self
    return if busy?
    if item.damage.recover? || item.damage.type == 0
      self.battle_phase = :idle 
      # Refresh idle key. In case if there is any state change or 
      # HP rate change
      return
    end
    self.battle_phase = :hurt if @result.hit?
    # Automatically switch to hurt phase
    if @result.evaded
      Sound.tsbs_play_eva
      self.battle_phase = :evade 
      # Automatically switch to evade phase
    end
  end
  # --------------------------------------------------------------------------
  # New method : Get state tone
  # --------------------------------------------------------------------------
  def state_tone
    result = nil
    states.each do |state|
      result = state.tone if state.tone
    end
    return result || EmptyTone
  end
  # --------------------------------------------------------------------------
  # New method : Get state color
  # --------------------------------------------------------------------------
  def state_color
    result = nil
    states.each do |state|
      result = state.color if state.color
    end
    return result || EmptyColor
  end
  # --------------------------------------------------------------------------
  # New method : Get animation guard
  # --------------------------------------------------------------------------
  def anim_guard_id
    states.each do |state|
      return state.anim_guard if state && state.anim_guard > 0
    end
    return 0
  end
  # --------------------------------------------------------------------------
  # New method : Get skills guard
  # --------------------------------------------------------------------------
  def skills_guard
    skill_guard = []
    states.each do |state|
      skill_guard.push(state.skill_guard) if state.skill_guard > 0
    end
    skill_guard.uniq.collect {|skill_id| $data_skills[skill_id]}
  end
  # --------------------------------------------------------------------------
  # New method : Get maximum opacity
  # --------------------------------------------------------------------------
  def max_opac
    unless states.empty?
      return states.collect do |state|
        state.max_opac
      end.min
    end
    return 255
  end
  # --------------------------------------------------------------------------
  # New method : State Animation
  # --------------------------------------------------------------------------
  def state_anim
    states.each do |state|
      return state.state_anim if state.state_anim > 0
    end
    return 0
  end
  # --------------------------------------------------------------------------
  # New method : Anim Behind?
  # --------------------------------------------------------------------------
  def anim_behind?
    states.each do |state|
      return state.anim_behind? if state.state_anim > 0
    end
    return false
  end  
  # --------------------------------------------------------------------------
  # New method : Screen Z
  # --------------------------------------------------------------------------
  def screen_z
    [@screen_z,3].max
  end
  # --------------------------------------------------------------------------
  # New method : Screen Z Formula
  # --------------------------------------------------------------------------
  def screen_z_formula
    return real_ypos + additional_z rescue 0
    # Real Y position (without jumping) + Additional Z value
  end
  # --------------------------------------------------------------------------
  # New method : Additional Z Formula
  # --------------------------------------------------------------------------
  def additional_z
    battle_phase == :idle || battle_phase == :hurt ?  0 : 1
    # Active battler displayed above another (increment by 1)
  end
  # --------------------------------------------------------------------------
  # Alias method : Add state
  # --------------------------------------------------------------------------
  alias tsbs_add_state add_state
  def add_state(state_id)
    tsbs_add_state(state_id)
    if battle_phase == :idle && @used_sequence != phase_sequence[:idle].call
      self.battle_phase = :idle
      # Refresh action key if changed
    end
    @refresh_opacity = true # Refrech max opacity
  end
  # --------------------------------------------------------------------------
  # Alias method : Remove state
  # --------------------------------------------------------------------------
  alias tsbs_rem_state remove_state
  def remove_state(state_id)
    tsbs_rem_state(state_id)
    if battle_phase == :idle && @used_sequence != phase_sequence[:idle].call
      self.battle_phase = :idle
      # Refresh action key if changed
    end
    @refresh_opacity = true # Refresh max opacity
  end
  # --------------------------------------------------------------------------
  # New method : State Sequence
  # --------------------------------------------------------------------------
  def state_sequence
    states.each do |state|
      return state.sequence unless state.sequence.empty?
    end
    return nil
  end
  # --------------------------------------------------------------------------
  # Alias method : On Turn End
  # --------------------------------------------------------------------------
  alias tsbs_turn_end on_turn_end
  def on_turn_end
    tsbs_turn_end
    if $game_party.in_battle
      reset_pos(10, 0)
      # Automatically reset position on turn end
      SceneManager.scene.check_collapse(self) 
      # Check collapse for self
    end
  end
  # --------------------------------------------------------------------------
  # Alias method : On Action End
  # --------------------------------------------------------------------------
  alias tsbs_action_end on_action_end
  def on_action_end
    tsbs_action_end
    if $game_party.in_battle
      SceneManager.scene.check_collapse(self) 
      # Check collapse for self
    end
  end
  # --------------------------------------------------------------------------
  # Alias method : Item Counterattack rate
  # --------------------------------------------------------------------------
  alias tsbs_counter item_cnt
  def item_cnt(user, item)
    return 0 if item.anti_counter? || user.battle_phase == :counter || dead? 
    tsbs_counter(user, item)
  end
  # --------------------------------------------------------------------------
  # Alias method : Item Reflection
  # --------------------------------------------------------------------------
  alias tsbs_reflect item_mrf
  def item_mrf(user, item)
    return 0 if item.anti_reflect? || user == self
    tsbs_reflect(user, item)
  end
  # --------------------------------------------------------------------------
  # Alias method : Item Evasion
  # --------------------------------------------------------------------------
  alias tsbs_eva item_eva
  def item_eva(user, item)
    return 0 if user.force_hit
    return 0 if item.always_hit?
    tsbs_eva(user, item)
  end
  # --------------------------------------------------------------------------
  # Alias method : Item Hit
  # --------------------------------------------------------------------------
  alias tsbs_hit item_hit
  def item_hit(user, item)
    return 1 if user.force_hit
    return 1 if item.always_hit?
    tsbs_hit(user, item)
  end
  # --------------------------------------------------------------------------
  # New method : Counter skill id
  # Stored in array for future use. In case if you want to make addon (or such)
  # For randomized counterattack skill
  # --------------------------------------------------------------------------
  def counter_skills_id
    [data_battler.counter_skill]
  end
  # --------------------------------------------------------------------------
  # New method : Counter skill
  # --------------------------------------------------------------------------
  def make_counter_skill
    skill_id = counter_skills_id[rand(counter_skills_id.size)]
    return $data_skills[skill_id]
  end
  # --------------------------------------------------------------------------
  # New method : State Transformation Name
  # --------------------------------------------------------------------------
  def state_trans_name
    states.each do |state|
      return state.trans_name unless state.trans_name.empty?
    end
    return ""
  end
  # --------------------------------------------------------------------------
  # New method : Target real range (pixel)
  # --------------------------------------------------------------------------
  def target_range
    return 9999 if target.nil?
    return 0 if area_flag
    rx = (self.x - target.x).abs
    ry = (self.y - target.y).abs
    return Math.sqrt((rx**2) + (ry**2))
  end
  # --------------------------------------------------------------------------
  # New method : Is event running?
  # --------------------------------------------------------------------------
  def event_running?
    SceneManager.scene.event_running?
  end
  # --------------------------------------------------------------------------
  # New method : Shadow position Y
  # --------------------------------------------------------------------------
  def shadow_y
    return screen_z - additional_z
  end
  
end