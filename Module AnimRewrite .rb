# encoding: utf8
# [125] 12658225: Module AnimRewrite 
#============================================================================
# * Rewrite module for how animation is handled in TSBS
#-------------------------------------------------------------------------------
# Put it inside any subclass of Sprite_Base. Don't forget to add @anim_top
# inside its start_animation as well
#-------------------------------------------------------------------------------
module TSBS_AnimRewrite
  # --------------------------------------------------------------------------
  # Overwrite method : animation set sprites
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
      # ---------------------------------------------
      # If animation position is to screen || on top?
      # ---------------------------------------------
      if (@animation.position == 3 && !@anim_top == -1) || @anim_top == 1
        sprite.z = self.z + 400 + i  # Always display in top
      elsif @anim_top == -1
        sprite.z = 3 + i
      else
        sprite.z = self.z + 2 + i
      end
      sprite.ox = 96
      sprite.oy = 96
      sprite.zoom_x = cell_data[i, 3] / 100.0
      sprite.zoom_y = cell_data[i, 3] / 100.0
      sprite.opacity = cell_data[i, 6] * self.opacity / 255.0
      sprite.blend_type = cell_data[i, 7]
    end
  end
end
# ----------------------------------------------------------------------------
# Kernel method to get scene spriteset
# ----------------------------------------------------------------------------
def get_spriteset
  SceneManager.scene.instance_variable_get("@spriteset")
end
# ----------------------------------------------------------------------------
# Kernel method for chance
# ----------------------------------------------------------------------------
def chance(c)
  return rand < c
end
# ----------------------------------------------------------------------------
# Copy method
# ----------------------------------------------------------------------------
def copy(object)
  Marshal.load(Marshal.dump(object))
end
# ----------------------------------------------------------------------------
# Altered basic module
# ----------------------------------------------------------------------------
module THEO
  module Movement
    class Move_Object
      attr_reader :real_y
    end
    def real_ypos
      return @move_obj.real_y if @move_obj.real_y > 0
      return self.y
    end
  end
end