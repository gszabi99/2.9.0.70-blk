local { openUrl } = require("scripts/onlineShop/url.nut")

class ::gui_handlers.SteamRateGame extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/steamRateGame/steamRateGame"

  getSceneTplView = @() {}
  initScreen = @() null

  onApply = @() openUrl(::loc("url/steam/community", {appId = ::steam_get_app_id()} ))
  onEventDestroyEmbeddedBrowser = @(p) goBack()
}

return {
  open = @() ::handlersManager.loadHandler(::gui_handlers.SteamRateGame)
}