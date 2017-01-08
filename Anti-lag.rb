# encoding: utf8
# [132] 77095198: Anti-lag
# ================================================= =============================
# + + + MOG - Simple Anti Lag (V1.0) + + +
# ================================================= =============================
# By Moghunter
# [url]http://www.atelier-rgss.com[/url]
# ================================================= =============================
# antilag System .
# ================================================= =============================
# To disable or enable antilag system use The Following command
#
# $ Game_system.anti_lag = true
#
# ================================================= =============================
# NOTE - This script does not work on maps with effect LOOP.
#
# ================================================= =============================
module MOG_ANTI_LAG
  # Area that will be updated off-screen. 
  UPDATE_OUT_SCREEN_RANGE = 3 
end

#==============================================================================
# ■ Game_System
#==============================================================================
class Game_System
  attr_accessor :anti_lag
  
 #--------------------------------------------------------------------------
 # ● Initialize
 #--------------------------------------------------------------------------   
  alias mog_antilag_initialize initialize
  def initialize
      @anti_lag = true
      mog_antilag_initialize
  end  
end

#==============================================================================
# ■ Game_Character
#==============================================================================
class Game_Event < Game_Character
  
  attr_accessor :can_update            

  #--------------------------------------------------------------------------
  # ● Initialize
  #--------------------------------------------------------------------------
  alias mog_anti_lag_initialize initialize
  def initialize(map_id, event)
      mog_anti_lag_initialize(map_id, event)
      @can_update = true
      @anti_lag = true
      if $game_map.loop_horizontal? or $game_map.loop_vertical?
         @anti_lag = false
      end
  end
    
 #--------------------------------------------------------------------------
 # ● Check Event on Screen
 #-------------------------------------------------------------------------- 
 def update_anti_lag
     unless $game_system.anti_lag
         @can_update = true 
         return
     end  
     anti_lag_event_on_screen
 end 
    
 #--------------------------------------------------------------------------
 # ● Event On Screen
 #--------------------------------------------------------------------------
 def anti_lag_event_on_screen
     @can_update = false
     out_screen = MOG_ANTI_LAG::UPDATE_OUT_SCREEN_RANGE
     px = ($game_map.display_x).truncate
     py = ($game_map.display_y).truncate
     distance_x = @x - px
     distance_y = @y - py
     if distance_x.between?(0 - out_screen, 16 + out_screen) and
        distance_y.between?(0 - out_screen, 12 + out_screen)
        @can_update = true
     end
 end
  
 #--------------------------------------------------------------------------
 # ● Update
 #--------------------------------------------------------------------------     
  alias mog_anti_lag_update update
  def update
      update_anti_lag unless !@anti_lag
      return if !@can_update
      mog_anti_lag_update
  end
end

#==============================================================================
# ■ Sprite Character
#==============================================================================
class Sprite_Character < Sprite_Base

 #--------------------------------------------------------------------------
 # ● Check Can Update Sprite
 #--------------------------------------------------------------------------       
  def check_can_update_sprite
      if self.visible and !@character.can_update
         reset_sprite_effects
      end        
      self.visible = @character.can_update           
  end
  
 #--------------------------------------------------------------------------
 # ● Reset Sprite Effects
 #--------------------------------------------------------------------------         
  def reset_sprite_effects
      dispose_animation
  end
  
 #--------------------------------------------------------------------------
 # ● Update
 #--------------------------------------------------------------------------           
  alias mog_anti_lag_update update
  def update
      if $game_system.anti_lag and @character.is_a?(Game_Event)
         check_can_update_sprite
         return unless self.visible
      end   
      mog_anti_lag_update
  end
  
end

$mog_rgss3_anti_lag = true