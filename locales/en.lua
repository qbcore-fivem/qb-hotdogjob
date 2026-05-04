local Translations = {
    error = {
        no_money = 'You do not have enough money to pay the deposit',
        too_far = 'You are too far from your Hot Dog Stand',
        no_stand = 'You do not have a hotdog stand',
        cust_refused = 'Customer refused the offer!',
        no_stand_found = 'Your hot dog stand was not found. You will not receive your deposit back!',
        no_more = 'You cannot make any more %{value} hotdogs. Stock limit reached!',
        deposit_notreturned = 'You did not have a Hot Dog Stand to return',
        no_dogs = 'You do not have any hotdogs to sell. Prepare some first!',
        already_preparing = 'You are already preparing food!',
        minigame_unavailable = 'Minigame system is not available',
    },
    success = {
        deposit = 'You paid a $%{deposit} deposit for the hotdog stand!',
        deposit_returned = 'Your $%{deposit} deposit has been returned!',
        sold_hotdogs = 'You sold %{value} x Hotdog(s) for $%{value2}',
        made_hotdog = 'You made 1x %{value} Hot Dog',
        made_luck_hotdog = 'You made %{value} x %{value2} Hot Dogs',
    },
    info = {
        command = "Delete Hotdog Stand (Admin Only)",
        blip_name = 'Hotdog Stand',
        start_working = '[E] Start Working',
        start_work = 'Start Working',
        stop_working = '[E] Stop Working',
        stop_work = 'Stop Working',
        grab_stall = '[~g~G~s~] Grab Stall',
        drop_stall = '[~g~G~s~] Release Stall',
        grab = 'Grab Stall',
        prepare = 'Prepare Hotdog',
        toggle_sell = 'Toggle Selling',
        selling_prep = '[~g~E~s~] Prepare Hotdog [Sale: ~g~Selling~w~]',
        not_selling = '[~g~E~s~] Prepare Hotdog [Sale: ~r~Not Selling~w~]',
        sell_dogs = '[~g~7~s~] Sell %{value} x HotDog(s) for $%{value2} / [~r~8~s~] Reject',
        sell_dogs_target = 'Sell %{value} x HotDog(s) for $%{value2}',
        admin_removed = "Hot Dog Stand Removed",
        label_a = "Perfect Quality (A)",
        label_b = "Good Quality (B)",
        label_c = "Standard Quality (C)"
    },
    keymapping = {
        gkey = 'Let go of hotdog stand',
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
