FREE GAME & UI SOUND PACK
=========================

60 sound effects for menus and games (24 UI + 36 game sounds), each as
WAV (44.1 kHz, 16-bit, mono) and OGG. Free for personal and commercial
games. Made by Willosuna.

  >> PLEASE RATE IT: a quick rating on the itch.io page is the best way to
     support this pack and it keeps the free packs coming:
     https://willosuna.itch.io/free-game-ui-sound-pack

WANT MORE?
  Pickups SFX - coins, gems, power-ups and rewards with many versions each:
    https://willosuna.itch.io/pixel-pickups-sfx
  Pixel Combat SFX - explosions, gunshots, slashes and impacts:
    https://willosuna.itch.io/pixel-combat-sfx
  Willosuna All-in-One - every Willosuna pack in one download:
    https://willosuna.itch.io/willosuna-all-in-one
  Bonus file on the same page (pay $1.99 or more): 12 more sounds
  (footsteps, ladder, ice, dive, boss roar, lock on, 3 combo hits,
  secret jingle and treasure).

THE SOUNDS (name, seconds, use)
  ui/
    ui_blip_up            0.13  menu cursor moves up
    ui_blip_down          0.13  menu cursor moves down
    ui_tab_switch         0.09  switch tab or page
    ui_slider_tick        0.05  slider or scroll step
    ui_checkbox_on        0.16  checkbox or toggle on
    ui_checkbox_off       0.13  checkbox or toggle off
    ui_popup_in           0.15  window or popup opens
    ui_popup_out          0.12  window or popup closes
    ui_tooltip            0.14  tooltip or hint appears
    ui_back               0.16  back or return
    ui_accept             0.42  accept or confirm choice
    ui_invalid            0.22  not allowed or wrong input
    ui_typewriter         0.07  dialogue text letter
    ui_score_count        0.50  score counting up
    ui_countdown_beep     0.17  3-2-1 countdown beep
    ui_countdown_go       0.55  countdown GO
    ui_drag_start         0.10  pick up an item to drag
    ui_place              0.13  drop or place an item in a slot
    ui_achievement        1.00  achievement unlocked
    ui_quest_complete     1.15  quest or mission complete
    ui_star_1             0.35  first rating star
    ui_star_2             0.41  second rating star
    ui_star_3             0.45  third rating star
    ui_menu_whoosh        0.26  menu slides in
  game/
    jump                  0.19  jump
    double_jump           0.26  double jump
    land                  0.16  land on the ground
    dash                  0.17  dash or quick dodge
    spring_bounce         0.45  spring or bounce pad
    gem_collect           0.40  collect a gem
    key_collect           0.55  collect a key
    heart_collect         0.60  collect health
    powerup               0.75  get a power-up
    power_down            0.70  lose a power-up
    shield_up             0.60  shield on
    shield_break          0.70  shield breaks
    hurt                  0.20  player takes damage
    player_death          1.10  player dies
    enemy_hit             0.11  hit an enemy
    enemy_defeat          0.45  enemy defeated
    stomp                 0.18  stomp an enemy
    laser_shot            0.22  laser gun
    blaster_shot          0.20  blaster gun
    explosion_small       0.65  small explosion
    explosion_big         1.50  big explosion
    door_open             0.70  door opens
    chest_open            0.85  treasure chest opens
    switch_flip           0.14  lever or switch
    teleport              0.65  teleport or warp
    checkpoint            0.85  checkpoint reached
    game_over             1.80  game over jingle
    stage_clear           1.60  stage clear jingle
    block_bump            0.14  head bumps a block
    block_break           0.45  block breaks
    splash                0.65  fall into water
    throw                 0.17  throw an item
    sword_swing           0.24  sword swing
    arrow_shot            0.32  bow shot
    bomb_fuse             1.20  lit bomb fuse
    magic_cast            0.80  cast a spell

FOLDERS
  wav/ui/  wav/game/     WAV files
  ogg/ui/  ogg/game/     OGG files (same names)
  godot/GameSfx.gd       sound player for Godot 4 (Autoload, play by name)
  godot/sfx_board.tscn   a soundboard scene with a button per sound
  unity/GameSfx.cs       sound player for Unity (play by name)
  manifest.json          name, category, length, files and use of each

HOW TO USE
  Godot 4:  copy the folder "free_game_ui_sounds" to res://, add
            godot/GameSfx.gd as an Autoload named GameSfx and call
            GameSfx.play("jump") or GameSfx.play("enemy_hit", 0.05) for a
            small random pitch. Open godot/sfx_board.tscn to hear them all.
  Unity:    copy the ogg folders into Assets/Resources/GameSfx, add
            GameSfx.cs to a GameObject and call GameSfx.Play("jump").
  Others:   the files are plain WAV and OGG; names say what they are for.
  Every sound starts right away (no silence at the start) and ends with a
  smooth tail, and all of them are leveled to the same loudness.

HOW IT WAS MADE
  Every sound is synthesized by original code written for this pack:
  oscillators, plucked strings, bells, filtered noise and envelopes.
  No recordings, no third-party samples.

LICENSE
  Personal and commercial use, royalty free, no attribution required.
  Do not resell or redistribute the files as a sound pack. See LICENSE.txt.
