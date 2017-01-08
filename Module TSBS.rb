# encoding: utf8
# [124] 90262378: Module TSBS
# =============================================================================
# Theolized Sideview Battle System (TSBS)
# Version : 1.3c
# Language : English
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Contact :
#------------------------------------------------------------------------------
# *> http://www.rpgmakerid.com
# *> http://www.rpgmakervxace.net
# *> http://theolized.blogspot.com
# =============================================================================
# Last updated : 2014.09.08
# -----------------------------------------------------------------------------
# Requires : Theo - Basic Modules v1.5b
# >> Basic Functions 
# >> Movement
# >> Core Result
# >> Core Fade
# >> Clone Image
# >> Rotate Image
# >> Smooth Movement
# -----------------------------------------------------------------------------
# This section is mainly aimed for scripters. There's nothing to do unless
# you know what you're doing. I told ya. It's for your own good 
# =============================================================================
($imported ||= {})[:TSBS] = true  # <-- don't edit this line ~
module TSBS
  # --------------------------------------------------------------------------
  # Constants
  # --------------------------------------------------------------------------
  
  BusyPhases = [:intro, :skill, :prepare, :collapse, :forced, :return]
  # Phase that considered as busy and wait for finish. Do not change!
  
  Temporary_Phase = [:hurt, :evade, :return, :intro, :counter, :collapse]
  # Phase that will be replaced by :idle when finished. Do not change!
  
  EmptyTone = Tone.new(0,0,0,0)
  # Tone that replace the battler tone if battler has no state tone
  # Do not change!
  
  EmptyColor = Color.new(0,0,0,0)
  # Color that replace the battler color blend if battler has no state color
  # Do not change!

  # ---------------------------------------------------------------------------
  # Sequence Constants. Want to simplify the command symbols? edit this section
  # ---------------------------------------------------------------------------
  
  # Initial Release v1.0
  SEQUENCE_POSE             = :pose           # set pose
  SEQUENCE_MOVE             = :move           # trigger move     
  SEQUENCE_SLIDE            = :slide          # trigger slide
  SEQUENCE_RESET            = :goto_oripost   # trigger back to original post
  SEQUENCE_MOVE_TO_TARGET   = :move_to_target # trigger move to target
  SEQUENCE_SCRIPT           = :script         # call script function
  SEQUENCE_WAIT             = :wait           # wait for x frames
  SEQUENCE_DAMAGE           = :target_damage  # Apply skill/item to target
  SEQUENCE_SHOW_ANIMATION   = :show_anim      # Show animation on target
  SEQUENCE_CAST             = :cast           # Show animation on self
  SEQUENCE_VISIBLE          = :visible        # Toggle visibility
  SEQUENCE_AFTERIMAGE       = :afterimage     # Toggle afterimage effect
  SEQUENCE_FLIP             = :flip           # Toggle flip / mirror sprite
  SEQUENCE_ACTION           = :action         # Call predefined action
  SEQUENCE_PROJECTILE       = :projectile     # Show projectile
  SEQUENCE_PROJECTILE_SETUP = :proj_setup     # Setup projectile
  SEQUENCE_USER_DAMAGE      = :user_damage    # User damage
  SEQUENCE_LOCK_Z           = :lock_z         # Lock shadow (and Z)
  SEQUENCE_ICON             = :icon           # Show icon
  SEQUENCE_SOUND            = :sound          # Play SE
  SEQUENCE_IF               = :if             # Set Branched condition
  SEQUENCE_TIMED_HIT        = :timed_hit      # Trigger timed hit function
  SEQUENCE_SCREEN           = :screen         # Setup screen
  SEQUENCE_ADD_STATE        = :add_state      # Add state
  SEQUENCE_REM_STATE        = :rem_state      # Remove state
  SEQUENCE_CHANGE_TARGET    = :change_target  # Change current target
  SEQUENCE_SHOW_PICTURE     = :show_pic       # Show picture
  SEQUENCE_TARGET_MOVE      = :target_move    # Force move target
  SEQUENCE_TARGET_SLIDE     = :target_slide   # Force slide target
  SEQUENCE_TARGET_RESET     = :target_reset   # Force target to return
  SEQUENCE_BLEND            = :blend          # Setup battler blending
  SEQUENCE_FOCUS            = :focus          # Setup focus effect
  SEQUENCE_UNFOCUS          = :unfocus        # Remove focus effect
  SEQUENCE_TARGET_LOCK_Z    = :target_lock_z  # Lock target shadow (and Z)
  # -------------------------------------------
  # Update v1.1
  # -------------------------------------------
  SEQUENCE_ANIMTOP          = :anim_top     # Flag animation in always on top    
  SEQUENCE_FREEZE           = :freeze       # Freeze the screen (not tested)    
  SEQUENCE_CSTART           = :cutin_start  # Start cutin graphic)
  SEQUENCE_CFADE            = :cutin_fade   # Fade cutin graphic
  SEQUENCE_CMOVE            = :cutin_slide  # Slide cutin graphic
  SEQUENCE_TARGET_FLIP      = :target_flip  # Flip target
  SEQUENCE_PLANE_ADD        = :plane_add    # Show looping image
  SEQUENCE_PLANE_DEL        = :plane_del    # Delete looping image
  SEQUENCE_BOOMERANG        = :boomerang    # Flag projectile as boomerang
  SEQUENCE_PROJ_AFTERIMAGE  = :proj_afimage # Set afterimage for projectile
  SEQUENCE_BALLOON          = :balloon      # Show balloon icon
  # -------------------------------------------
  # Update v1.2
  # -------------------------------------------
  SEQUENCE_LOGWINDOW        = :log        # Display battle log
  SEQUENCE_LOGCLEAR         = :log_clear  # Clear battle log
  SEQUENCE_AFTINFO          = :aft_info   # Change afterimage
  SEQUENCE_SMMOVE           = :sm_move    # Smooth move
  SEQUENCE_SMSLIDE          = :sm_slide   # Smooth slide
  SEQUENCE_SMTARGET         = :sm_target  # Smooth move to target
  SEQUENCE_SMRETURN         = :sm_return  # Smooth return
  # -------------------------------------------
  # Update v1.3
  # -------------------------------------------
  SEQUENCE_LOOP             = :loop         # Loop in n times
  SEQUENCE_WHILE            = :while        # While loop
  SEQUENCE_COLLAPSE         = :collapse     # Perform collapse effect  
  SEQUENCE_FORCED           = :forced       # Force change action key to target
  SEQUENCE_ANIMBOTTOM       = :anim_bottom    # Play anim behind battler
  SEQUENCE_CASE             = :case           # Case switch
  SEQUENCE_INSTANT_RESET    = :instant_reset  # Instant reset
  SEQUENCE_ANIMFOLLOW       = :anim_follow    # Animation follow the battler
  SEQUENCE_CHANGE_SKILL     = :change_skill   # Change carried skill
  # v1.3b
  SEQUENCE_CHECKCOLLAPSE    = :check_collapse # Check collapse for target
  SEQUENCE_RESETCOUNTER     = :reset_counter  # Reset damage counter
  SEQUENCE_FORCEHIT         = :force_hit      # Toggle force to always hit
  SEQUENCE_SLOWMOTION       = :slow_motion    # Slow Motion effect
  SEQUENCE_TIMESTOP         = :timestop       # Timestop effect
  # v1.3c
  SEQUENCE_ONEANIM          = :one_anim       # One Anim Flag
  SEQUENCE_PROJ_SCALE       = :proj_scale     # Scale damage for projectile
  SEQUENCE_COMMON_EVENT     = :com_event      # Call common event
  SEQUENCE_GRAPHICS_FREEZE  = :scr_freeze     # Freeze the graphic
  SEQUENCE_GRAPHICS_TRANS   = :scr_trans      # Transition
  
  # Screen sub-modes
  Screen_Tone       = :tone       # Set screen tone
  Screen_Shake      = :shake      # Set screen shake
  Screen_Flash      = :flash      # Set screen flash
  Screen_Normalize  = :normalize  # Normalize screen
  
  # Projectile setup
  ProjSetup_Feet    = :feet   # Set target projectile to feet
  ProjSetup_Middle  = :middle # Set target projectile to body
  ProjSetup_Head    = :head   # Set target projectile to head
  
  # -------------------------------------------------------------------------
  # Regular Expression (REGEXP) Constants. Want to simplify notetags? edit 
  # this section. If only you understand the ruby regular expression
  # -------------------------------------------------------------------------
  
  AnimGuard = /<anim[_\s]+guard\s*:\s*(\d+)>/i
  # Notetag for animation guard
  
  SkillGuard = /<skill[_\s]+guard\s*:\s*(\d+)>/i
  # Notetag for skill guard
  
  IgnoreSkillGuard = /<ignore[-\s]skill[-\s]guard>/i
  # Notetag for skill that ignore state skill guard
  
  IgnoreAnimGuard = /<ignore[-\s]anim[-\s]guard>/i
  # Notetag for skill that ignore state skill guard
  
  ParallelTAG = /<parallel[\s_]+anim>/i
  # Pararrel tag to plays animation and anim guard simultaneously
  
  StateOpacity = /<opacity\s*:\s*(\d+)>/i
  # Notetag for state Opacity
  
  SequenceREGX = /\\sequence\s*:\s*(.+)/i
  # Action sequence notetag in skill
  
  PrepareREGX = /\\preparation\s*:\s*(.+)/i
  # Preparation move for skill
  
  ReturnREGX = /\\return\s*:\s*(.+)/i
  # Return sequence movement for each skill
  
  ReflectAnim = /<reflect[_\s]+anim\s*:\s*(\d+)>/i
  # Reflect animation for skill
  
  AreaTAG = /<area>/i
  # Tag for area skill
  
  NoReturnTAG = /<no[\s_]+return>/i
  # Tag for no return sequence for skill
  
  NoShadowTAG = /<no[\s_]+shadow>/i
  # Tag for no shadow for actor/enemy
  
  AbsoluteTarget = /<abs[-_\s]+target>/i
  # Tag for absolute targeting
  
  StateAnim = /<animation\s*:\s*(\d+)/i
  # State Animation ID notetag
  
  AlwaysHit = /<always[_\s]+hit>/i
  # Always hit tag
  
  AntiCounter = /<anti[_\s]+counter>/i
  # Anti counter attack
  
  AntiReflect = /<anti[_\s]+reflect>/i
  # Anti magic reflect
  
  CounterSkillID = /<counter[_\s]+skill\s*:\s*(\d+)>/i
  # Counter Skill ID
  
  RandomReflect = /<random[_\s]+reflect>/i
  # Random magic reflection
  
  Transform = /<transform\s*:\s*(.+)>/i
  # Transform State
  
  DefaultFlip = /<flip>/i
  # Default flip for enemies
  
  DefaultATK = /<attack[\s_]*:\s*(\d+)>/i
  DefaultDEF = /<guard[\s_]*:\s*(\d+)>/i
  # Default basic actions
  
  AnimBehind = /<anim[\s_]+behind>/i
  # State Animation behind flag
  
  CollapSound = /<collapsound\s*:\s*(.+)\s*,\s*(\d+)\s*,\s*(\d+)\s*>/i
  # Collapse sound effect 
  
  OneAnimation = /<one animation>/i
  # One Animation tag
  
  ToneREGX = 
  /<tone:\s*(-|\+*)(\d+),\s*(-|\+*)(\d+),\s*(-|\+*)(\d+),\s*(-|\+*)(\d+)>/i
  # Regular expression for state tone tag
  
  ColorREGX =
  /<color:\s*(-|\+*)(\d+),\s*(-|\+*)(\d+),\s*(-|\+*)(\d+),\s*(-|\+*)(\d+)>/i
  # Regular expression for state color blend
  
  SBS_Start   = /<sideview>/i             # Starting Sideview Tag
  SBS_Start_S = /<sideview\s*:\s*(.+)>/i  # Starting with string
  SBS_End     = /<\/sideview>/i           # End of sideview tag
  
  # ---------------------------------------------
  # Sideview tags
  # ---------------------------------------------
  
  SBS_Idle      = /\s*idle\s*:\s*(.+)/i
  SBS_Critical  = /\s*critical\s*:\s*(.+)/i
  SBS_Evade     = /\s*evade\s*:\s*(.+)/i
  SBS_Hurt      = /\s*hurt\s*:\s*(.+)/i
  SBS_Return    = /\s*return\s*:\s*(.+)/i
  SBS_Dead      = /\s*dead\s*:\s*(.+)/i
  SBS_Escape    = /\s*escape\s*:\s*(.+)/i
  SBS_Win       = /\s*victory\s*:\s*(.+)/i
  SBS_Intro     = /\s*intro\s*:\s*(.+)/i
  SBS_Counter   = /\s*counter\s*:\s*(.+)/i
  SBS_Collapse  = /\s*collapse\s*:\s*(.+)/i
  
  # -------------------------------------------------------------------------
  # Error Handler. Because I don't want to be blamed ~
  # -------------------------------------------------------------------------
  
  ErrorSound = RPG::SE.new("Buzzer1",100,100)
  def self.error(symbol, params, seq)
    ErrorSound.play
    text = "Sequence : #{seq}\n" +
    "#{symbol} mode needs at least #{params} parameters"
    msgbox text
    exit
  end
  
end
#===============================================================================
# * Rewrite module for how animation is handled in TSBS
#-------------------------------------------------------------------------------
# Put it inside any subclass of Sprite_Base. Don't forget to add @anim_top
# inside its start_animation as well
#-------------------------------------------------------------------------------