# encoding: utf8
# [127] 62258286: Classes Setup
#==============================================================================
# ** Game_Temp
#------------------------------------------------------------------------------
#  This class handles temporary data that is not included with save data.
# The instance of this class is referenced by $game_temp.
#==============================================================================

class Game_Temp
  # --------------------------------------------------------------------------
  # New public accessors
  # --------------------------------------------------------------------------
  attr_accessor :actors_fiber       # Store actor Fibers thread
  attr_accessor :enemies_fiber      # Store enemy Fibers thread
  attr_accessor :battler_targets    # Store current targets
  attr_accessor :anim_top           # Store anim top flag
  attr_accessor :global_freeze      # Global freeze flag (not tested)
  attr_accessor :anim_follow        # Store anim follow flag
  attr_accessor :slowmotion_frame   # Total frame for slowmotion
  attr_accessor :slowmotion_rate    # Framerate for slowmotion
  attr_accessor :one_animation_id   # One Animation ID Display
  attr_accessor :one_animation_flip # One Animation flip flag
  attr_accessor :one_animation_flag # One Animation assign flag
  attr_accessor :tsbs_event         # TSBS common event play
  # --------------------------------------------------------------------------
  # Alias method : Initialize
  # --------------------------------------------------------------------------
  alias tsbs_init initialize
  def initialize
    tsbs_init
    clear_tsbs
  end
  # --------------------------------------------------------------------------
  # New method : clear TSBS infos
  # --------------------------------------------------------------------------
  def clear_tsbs
    @actors_fiber = {}
    @enemies_fiber = {}
    @battler_targets = []
    @anim_top = 0
    @global_freeze = false
    @anim_follow = false
    @slowmotion_frame = 0
    @slowmotion_rate = 2
    @one_animation_id = 0
    @one_animation_flip = false
    @one_animation_flag = false
    @tsbs_event = 0
  end
  
end

#==============================================================================
# ** Game_Action
#------------------------------------------------------------------------------
#  This class handles battle actions. This class is used within the
# Game_Battler class.
#==============================================================================

class Game_Action
  # --------------------------------------------------------------------------
  # Alias method : targets for opponents
  # --------------------------------------------------------------------------
  alias tsbs_trg_for_opp targets_for_opponents
  def targets_for_opponents
    return abs_target if item.abs_target?
    return tsbs_trg_for_opp
  end
  # --------------------------------------------------------------------------
  # New method : Absolute target
  # --------------------------------------------------------------------------
  def abs_target
    opponents_unit.abs_target(item.number_of_targets)
  end
end

#==============================================================================
# ** Game_ActionResult
#------------------------------------------------------------------------------
#  This class handles the results of battle actions. It is used internally for
# the Game_Battler class. 
#==============================================================================

class Game_ActionResult
  attr_accessor :reflected  # Reflected flag. Purposely used for :if command
  # --------------------------------------------------------------------------
  # Alias method : Clear
  # --------------------------------------------------------------------------
  alias tsbs_clear clear
  def clear
    tsbs_clear
    @reflected = false
  end

end

#==============================================================================
# ** Game_Unit
#------------------------------------------------------------------------------
#  This class handles units. It's used as a superclass of the Game_Party and
# and Game_Troop classes.
#==============================================================================

class Game_Unit
  # --------------------------------------------------------------------------
  # New method : Make absolute target candidate
  # --------------------------------------------------------------------------
  def abs_target(number)
    candidate = alive_members.shuffle
    ary = []
    [number,candidate.size].min.times do 
      ary.push(candidate.shift) if !candidate[0].nil?
    end
    return ary
  end
  
end

