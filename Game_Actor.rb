# encoding: utf8
# [129] 7221577: Game_Actor

#==============================================================================
# ** Game_Actor
#------------------------------------------------------------------------------
#  This class handles actors. It is used within the Game_Actors class
# ($game_actors) and is also referenced from the Game_Party class ($game_party)
#==============================================================================

class Game_Actor < Game_Battler
  # --------------------------------------------------------------------------
  # Public instance variables. Compatibility with Basic Movement
  # --------------------------------------------------------------------------
  attr_accessor :x
  attr_accessor :y
  # --------------------------------------------------------------------------
  # Alias method : setup
  # --------------------------------------------------------------------------
  alias theo_tsbs_actor_setup setup
  def setup(id)
    self.x = 0
    self.y = 0
    theo_tsbs_actor_setup(id)
    @battler_name = data_battler.battler_name
  end
  # --------------------------------------------------------------------------
  # New Method : Clear TSBS
  # --------------------------------------------------------------------------
  def clear_tsbs
    super
    @ori_x = 0
    @ori_y = 0
  end
  # --------------------------------------------------------------------------
  # Overwrite method : Fiber object thread
  # --------------------------------------------------------------------------
  def fiber_obj
    $game_temp.actors_fiber[id]
  end
  # --------------------------------------------------------------------------
  # Alias method : On Battle Start
  # --------------------------------------------------------------------------
  alias tsbs_on_bs_start on_battle_start
  def on_battle_start
    self.x = @ori_x
    self.y = @ori_y
    if data_battler.intro_key.empty?
      reset_pos(1) 
      update_move
    end
    tsbs_on_bs_start
  end
  # --------------------------------------------------------------------------
  # New method : Original X position
  # --------------------------------------------------------------------------
  def original_x
    ActorPos[index][0] || 0 rescue 0
  end
  # --------------------------------------------------------------------------
  # New method : Original Y position
  # --------------------------------------------------------------------------
  def original_y
    ActorPos[index][1] || 0 rescue 0
  end
  # --------------------------------------------------------------------------
  # New method : Screen X
  # Define sprite reposition formula here. Such as camera
  # Do not ever change the :x
  # --------------------------------------------------------------------------
  def screen_x
    return x
  end
  # --------------------------------------------------------------------------
  # New method : Screen Y
  # Define sprite reposition formula here. Such as camera
  # Do not ever change the :y
  # --------------------------------------------------------------------------
  def screen_y
    return y
  end
  # --------------------------------------------------------------------------
  # New method : Screen Z
  # --------------------------------------------------------------------------
  def screen_z
    super
  end
  # --------------------------------------------------------------------------
  # Overwrite method : use sprite
  # --------------------------------------------------------------------------
  def use_sprite?
    return true
  end
  # --------------------------------------------------------------------------
  # New method : Actor's battler name
  # Base Name + State Name + _index 
  # --------------------------------------------------------------------------
  def battler_name
    return "#{@battler_name+state_trans_name}_#{battler_index}"
  end
  # --------------------------------------------------------------------------
  # New method : Actor's Hue
  # --------------------------------------------------------------------------
  def battler_hue
    return 0
  end
  # --------------------------------------------------------------------------
  # New method : Data Battler
  # --------------------------------------------------------------------------
  def data_battler
    actor
  end
  # --------------------------------------------------------------------------
  # Overwrite method : Remove perform damage effect
  # --------------------------------------------------------------------------
  def perform_damage_effect
  end
  # --------------------------------------------------------------------------
  # Overwrite method : Remove perform collapse effect
  # --------------------------------------------------------------------------
  alias tsbs_perform_collapse_effect perform_collapse_effect
  def perform_collapse_effect
    if !collapse_key.empty?
      self.battle_phase = :collapse
    end
  end
  # --------------------------------------------------------------------------
  # New method : init oripost
  # --------------------------------------------------------------------------
  def init_oripost
    @ori_x = original_x
    @ori_y = original_y
  end
  # --------------------------------------------------------------------------
  # Alias method : Attack skill ID
  # --------------------------------------------------------------------------
  alias tsbs_atk_id attack_skill_id
  def attack_skill_id
    return sort_states.find {|state| $data_states[state].attack_id > 0} if 
      sort_states.any?{ |state| $data_states[state].attack_id > 0}
    return weapons[0].attack_id if weapons[0] ? weapons[0].attack_id > 0 : 
      false
    return $data_classes[class_id].attack_id if 
      $data_classes[class_id].attack_id > 0
    return $data_actors[id].attack_id if $data_actors[id].attack_id > 0
    return tsbs_atk_id
  end
  # --------------------------------------------------------------------------
  # Alias method : Guard skill ID
  # --------------------------------------------------------------------------
  alias tsbs_grd_id guard_skill_id
  def guard_skill_id
    return sort_states.find {|state| $data_states[state].guard_id > 0} if 
       sort_states.any? { |state| $data_states[state].guard_id > 0}
    return $data_classes[class_id].guard_id if 
    $data_classes[class_id].guard_id > 0
    return $data_actors[id].guard_id if $data_actors[id].guard_id > 0
    return tsbs_grd_id
  end
  
end

#==============================================================================
# ** Game_Enemy
#------------------------------------------------------------------------------
#  This class handles enemies. It used within the Game_Troop class 
# ($game_troop) and is a subclass of game battler
#==============================================================================

class Game_Enemy < Game_Battler
  attr_reader :collapsed
  # --------------------------------------------------------------------------
  # Alias methods : Compatibility with Basic Movement
  # --------------------------------------------------------------------------
  alias x screen_x
  alias y screen_y
  # --------------------------------------------------------------------------
  # Alias method : Initialize
  # --------------------------------------------------------------------------
  alias tsbs_enemy_init initialize
  def initialize(index, enemy_id)
    tsbs_enemy_init(index, enemy_id)
    @screen_z = ($game_troop.troop.members[index].y rescue 0)
    @flip = default_flip
  end
  # --------------------------------------------------------------------------
  # Alias method : On Battle Start
  # --------------------------------------------------------------------------
  alias tsbs_on_bs_start on_battle_start
  def on_battle_start
    tsbs_on_bs_start
    @ori_x = x
    @ori_y = y
    return unless data_battler.use_sprite
    @anim_index = rand(get_animloop_array.size - 1) rescue rescued_error
    @collapsed = false
  end
  # --------------------------------------------------------------------------
  # Overwrite method : Fiber object thread
  # --------------------------------------------------------------------------
  def fiber_obj
    $game_temp.enemies_fiber[index]
  end
  # --------------------------------------------------------------------------
  # New method : Set X Position
  # --------------------------------------------------------------------------
  def x=(x)
    @screen_x = x
  end
  # --------------------------------------------------------------------------
  # New method : Set Y Position
  # --------------------------------------------------------------------------
  def y=(y)
    @screen_y = y
  end
  # --------------------------------------------------------------------------
  # New method : Data Battler
  # --------------------------------------------------------------------------
  def data_battler
    enemy
  end
  # --------------------------------------------------------------------------
  # Alias method : Battler Name
  # --------------------------------------------------------------------------
  alias tsbs_ename battler_name
  def battler_name
    return "#{data_battler.sprite_name + state_trans_name}_#{battler_index}" if
      data_battler.use_sprite
    return tsbs_ename + state_trans_name
  end
  # --------------------------------------------------------------------------
  # Overwrite method : Screen Z
  # --------------------------------------------------------------------------
  def screen_z
    super
  end
  # --------------------------------------------------------------------------
  # New method : Default flip
  # --------------------------------------------------------------------------
  def default_flip
    result = TSBS::Enemy_Default_Flip
    toggler = (!data_battler.note[DefaultFlip].nil? rescue result)
    result = !result if toggler != result
    return result
  end
  # --------------------------------------------------------------------------
  # Overwrite method : Delete perform damage effect
  # --------------------------------------------------------------------------
  def perform_damage_effect
  end  
  # --------------------------------------------------------------------------
  # Alias method : Perform Collapse effect.
  # --------------------------------------------------------------------------
  alias tsbs_perform_collapse_effect perform_collapse_effect
  def perform_collapse_effect
    return if @collapsed
    if !collapse_key.empty?
      self.battle_phase = :collapse
    else
      tsbs_perform_collapse_effect
    end
    @collapsed = true
  end
  
  alias tsbs_collapsound_effect tsbs_perform_collapse_effect
  def tsbs_perform_collapse_effect
    tsbs_collapsound_effect
    data_battler.collapsound.play
  end
  
end
