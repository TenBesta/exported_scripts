# encoding: utf8
# [34] 47174434: Game_Player
#==============================================================================
# ** Game_Player
#------------------------------------------------------------------------------
#  This class handles the player. It includes event starting determinants and
# map scrolling functions. The instance of this class is referenced by
# $game_player.
#==============================================================================

class Game_Player < Game_Character
  #--------------------------------------------------------------------------
  # * Public Instance Variables
  #--------------------------------------------------------------------------
  attr_reader   :followers                # Followers (party members)
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    super
    @vehicle_type = :walk           # Type of vehicle currently being ridden
    @vehicle_getting_on = false     # Boarding vehicle flag
    @vehicle_getting_off = false    # Getting off vehicle flag
    @transparent = $data_system.opt_transparent
    clear_transfer_info
  end
  #--------------------------------------------------------------------------
  # * Clear Transfer Player Information
  #--------------------------------------------------------------------------
  def clear_transfer_info
    @transferring = false           # Player transfer flag
    @new_map_id = 0                 # Destination map ID
    @new_x = 0                      # Destination X coordinate
    @new_y = 0                      # Destination Y coordinate
    @new_direction = 0              # Post-movement direction
  end
  #--------------------------------------------------------------------------
  # * Refresh
  #--------------------------------------------------------------------------
  def refresh
    @character_name = actor ? actor.character_name : ""
    @character_index = actor ? actor.character_index : 0
  end
  #--------------------------------------------------------------------------
  # * Get Corresponding Actor
  #--------------------------------------------------------------------------
  def actor
    $game_party.battle_members[0]
  end
  #--------------------------------------------------------------------------
  # * Determine if Stopping
  #--------------------------------------------------------------------------
  def stopping?
    return false if @vehicle_getting_on || @vehicle_getting_off
    return super
  end
  #--------------------------------------------------------------------------
  # * Player Transfer Reservation
  #     d:  Post move direction (2,4,6,8)
  #--------------------------------------------------------------------------
  def reserve_transfer(map_id, x, y, d = 2)
    @transferring = true
    @new_map_id = map_id
    @new_x = x
    @new_y = y
    @new_direction = d
  end
  #--------------------------------------------------------------------------
  # * Determine if Player Transfer is Reserved
  #--------------------------------------------------------------------------
  def transfer?
    @transferring
  end
  #--------------------------------------------------------------------------
  # * Execute Player Transfer
  #--------------------------------------------------------------------------
  def perform_transfer
    if transfer?
      set_direction(@new_direction)
      if @new_map_id != $game_map.map_id
        $game_map.setup(@new_map_id)
        $game_map.autoplay
      end
      moveto(@new_x, @new_y)
      clear_transfer_info
    end
  end
  #--------------------------------------------------------------------------
  # * Determine if Map is Passable
  #     d:  Direction (2,4,6,8)
  #--------------------------------------------------------------------------
  def map_passable?(x, y, d)
    super
 end
  
  #--------------------------------------------------------------------------
  # * Determine if Dashing
  #--------------------------------------------------------------------------
  def dash?
    return false if @move_route_forcing
    return false if $game_map.disable_dash?
    return Input.press?(:A)
  end
  #--------------------------------------------------------------------------
  # * Determine if Debug Pass-through State
  #--------------------------------------------------------------------------
  def debug_through?
    $TEST && Input.press?(:CTRL)
  end
  #--------------------------------------------------------------------------
  # * Detect Collision (Including Followers)
  #--------------------------------------------------------------------------
  def collide?(x, y)
    !@through && (pos?(x, y)) 
  end
  #--------------------------------------------------------------------------
  # * X Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_x
    (Graphics.width / 32 - 1) / 2.0
  end
  #--------------------------------------------------------------------------
  # * Y Coordinate of Screen Center
  #--------------------------------------------------------------------------
  def center_y
    (Graphics.height / 32 - 1) / 2.0
  end
  #--------------------------------------------------------------------------
  # * Set Map Display Position to Center of Screen
  #--------------------------------------------------------------------------
  def center(x, y)
    $game_map.set_display_pos(x - center_x, y - center_y)
  end
  #--------------------------------------------------------------------------
  # * Move to Designated Position
  #--------------------------------------------------------------------------
  def moveto(x, y)
    super
    center(x, y)
   
  

  end
  #--------------------------------------------------------------------------
  # * Increase Steps
  #--------------------------------------------------------------------------
  def increase_steps
    super
    $game_party.increase_steps 
  end
  
  #--------------------------------------------------------------------------
  # * Create Group ID for Troop Encountered
  #--------------------------------------------------------------------------
  def make_encounter_troop_id
    encounter_list = []
    weight_sum = 0
    $game_map.encounter_list.each do |encounter|
      next unless encounter_ok?(encounter)
      encounter_list.push(encounter)
      weight_sum += encounter.weight
    end
    if weight_sum > 0
      value = rand(weight_sum)
      encounter_list.each do |encounter|
        value -= encounter.weight
        return encounter.troop_id if value < 0
      end
    end
    return 0
  end
  #--------------------------------------------------------------------------
  # * Determine Usability of Encounter Item
  #--------------------------------------------------------------------------
  def encounter_ok?(encounter)
    return true if encounter.region_set.empty?
    return true if encounter.region_set.include?(region_id)
    return false
  end
  #--------------------------------------------------------------------------
  # * Execute Encounter Processing
  #--------------------------------------------------------------------------
  def encounter
    return false if $game_map.interpreter.running?
    troop_id = make_encounter_troop_id
    return false unless $data_troops[troop_id]
    BattleManager.setup(troop_id)
    BattleManager.on_encounter
    return true
  end
  #--------------------------------------------------------------------------
  # * Trigger Map Event
  #     triggers : Trigger array
  #     normal   : Is priority set to [Same as Characters] ?
  #--------------------------------------------------------------------------
  def start_map_event(x, y, triggers, normal)
    return if $game_map.interpreter.running?
    $game_map.events_xy(x, y).each do |event|
      if event.trigger_in?(triggers) && event.normal_priority? == normal
        event.start
      end
    end
  end
  #--------------------------------------------------------------------------
  # * Determine if Same Position Event is Triggered
  #--------------------------------------------------------------------------
  def check_event_trigger_here(triggers)
    start_map_event(@x, @y, triggers, false)
  end
  #--------------------------------------------------------------------------
  # * Determine if Front Event is Triggered
  #--------------------------------------------------------------------------
  def check_event_trigger_there(triggers)
    x2 = $game_map.round_x_with_direction(@x, @direction)
    y2 = $game_map.round_y_with_direction(@y, @direction)
    start_map_event(x2, y2, triggers, true)
    return if $game_map.any_event_starting?
    return unless $game_map.counter?(x2, y2)
    x3 = $game_map.round_x_with_direction(x2, @direction)
    y3 = $game_map.round_y_with_direction(y2, @direction)
    start_map_event(x3, y3, triggers, true)
  end
  #--------------------------------------------------------------------------
  # * Determine if Touch Event is Triggered
  #--------------------------------------------------------------------------
  def check_event_trigger_touch(x, y)
    start_map_event(x, y, [1,2], true)
  end
  #--------------------------------------------------------------------------
  # * Processing of Movement via Input from Directional Buttons
  #--------------------------------------------------------------------------
  def move_by_input
    return if !movable? || $game_map.interpreter.running?
    move_straight(Input.dir4) if Input.dir4 > 0
  end
  #--------------------------------------------------------------------------
  # * Determine if Movement is Possible
  #--------------------------------------------------------------------------
  def movable?
    return false if moving?
    return false if @move_route_forcing 
    return false if $game_message.busy? || $game_message.visible
    return true
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    last_real_x = @real_x
    last_real_y = @real_y
    last_moving = moving?
    move_by_input
    super
    update_scroll(last_real_x, last_real_y)
    update_nonmoving(last_moving) unless moving?
  
  end
  #--------------------------------------------------------------------------
  # * Scroll Processing
  #--------------------------------------------------------------------------
  def update_scroll(last_real_x, last_real_y)
    ax1 = $game_map.adjust_x(last_real_x)
    ay1 = $game_map.adjust_y(last_real_y)
    ax2 = $game_map.adjust_x(@real_x)
    ay2 = $game_map.adjust_y(@real_y)
    $game_map.scroll_down (ay2 - ay1) if ay2 > ay1 && ay2 > center_y
    $game_map.scroll_left (ax1 - ax2) if ax2 < ax1 && ax2 < center_x
    $game_map.scroll_right(ax2 - ax1) if ax2 > ax1 && ax2 > center_x
    $game_map.scroll_up   (ay1 - ay2) if ay2 < ay1 && ay2 < center_y
  end
 
  #--------------------------------------------------------------------------
  # * Processing When Not Moving
  #     last_moving : Was it moving previously?
  #--------------------------------------------------------------------------
  def update_nonmoving(last_moving)
    return if $game_map.interpreter.running?
    if last_moving
      $game_party.on_player_walk
      return if check_touch_event
    end
    if movable? && Input.trigger?(:C)
    return if check_action_event
    end
  end
 
  
  #--------------------------------------------------------------------------
  # * Determine if Event Start Caused by Touch (Overlap)
  #--------------------------------------------------------------------------
  def check_touch_event
      check_event_trigger_here([1,2])
    $game_map.setup_starting_event
  end
  #--------------------------------------------------------------------------
  # * Determine if Event Start Caused by [OK] Button
  #--------------------------------------------------------------------------
  def check_action_event
    
    return true if $game_map.setup_starting_event
    check_event_trigger_there([0,1,2])
    $game_map.setup_starting_event
  end
 
  #--------------------------------------------------------------------------
  # * Force One Step Forward
  #--------------------------------------------------------------------------
  def force_move_forward
    @through = true
    move_forward
    @through = false
  end
  #--------------------------------------------------------------------------
  # * Determine if Damage Floor
  #--------------------------------------------------------------------------
  def on_damage_floor?
    $game_map.damage_floor?(@x, @y) && !in_airship?
  end
  #--------------------------------------------------------------------------
  # * Move Straight
  #--------------------------------------------------------------------------
  def move_straight(d, turn_ok = true)
   
    super
  end
 
end
