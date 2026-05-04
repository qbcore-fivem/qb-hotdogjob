# qb-hotdogjob
Grand bit of work here, lads! A proper hot dog stand job for QBCore that'll have your players makin' a few bob while actually enjoyin' the ride.

## What's the Craic?
Look, you set up your hot dog stand, you get stuck into a bit of cookin' action, and then you're sellin' to the customers that come your way. The catch? Some folks are sound, some are awkward, and what time of day it is makes a massive difference to your profits. It's not just about flippin' a hotdog—you gotta actually be decent at the cookin' minigame to make the good stuff.

## 🎥 Showcase

<p align="center">
  <a href="https://youtu.be/bi9Z18guCgg">
    <img src="https://img.youtube.com/vi/bi9Z18guCgg/maxresdefault.jpg" width="700" alt="qb-hotdogjob showcase"/>
  </a>
</p>

<p align="center">
  ▶ Click to watch the full demo
</p>


## The Features, Yeah

### Your Stand
- Plop down a stand somewhere with a bit of cash upfront (deposit-like)
- Turn the sellin' on and off, dead easy—got a nice red and green light to show the story
- Little dashboard showin' how many dogs ya got, what you're makin', that kind of thing
- Keeps the workin' threads tidy so it doesn't eat your server's lunch

### Cookin' the Dogs
- Pick your minigame style—we've got three options:
  - Let it pick automatically, or go with `qb-minigames` if ya have it
  - Fancy HTML/JavaScript cookin' game with a heat bar and everythin'
  - Or just a basic Lua QTE if you're not feelin' fancy
- The minigame actually matters—mess it up and you get dodgy hotdogs:
  - Perfect cookin' (no mess-ups) = Exotic quality, top dollar
  - One mistake = Good quality, still decent
  - Two mistakes = Undercooked, cheaper
  - Three or more = Burnt to a crisp, useless, nobody buys it
- There's a combo thing too—nail it a few times in a row and you can bounce back from mistakes
- Nice grill-themed bar showin' from red (undercooked) through green (perfect) to black (burnt)

### The Money Side of Things
- **Different Customers**: Every person who stops by is different:
  - Sound fella: Pays 20% more, buys bigger portions
  - Normal Joe: Standard deal
  - Picky one: Pays less, wants decent quality, smaller amounts
  - Hungry type: Pays a bit more, wants loads of it
  - And some folks just won't buy dodgy stuff depending on who they are
- **Time of Day Matters**: 
  - Breakfast rush (6am-12pm): Everybody wants hotdogs, prices up
  - Lunch (12pm-2pm): Peak time
  - Afternoon dip (2pm-5pm): Quiet stretch
  - Dinner rush (5pm-8pm): Goes mad again
  - Late night (8pm-6am): Dead quiet
- **See What You're Gettin'**: For each offer you make, the UI shows you:
  - Who you're sellin' to (their type)
  - What the demand's at right now
  - Green if it's a good time, red if it's not lookin' great
  - The actual percentage change, so you know what's what
- Customers'll tell ya to jog on if they don't like the quality vs. the price

### Quality of Life
- Sound effects so you know what's happenin'
- Supports 12 languages, includin' Irish for us lot
- Works with prompts or targets, whatever you fancy
- Only runs what it needs to when you're actually workin'

### Tweak It How You Like
Everything's configurable in `config.lua`:
- How many rounds in the cookin' game, how long ya got, how many mess-ups before you lose
- How often the combo kicks in
- How fast the heat bar moves, how big the good zone is
- How bad the different quality levels gotta be
- Customer type probabilities and how much they affect prices
- Demand multipliers for each time period

## How to Get It Set Up
1. Chuck the `qb-hotdogjob` folder in your resources
2. Add `ensure qb-hotdogjob` to your server.cfg
3. Open up `config.lua` and fiddle with it if ya want
4. Make sure you've got `qb-core` runnin'

## What You'll Need
- QBCore Framework
- interact-sound for the menus
- qb-minigames is grand if ya have it, but not essential
- qb-target but not essential

# License

    QBCore Framework
    Copyright (C) 2021 Joshua Eger

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>
