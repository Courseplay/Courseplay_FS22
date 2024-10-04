# Courseplay Beta for Farming Simulator 2022

<!-- [![Modhub release (latest by date)](https://img.shields.io/badge/dynamic/xml?color=blue&style=flat-square&label=Modhub+Release&prefix=v&query=%2F%2Fdiv%5B%40class%3D%27table-cell%27%5D%5B2%5D%5Bcontains%28text%28%29%2C%227.%22%29%5D&url=https%3A%2F%2Fwww.farming-simulator.com%2Fmod.php%3Flang%3Dde%26country%3Dde%26mod_id%3D248390%26title%3Dfs2022)](https://www.farming-simulator.com/mod.php?lang=de&country=de&mod_id=248390&title=fs2022) -->
[![Modhub release](https://img.shields.io/badge/Modhub%20Release-Modification-blue.svg)](https://www.farming-simulator.com/mod.php?mod_id=248390)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/Courseplay/Courseplay_FS22?include_prereleases&style=flat-square&label=Github+Release)](https://github.com/Courseplay/Courseplay_FS22/releases/latest)
[![GitHub Pre-Releases (by Asset)](https://img.shields.io/github/downloads-pre/Courseplay/Courseplay_FS22/latest/FS22_Courseplay.zip?style=flat-square)](https://github.com/Courseplay/Courseplay_FS22/releases/latest/download/FS22_Courseplay.zip)
[![GitHub issues](https://img.shields.io/github/issues/Courseplay/Courseplay_FS22?style=flat-square)](https://github.com/Courseplay/Courseplay_FS22/issues)

**[Download the latest developer version](https://github.com/Courseplay/Courseplay_FS22/releases/latest)** (the file FS22_Courseplay.zip).

**[Courseplay Website](https://courseplay.github.io/Courseplay_FS22.github.io/)**

## What Works

* **Multiplayer support**
* Fieldwork mode:
  * Course generator for complex fields with many option like headlands or beets with combines and so on ..
  * Up to 5 workers with the same tools can work together on a field with the same course (multi tools)
  * Generate courses for vine work
  * Save/load/rename/move courses
  * Load courses for baling, straw or grass collection and so on
  * Combines can automatically unload into nearby trailers (combine self unload)
* Bale collector mode:
  * Wrapping bales on a field without a course
  * Collecting bales on the field without a course and unloading them with [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive)
* Combine unloader mode:
  * Unload combines on the field
  * Sending the giants helper or [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive) to unload at an unload station
  * Creating heaps of sugar beets or other fruits on the field
  * Unloading a loader vehicle, like the ``ROPA Maus`` and letting [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive) or Giants unload the trailer after that
* Silo load mode:
  * Loading from a heap or bunker silo with loader, like the ``ROPA Maus``
  * Using a wheel loader or a front loader to load from a heap or a bunker silo and unload to:
    * Unloading to nearby trailers
    * Unloading to an unloading station, which needs to be selected on the AI menu
* Bunker silo mode:
  * Compacting the silo with or without tools like this one [Silo distributor](https://www.farming-simulator.com/mod.php?lang=de&country=de&mod_id=242708&title=fs2022)
  * Using a shield in a silo with a back wall to push the chaff to the back of silo
* Misc:
  * Creating custom fields by recording the boarder with a vehicle or drawing on the AI Map.
  * Course editor in the buy menu to edit courses or custom fields.
* Mod support with [AutoDrive](https://github.com/Stephan-S/FS22_AutoDrive):
  * Sending the fieldwork driver to refill seeds/fertilizers and so on.
  * Sending the fieldworker/ bale collector to unload collected straw and so on.
  * Sending the fieldwork driver to refuel or repair.
* Bale collector mod support for:
  * [Pallet Autoload Specialization](https://www.farming-simulator.com/mod.php?lang=en&country=gb&mod_id=228819)
  * [Universal Autoload](https://farming-simulator.com/mod.php?lang=en&country=us&mod_id=237080&title=fs2022)

## Usage

Courseplay functions are now documented in the in-game help menu:

![image](https://user-images.githubusercontent.com/2379521/195123670-20773556-48d4-4292-ba06-28443a2f9c69.png)

If you prefer videos, YouTube has many great [tutorials](https://www.youtube.com/results?search_query=courseplay+fs22)

## Turning on Debug Channels

When there's an issue, you can turn on debug logging on the Courseplay vehicle settings page for each vehicle. This will
enable logging of debug information for only this vehicle. **Devs need those logs for troubleshooting and fixing bugs.**

What information is logged when you activated the debug logging for the vehicle depends on the active debug channels. This
are similar to those we had in CP 19, but the way to turn them on/off is different: you can bring up the debug channel menu
by pressing Shift+4, then use Shift+1 and Shift+3 to select a channel, and then Shift+2 to toggle the selected debug channel
(green is on).

Remember, you have to activate debug mode for the vehicle in the vehicle settings page, otherwise nothing is logged, even if
the channel is active.

## Developer version

Please be aware you're using a developer version, which may and will contain errors, bugs, mistakes and unfinished code. Chances are you computer will explode when using it. Twice. If you have no idea what "beta", "alpha", or "developer" means and entails, steer clear. The Courseplay team will not take any responsibility for crop destroyed, savegames deleted or baby pandas killed.

You have been warned.

If you're still ok with this, please remember to post possible issues that you find in the developer version. That's the only way we can find sources of error and fix them.
Be as specific as possible:

* tell us the version number
* only use the vehicles necessary, not 10 other ones at a time
* which vehicles are involved, what is the intended action?
* Post! The! Log! to [Gist](https://gist.github.com/) or [PasteBin](http://pastebin.com/)
* For more details on how to post a proper bug report, visit our [Wiki](https://github.com/Courseplay/Courseplay_FS22/wiki)

## Help Us Out

We work long, hard, in our own free time at developing and improving Courseplay. If you like the project, show us your undying love:

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=7PDM2P6HQ5D56&item_name=Promote+the+development+of+Courseplay&currency_code=EUR&source=url)

___

## Contributors

See [Contributors](/Contributors.md)

___

## Supporters

People and teams who support us

* Ameyer1233 [ModHoster Profile](https://www.modhoster.de/community/user/meyer123)

* Burning Gamers [YouTube Channel](https://www.youtube.com/c/BurningGamersde/featured)

* Mario Hirschfeld [YouTube Channel](https://www.youtube.com/c/MarioHirschfeld/featured)
