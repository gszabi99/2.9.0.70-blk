local {
  HasTargetTracker,
  IsSightLocked,
  IsTargetTracked,
  AimCorrectionEnabled,
  TargetRadius,
  TargetAge,
  TargetX,
  TargetY } = require("reactiveGui/hud/targetTrackerState.nut")


local hl = 20
local vl = 20

local styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
}


local function lockSight(colorWatched, width, height, posX, posY) {
  return @() styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    color = colorWatched.value
    watch = [IsSightLocked, IsTargetTracked, colorWatched]
    commands = IsSightLocked.value && !IsTargetTracked.value
      ? [
          [VECTOR_LINE, 0, 0, hl, vl],
          [VECTOR_LINE, 0, 100, vl, 100 - vl],
          [VECTOR_LINE, 100, 100, 100 - hl, 100 - vl],
          [VECTOR_LINE, 100, 0, 100 - hl, vl]
        ]
      : null
  })
}

local targetSize = @(colorWatched, width, height, is_static_pos) function() {
  local hd = 5
  local vd = 5
  local posX = is_static_pos ? 50 : (TargetX.value / sw(100) * 100)
  local posY = is_static_pos ? 50 : (TargetY.value / sh(100) * 100)

  local target_radius = TargetRadius.value

  local getAimCorrectionCommands = [
      [
        VECTOR_RECTANGLE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        2.0 * target_radius / width * 100,
        2.0 * target_radius / height * 100
      ],
      [
        VECTOR_ELLIPSE,
        50,
        50,
        target_radius / width * 100,
        target_radius / height * 100
      ]
    ]

  local getTargetTrackedCommands = [
      [
        VECTOR_RECTANGLE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        2.0 * target_radius / width * 100,
        2.0 * target_radius / height * 100
      ]
    ]

  local getTargetUntrackedCommands = [
      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        posX - (target_radius - hd) / width * 100,
        posY - target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY - target_radius / height * 100,
        posX - target_radius / width * 100,
        posY - (target_radius - vd) / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY - target_radius / height * 100,
        posX + (target_radius - hd) / width * 100,
        posY - target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY - target_radius / height * 100,
        posX + target_radius / width * 100,
        posY - (target_radius - vd) / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY + target_radius / height * 100,
        posX + (target_radius - hd) / width * 100,
        posY + target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX + target_radius / width * 100,
        posY + target_radius / height * 100,
        posX + target_radius / width * 100,
        posY + (target_radius - vd) / height * 100],

      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY + target_radius / height * 100,
        posX - (target_radius - hd) / width * 100,
        posY + target_radius / height * 100
      ],
      [
        VECTOR_LINE,
        posX - target_radius / width * 100,
        posY + target_radius / height * 100,
        posX - target_radius / width * 100,
        posY + (target_radius - vd) / height * 100
      ]
    ]

  return styleLineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    color = colorWatched.value
    size = [width, height]
    fillColor = Color(0, 0, 0, 0)
    watch = [ IsTargetTracked, AimCorrectionEnabled, HasTargetTracker, TargetRadius, TargetX, TargetY, colorWatched ]
    commands = !HasTargetTracker.value || TargetRadius.value <= 0.0 ? null
      : !IsTargetTracked.value ? getTargetUntrackedCommands
      : AimCorrectionEnabled.value ? getAimCorrectionCommands
      : getTargetTrackedCommands
  })
}

local targetSizeTrigger = {}
TargetAge.subscribe(@(v) v >= 0.2 ? ::anim_start(targetSizeTrigger) : ::anim_request_stop(targetSizeTrigger))

local function targetSizeComponent(
  colorWatched,
  width,
  height,
  is_static_pos) {

  return @() {
    pos = [0, 0]
    size = SIZE_TO_CONTENT
    watch = [TargetX, TargetY]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = TargetAge.value >= 0.2, loop = true, easing = InOutSine, trigger = targetSizeTrigger}]
    children = targetSize(colorWatched, width, height, is_static_pos)
  }
}

return {
  lockSight
  targetSize = targetSizeComponent
}
