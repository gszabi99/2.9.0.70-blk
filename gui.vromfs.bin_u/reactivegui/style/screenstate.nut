local extWatched = require("reactiveGui/globals/extWatched.nut")

local debugRowHeight = 14 /* Height of on-screen debug text (fps, build, etc) */

local resolution = extWatched("resolution",
  @() ::cross_call.sysopt.getGuiValue("resolution", "1024 x 768"))

local mode = extWatched("screenMode",
  @() ::cross_call.sysopt.getGuiValue("mode", "fullscreen"))

local safeAreaHud = extWatched("safeAreaHud",
  @() ::cross_call.getHudSafearea() ?? [ 1.0, 1.0 ])

local safeAreaMenu = extWatched("safeAreaMenu",
  @() ::cross_call.getMenuSafearea() ?? [ 1.0, 1.0 ])

local isInVr = extWatched("isInVr", @() ::cross_call.isInVr())

local recalculateHudSize = function(safeArea) {
  local borders = [
    ::max((sh((1.0 - safeArea[1]) *100) / 2).tointeger(), debugRowHeight),
    ::max((sw((1.0 - safeArea[0]) *100) / 2).tointeger(), debugRowHeight)
  ]
  local size = [sw(100) - 2 * borders[1], sh(100) - 2 * borders[0]]
  return {
    size = size
    borders = borders
  }
}

local safeAreaSizeHud = ::Computed(@() recalculateHudSize(safeAreaHud.value))
local safeAreaSizeMenu = ::Computed(@() recalculateHudSize(safeAreaMenu.value))

local rw = ::Computed(@() safeAreaSizeHud.value.size[0])
local rh = ::Computed(@() safeAreaSizeHud.value.size[1])
local bw = ::Computed(@() safeAreaSizeHud.value.borders[1])
local bh = ::Computed(@() safeAreaSizeHud.value.borders[0])

local function setOnVideoMode(...){
  ::gui_scene.setInterval(0.5,
    function() {
      ::gui_scene.clearTimer(callee())
      ::interop.updateExtWatched({
        safeAreaHud = ::cross_call.getHudSafearea() ?? [ 1.0, 1.0 ]
        safeAreaMenu = ::cross_call.getMenuSafearea() ?? [ 1.0, 1.0 ]
      })
  })
}
foreach (w in [resolution, mode])
  w.subscribe(setOnVideoMode)

return {
  safeAreaSizeHud
  safeAreaSizeMenu
  rw
  rh
  bw
  bh
  isInVr
}
