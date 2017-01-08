# encoding: utf8
# [126] 19461567: Classes Miscellaneous



#==============================================================================
# ** Sound
#------------------------------------------------------------------------------
#  This module plays sound effects. It obtains sound effects specified in the
# database from the global variable $data_system, and plays them.
#==============================================================================

class << Sound
  
  # Delete play evasion. Because I don't want to overwrite Window_BattleLog
  alias tsbs_play_eva play_evasion
  def play_evasion
  end
  
  # Delete play evasion. Because I don't want to overwrite perform collapse
  alias tsbs_play_enemycollapse play_enemy_collapse
  def play_enemy_collapse
  end
  
end

#==============================================================================
# ** DataManager
#------------------------------------------------------------------------------
#  This module manages the database and game objects. Almost all of the 
# global variables used by the game are initialized by this module.
#==============================================================================

class << DataManager
  # --------------------------------------------------------------------------
  # Alias method : load database
  # --------------------------------------------------------------------------
  alias theo_tsbs_load_db load_database
  def load_database
    theo_tsbs_load_db
    load_tsbs
  end
  # --------------------------------------------------------------------------
  # New Method : Load TSBS caches
  # --------------------------------------------------------------------------
  def load_tsbs
    ($data_skills + $data_items + $data_states + $data_classes + 
      $data_weapons + $data_actors + $data_enemies).compact.each do |item|
      item.load_tsbs
    end
  end  
end

#==============================================================================
# ** BattleManager
#------------------------------------------------------------------------------
#  This module manages battle progress.
#==============================================================================

class << BattleManager
  # --------------------------------------------------------------------------
  # Alias method : Battle Start
  # --------------------------------------------------------------------------
  alias tsbs_battle_start battle_start
  def battle_start
    tsbs_battle_start
    if ($imported["YEA-BattleEngine"] && !YEA::BATTLE::MSG_ENEMY_APPEARS) ||
        !$game_message.busy?
      swindow = SceneManager.scene.instance_variable_get("@status_window")
      if swindow 
        swindow.open 
        swindow.refresh
      end
      # Open status window if encounter message is disabled
    end
    SceneManager.scene.wait_for_sequence 
    # wait for intro sequence
  end
  # --------------------------------------------------------------------------
  # Alias method : process victory
  # --------------------------------------------------------------------------
  alias tsbs_process_victory process_victory
  def process_victory
    $game_party.alive_members.each do |member|
      member.battle_phase = :victory unless member.victory.empty?
    end
    tsbs_process_victory
  end
  # ---------------------------------------------------------------------------
  # Overwrite method : process escape
  # ---------------------------------------------------------------------------
  def process_escape
    $game_message.add(sprintf(Vocab::EscapeStart, $game_party.name))
    success = @preemptive ? true : (rand < @escape_ratio)
    Sound.play_escape
    if success
      process_abort
      $game_party.alive_members.each do |member|
        member.battle_phase = :escape
      end
    else
      @escape_ratio += 0.1
      $game_message.add('\.' + Vocab::EscapeFailure)
      $game_party.clear_actions
    end
    wait_for_message
    return success
  end
  # --------------------------------------------------------------------------
  # Alias method : Judge win loss
  # It seems if I don't add these lines. Enemy battler won't collapse when
  # K.O by slip damage
  # --------------------------------------------------------------------------
  alias tsbs_judge_win_loss judge_win_loss
  def judge_win_loss
    if SceneManager.scene_is?(Scene_Battle)
      SceneManager.scene.all_battle_members.each do |member|
        SceneManager.scene.check_collapse(member)
      end
      SceneManager.scene.wait_for_sequence 
    end
    tsbs_judge_win_loss
  end
  
end

#==============================================================================
# ** RPG::Class
#------------------------------------------------------------------------------
#  This class handles database for classes
#==============================================================================

class RPG::Class < RPG::BaseItem
  attr_accessor :attack_id
  attr_accessor :guard_id
  
  def load_tsbs
    @attack_id = 0
    @guard_id = 0
    self.note.split(/[\r\n]+/).each do |line|
      case line
      when TSBS::DefaultATK
        @attack_id = $1.to_i
      when TSBS::DefaultDEF
        @guard_id = $1.to_i
      end
    end
  end
end

#==============================================================================
# ** RPG::Weapon
#------------------------------------------------------------------------------
#  This class handles database for weapons
#==============================================================================

class RPG::Weapon < RPG::EquipItem
  attr_accessor :attack_id
  attr_accessor :guard_id
  
  def load_tsbs
    @attack_id = 0
    @guard_id = 0
    self.note.split(/[\r\n]+/).each do |line|
      case line
      when TSBS::DefaultATK
        @attack_id = $1.to_i
      when TSBS::DefaultDEF
        @guard_id = $1.to_i\
      end
    end
  end
  
end

#==============================================================================
# ** RPG::State
#------------------------------------------------------------------------------
#  This class handles database for states
#==============================================================================

class RPG::State < RPG::BaseItem
  # --------------------------------------------------------------------------
  # New public accessors
  # --------------------------------------------------------------------------
  attr_accessor :tone           # State Tone
  attr_accessor :color          # State Color
  attr_accessor :anim_guard     # Animation Guard
  attr_accessor :skill_guard    # Skill Guard
  attr_accessor :max_opac       # Max Opacity
  attr_accessor :sequence       # State sequence
  attr_accessor :state_anim     # State animation
  attr_accessor :trans_name     # Transform Name
  attr_accessor :attack_id      # Default attack
  attr_accessor :guard_id       # Default guard
  # --------------------------------------------------------------------------
  # New method : load TSBS notetags
  # --------------------------------------------------------------------------
  def load_tsbs
    @anim_guard = 0
    @skill_guard = 0
    @max_opac = 255
    @sequence = ""
    @state_anim = 0
    @trans_name = ""
    @color = nil
    @attack_id = 0
    @guard_id = 0
    note.split(/[\r\n]+/).each do |line|
      case line
      when TSBS::ToneREGX
        @tone = Tone.new
        @tone.red = $2.to_i * ($1.to_s == "-" ? -1 : 1)
        @tone.green = $4.to_i * ($3.to_s == "-" ? -1 : 1)
        @tone.blue = $6.to_i * ($5.to_s == "-" ? -1 : 1)
        @tone.gray = $8.to_i * ($7.to_s == "-" ? -1 : 1)
      when TSBS::ColorREGX
        @color = Color.new
        @color.red = $2.to_i * ($1.to_s == "-" ? -1 : 1)
        @color.green = $4.to_i * ($3.to_s == "-" ? -1 : 1)
        @color.blue = $6.to_i * ($5.to_s == "-" ? -1 : 1)
        @color.alpha = $8.to_i * ($7.to_s == "-" ? -1 : 1)
      when TSBS::AnimGuard
        @anim_guard = $1.to_i
      when TSBS::SkillGuard
        @skill_guard = $1.to_i
      when TSBS::StateOpacity
        @max_opac = $1.to_i
      when TSBS::SequenceREGX
        @sequence = $1.to_s
      when TSBS::StateAnim
        @state_anim = $1.to_i
      when TSBS::Transform
        @trans_name = $1.to_s
      when TSBS::DefaultATK
        @attack_id = $1.to_i
      when TSBS::DefaultDEF
        @guard_id = $1.to_i
      end
    end
  end
  # --------------------------------------------------------------------------
  # New method : Anim Behind?
  # --------------------------------------------------------------------------
  def anim_behind?
    !note[TSBS::AnimBehind].nil?
  end
  
end

#==============================================================================
# ** RPG::UsableItem
#------------------------------------------------------------------------------
#  This class handles database for skills and items
#==============================================================================

class RPG::UsableItem < RPG::BaseItem
  # --------------------------------------------------------------------------
  # New public accessors
  # --------------------------------------------------------------------------
  attr_accessor :seq_key        # Sequence keys
  attr_accessor :prepare_key    # Preparation keys
  attr_accessor :return_key     # Return key sequence
  attr_accessor :reflect_anim   # Reflect animations
  # --------------------------------------------------------------------------
  # New method : load TSBS notetags
  # --------------------------------------------------------------------------
  def load_tsbs
    @seq_key = TSBS::Default_SkillSequence
    @seq_key = TSBS::Default_ItemSequence if is_a?(RPG::Item)
    @prepare_key = ""
    @return_key = ""
    @reflect_anim = animation_id
    first_time = true
    note.split(/[\r\n]+/).each do |line|
      case line 
      when TSBS::SequenceREGX
        if first_time
          @seq_key = [$1.to_s]
          first_time = false
        else
          @seq_key.push($1.to_s)
        end
      when TSBS::PrepareREGX
        @prepare_key = $1.to_s
      when TSBS::ReturnREGX
        @return_key = $1.to_s
      when TSBS::ReflectAnim
        @reflect_anim = $1.to_i
      end
    end
  end
  # --------------------------------------------------------------------------
  # New method : Determine if item / skill is area attack
  # --------------------------------------------------------------------------
  def area?
    !note[TSBS::AreaTAG].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if item / skill doesn't require subject to return
  # --------------------------------------------------------------------------
  def no_return?
    !note[TSBS::NoReturnTAG].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if item / skill has absolute target
  # --------------------------------------------------------------------------
  def abs_target?
    !note[TSBS::AbsoluteTarget].nil? && for_random?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill is ignoring skill guard effect
  # --------------------------------------------------------------------------
  def ignore_skill_guard?
    !note[TSBS::IgnoreSkillGuard].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill is ignoring anim guard effect
  # --------------------------------------------------------------------------
  def ignore_anim_guard?
    !note[TSBS::IgnoreAnimGuard].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill anti counter attack
  # --------------------------------------------------------------------------
  def anti_counter?
    !note[TSBS::AntiCounter].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill is anti magic reflection
  # --------------------------------------------------------------------------
  def anti_reflect?
    !note[TSBS::AntiReflect].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill is always hit
  # --------------------------------------------------------------------------
  def always_hit?
    !note[TSBS::AlwaysHit].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill is plays parallel animation
  # --------------------------------------------------------------------------
  def parallel_anim?
    !note[TSBS::ParallelTAG].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill is randomly select target during magic
  # reflection
  # --------------------------------------------------------------------------
  def random_reflect?
    !note[TSBS::RandomReflect].nil?
  end
  # --------------------------------------------------------------------------
  # New method : Determine if skill has one animation flag
  # --------------------------------------------------------------------------
  unless $imported["YEA-BattleEngine"]
  def one_animation
    !note[TSBS::OneAnimation].nil?
  end
  end
end

#==============================================================================
# ** RPG::Actor
#------------------------------------------------------------------------------
#  This class handles actors database
#==============================================================================

class RPG::Actor < RPG::BaseItem
  # --------------------------------------------------------------------------
  # New public accessors
  # --------------------------------------------------------------------------
  attr_accessor :idle_key       # Idle key sequence
  attr_accessor :critical_key   # Critical key sequence
  attr_accessor :evade_key      # Evade key sequence
  attr_accessor :hurt_key       # Hurt key sequence
  attr_accessor :return_key     # Return key sequence
  attr_accessor :dead_key       # Dead key sequence
  attr_accessor :escape_key     # Escape key sequence
  attr_accessor :victory_key    # Victory key sequence
  attr_accessor :intro_key      # Intro key sequence
  attr_accessor :counter_key    # Counterattack key sequence
  attr_accessor :collapse_key   # Collapse key sequence
  attr_accessor :battler_name   # Battler name
  attr_accessor :counter_skill  # Counterattack skill ID
  attr_accessor :use_sprite     # Use sprite flag (always true)
  attr_accessor :reflect_anim   # Reflect animation
  attr_accessor :attack_id      # Attack skill ID
  attr_accessor :guard_id       # Guard skill ID
  attr_accessor :no_shadow      # No shadow flag
  # --------------------------------------------------------------------------
  # New method : load TSBS notetags
  # --------------------------------------------------------------------------
  def load_tsbs
    @idle_key = TSBS::Default_Idle
    @critical_key = TSBS::Default_Critical
    @evade_key = TSBS::Default_Evade
    @hurt_key = TSBS::Default_Hurt
    @return_key = TSBS::Default_Return
    @dead_key = TSBS::Default_Dead
    @escape_key = TSBS::Default_Escape
    @victory_key = TSBS::Default_Victory
    @intro_key = TSBS::Default_Intro
    @counter_key = TSBS::Default_ACounter
    @collapse_key = ""
    @battler_name = @name.clone
    @counter_skill = 1
    @reflect_anim = TSBS::Reflect_Guard
    @use_sprite = true
    @attack_id = 0
    @guard_id = 0
    @no_shadow = false
    load_sbs = false
    note.split(/[\r\n]+/).each do |line|
      # -- Non TSBS sideview tag ---
      case line
      when TSBS::DefaultATK
        @attack_id = $1.to_i
      when TSBS::DefaultDEF
        @guard_id = $1.to_i
      when TSBS::ReflectAnim
        @reflect_anim = $1.to_i
      when TSBS::CounterSkillID
        @counter_skill = $1.to_i
      when TSBS::NoShadowTAG
        @no_shadow = true 
      end
      # -- TSBS sideview tag ---
      if line =~ TSBS::SBS_Start
        load_sbs = true
      elsif line =~ TSBS::SBS_Start_S
        load_sbs = true
        @battler_name = $1.to_s
      elsif line =~ TSBS::SBS_End
        load_sbs = false
      end
      # -- End ---
      next unless load_sbs
      case line
      when TSBS::SBS_Idle
        @idle_key = $1.to_s
      when TSBS::SBS_Critical
        @critical_key = $1.to_s
      when TSBS::SBS_Evade
        @evade_key = $1.to_s
      when TSBS::SBS_Hurt
        @hurt_key = $1.to_s
      when TSBS::SBS_Return
        @return_key = $1.to_s
      when TSBS::SBS_Dead
        @dead_key = $1.to_s
      when TSBS::SBS_Escape
        @escape_key = $1.to_s
      when TSBS::SBS_Win
        @victory_key = $1.to_s
      when TSBS::SBS_Intro
        @intro_key = $1.to_s
      when TSBS::SBS_Counter
        @counter_key = $1.to_s
      when TSBS::SBS_Collapse
        @collapse_key = $1.to_s
      end
    end
  end
end

#==============================================================================
# ** RPG::Enemy
#------------------------------------------------------------------------------
#  This class handles enemies database
#==============================================================================

class RPG::Enemy < RPG::BaseItem
  # --------------------------------------------------------------------------
  # New public accessors
  # --------------------------------------------------------------------------
  attr_accessor :idle_key       # Idle key sequence
  attr_accessor :critical_key   # Critical key sequence
  attr_accessor :evade_key      # Evade key sequence
  attr_accessor :hurt_key       # Hurt key sequence
  attr_accessor :return_key     # Return key sequence
  attr_accessor :dead_key       # Dead key sequence
  attr_accessor :intro_key      # Intro key sequence
  attr_accessor :counter_key    # Counterattack key sequence
  attr_accessor :collapse_key   # Collapse key sequence
  attr_accessor :use_sprite     # Use sprite flag (true/false)
  attr_accessor :sprite_name    # Sprite name
  attr_accessor :counter_skill  # Counter skill ID
  attr_accessor :reflect_anim   # Reflect animation
  attr_accessor :no_shadow      # No shadow flag
  attr_accessor :collapsound    # Collapse sound effect
  # --------------------------------------------------------------------------
  # New method : load TSBS notetags
  # --------------------------------------------------------------------------
  def load_tsbs
    @idle_key = TSBS::Default_Idle
    @critical_key = TSBS::Default_Critical
    @evade_key = TSBS::Default_Evade
    @hurt_key = TSBS::Default_Hurt
    @return_key = TSBS::Default_Return
    @dead_key = TSBS::Default_Dead
    @intro_key = TSBS::Default_Intro
    @reflect_anim = TSBS::Reflect_Guard
    @counter_key = TSBS::Default_ECounter
    @collapse_key = ""
    @sprite_name = ""
    @counter_skill = 1
    @use_sprite = false
    @no_shadow = false
    @collapsound = $data_system.sounds[11]
    load_sbs = false
    note.split(/[\r\n]+/).each do |line|
      case line
      when TSBS::NoShadowTAG
        @no_shadow = true 
      when TSBS::SBS_Start_S
        load_sbs = true
        @use_sprite = true
        @sprite_name = $1.to_s
      when TSBS::SBS_Start
        load_sbs = true
      when TSBS::SBS_End
        load_sbs = false
      when TSBS::ReflectAnim
        @reflect_anim = $1.to_i
      when TSBS::CounterSkillID
        @counter_skill = $1.to_i
      when TSBS::CollapSound
        @collapsound = RPG::SE.new($1.to_s,$2.to_i,$3.to_i)
      end
      next unless load_sbs
      case line
      when TSBS::SBS_Idle
        @idle_key = $1.to_s
      when TSBS::SBS_Critical
        @critical_key = $1.to_s
      when TSBS::SBS_Evade
        @evade_key = $1.to_s
      when TSBS::SBS_Hurt
        @hurt_key = $1.to_s
      when TSBS::SBS_Return
        @return_key = $1.to_s
      when TSBS::SBS_Dead
        @dead_key = $1.to_s
      when TSBS::SBS_Intro
        @intro_key = $1.to_s
      when TSBS::SBS_Counter
        @counter_key = $1.to_s
      when TSBS::SBS_Collapse
        @collapse_key = $1.to_s
      end
    end
  end
  
end