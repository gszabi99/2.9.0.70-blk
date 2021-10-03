local { isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { TIME_HOUR_IN_SECONDS } = require("std/time.nut")
local { getShopItem } = require("scripts/onlineShop/entitlementsStore.nut")
local steamRateGameWnd = require("steamRateGameWnd.nut")
local { debriefingRows } = require("scripts/debriefing/debriefingFull.nut")

local log = require("std/log.nut")().with_prefix("[UserUtils] ")

local needShowRateWnd = persist("needShowRateWnd", @() ::Watched(false)) //need this, because debriefing data destroys after debriefing modal is closed

local winsInARow = persist("winsInARow", @() ::Watched(0))
local haveMadeKills = persist("haveMadeKills", @() ::Watched(false))
local havePurchasedSpecUnit = persist("havePurchasedSpecUnit", @() ::Watched(false))
local havePurchasedPremium = persist("havePurchasedPremium", @() ::Watched(false))

const RATE_WND_SAVE_ID = "seen/rateWnd"

local isConfigInited = false
local cfg = { // Overridden by gui.blk values
  totalPvpBattlesMin = 7
  totalPlayedHoursMax = 300
  minPlaceOnWin = 3
  totalWinsInARow = 3
  minKillsNum = 1
  hideSteamRateLanguages = ""
  hideSteamRateLanguagesArray = []
}

local function initConfig() {
  if (isConfigInited)
    return
  isConfigInited = true

  local guiBlk = ::configs.GUI.get()
  local cfgBlk = guiBlk?.suggestion_rate_game
  foreach (k, v in cfg)
    cfg[k] = cfgBlk?[k] ?? cfg[k]
  cfg.hideSteamRateLanguagesArray = cfg.hideSteamRateLanguages.split(";")
}

local function setNeedShowRate(debriefingResult, myPlace) {
  //can be on any platform in future,
  //no need to specify platform in func name
  if ((!isPlatformXboxOne && !::steam_is_running()) || debriefingResult == null)
    return

  if (::load_local_account_settings(RATE_WND_SAVE_ID, false)) {
    log("[ShowRate] Already seen")
    return
  }

  initConfig()

  if (::my_stats.getPvpPlayed() < cfg.totalPvpBattlesMin) // Newbies
    return
  if (!::my_stats.isStatsLoaded() || (::my_stats.getTotalTimePlayedSec() / TIME_HOUR_IN_SECONDS) > cfg.totalPlayedHoursMax) // Old players
    return

  local isWin = debriefingResult?.isSucceed && (debriefingResult?.gm == ::GM_DOMINATION)
  if (isWin && (havePurchasedPremium.value || havePurchasedSpecUnit.value || myPlace <= cfg.minPlaceOnWin)) {
    log($"[ShowRate] Passed by win and prem {havePurchasedPremium.value || havePurchasedSpecUnit.value} or win and place {myPlace} condition")
    needShowRateWnd(true)
    return
  }

  if (isWin) {
    winsInARow(winsInARow.value+1)

    local totalKills = 0
    debriefingRows.each(function(b) {
      if (b.id.contains("Kills"))
        totalKills += debriefingResult.exp?[$"num{b.id}"] ?? 0
    })

    haveMadeKills(haveMadeKills.value || totalKills >= cfg.minKillsNum)
    log($"[ShowRate] Update kills count {totalKills}; haveMadeKills {haveMadeKills.value}")
  }
  else {
    winsInARow(0)
    haveMadeKills(false)
  }

  if (winsInARow.value >= cfg.totalWinsInARow && haveMadeKills.value) {
    log("[ShowRate] Passed by wins in a row and kills")
    needShowRateWnd(true)
  }
}

local function tryOpenXboxRateReviewWnd() {
  if (isPlatformXboxOne && ::xbox_show_rate_and_review())
  {
    ::save_local_account_settings(RATE_WND_SAVE_ID, true)
    ::add_big_query_record("rate", "xbox")
  }
}

local function tryOpenSteamRateReview(forceShow = false) {
  if (!forceShow && (!::steam_is_running() || !::has_feature("SteamRateGame")))
    return

  if (!forceShow && cfg.hideSteamRateLanguagesArray.contains(::g_language.getLanguageName()))
    return

  ::save_local_account_settings(RATE_WND_SAVE_ID, true)
  ::add_big_query_record("rate", "steam")
  steamRateGameWnd.open()
}

local function checkShowRateWnd() {
  if (!needShowRateWnd.value || ::load_local_account_settings(RATE_WND_SAVE_ID, false))
    return

  tryOpenXboxRateReviewWnd()
  tryOpenSteamRateReview()

  // in case of error, show in next launch.
  needShowRateWnd(false)
}

addListenersWithoutEnv({
  UnitBought = function(p) {
    local unit = ::getAircraftByName(p?.unitName)
    if (unit && ::isUnitSpecial(unit))
      havePurchasedSpecUnit(true)
  }
  EntitlementStoreItemPurchased = function(p) {
    if (getShopItem(p?.id)?.isMultiConsumable == false) //isMultiConsumable == true - eagles
      havePurchasedSpecUnit(true)
  }
  OnlineShopPurchaseSuccessful = function(p) {
    if (p?.purchData.chapter == ONLINE_SHOP_TYPES.PREMIUM)
      havePurchasedPremium(true)
  }
})

return {
  setNeedShowRate
  checkShowRateWnd
  tryOpenSteamRateReview
}