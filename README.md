# seroperson's Warhammer 40k Darktide mods

Hello and welcome to my Darktide mods repository.

- [FilterTrash](#filtertrash)
- [GlobalStore](#globalstore)
- [ImprovedPenanceTracking](#improvedpenancetracking)

## FilterTrash

Filters Brunt's store weapon items to get rid of unusable trash. Currently it
supports:

- Filtering based on every available item max stat (60-80%).
- Filtering "ideal" items. When checked, it shows only elements which have one
  max stat 60%.
- Filtering items which have all stats >= 70-76%.
- Filtering curios based on their rating (0-430).
- Works both in Armoury and Requisitorium.
- English, Russian, Chinese (by deluxghost) localization.

Relics are always visible because it takes not so much time to check them
manually.

## GlobalStore

Adds a button to Armoury and Requisitorium which allows you to open an
aggregated store view with offers from all your characters. It dramatically
speed up your store checking because you no longer need to check every character
separately. Works best in combo with `FilterTrash`.

Note: If used in combination with `FilterTrash`, it should be loaded BEFORE
`FilterTrash`.

## ImprovedPenanceTracking

Minor QoL improvements for penance tracking system:

- Increases max penances tracking limit up to 20.
- Allows you to hide other classes penances in TAB overlay if not playing this
  class right now (togglable in settings, default: false). For example, it hides
  Zealot's penances when playing Orgyn.

Known issues: TAB overlay is missing scrollbar if too much penances are tracked.
