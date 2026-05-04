local Translations = {
    error = {
        no_money = 'Níl dóthain airgid agat don táille/ You do not have enough money to pay the deposit',
        too_far = 'Tá tú ró-fhada ó do Bhiachóir Rósta Conaigh / You are too far from your Hot Dog Stand',
        no_stand = 'Níl biachóir rósta conaigh agat / You do not have a hotdog stand',
        cust_refused = 'Dhiúltaigh an custaiméir an tairiscint! / Customer refused the offer!',
        no_stand_found = 'Ní bhraistí do bhiachóir rósta conaigh. Ní bhfaighidh tú do táille ar ais! / Your hot dog stand was not found. You will not receive your deposit back!',
        no_more = 'Ní féidir leat níos mó %{value} róstaithe conaigh a dhéanamh. Sroichitear teorainn stoc! / You cannot make any more %{value} hotdogs. Stock limit reached!',
        deposit_notreturned = 'Ní raibh Biachóir Rósta Conaigh agat le filleadh / You did not have a Hot Dog Stand to return',
        no_dogs = 'Níl aon róstaí conaigh agat le díol. Réitigh cuid a thosú! / You do not have any hotdogs to sell. Prepare some first!',
        already_preparing = 'Tá tú ag réiteach bia cheana féin! / You are already preparing food!',
        minigame_unavailable = 'Níl an córas minigame ar fáil / Minigame system is not available',
    },
    success = {
        deposit = 'Dhíol tú táille $%{deposit} ar an róstaithe conaigh! / You paid a $%{deposit} deposit for the hotdog stand!',
        deposit_returned = 'Tugadh ar ais do tháille $%{deposit} duit! / Your $%{deposit} deposit has been returned!',
        sold_hotdogs = 'Dhíol tú %{value} x Róstaithe Conaigh ar $%{value2} / You sold %{value} x Hotdog(s) for $%{value2}',
        made_hotdog = 'Rinne tú 1x %{value} Róstaithe Conaigh / You made 1x %{value} Hot Dog',
        made_luck_hotdog = 'Rinne tú %{value} x %{value2} Róstaithe Conaigh / You made %{value} x %{value2} Hot Dogs',
    },
    info = {
        command = "Scrios an Róstaithe Conaigh (Cigire Amháin) / Delete Hotdog Stand (Admin Only)",
        blip_name = 'Róstaithe Conaigh / Hotdog Stand',
        start_working = '[E] Tosú ag Obair / Start Working',
        start_work = 'Tosú ag Obair / Start Working',
        stop_working = '[E] Stad ag Obair / Stop Working',
        stop_work = 'Stad ag Obair / Stop Working',
        grab_stall = '[~g~G~s~] Fáil Seilf / Grab Stall',
        drop_stall = '[~g~G~s~] Scaoil Seilf / Release Stall',
        grab = 'Fáil Seilf / Grab Stall',
        prepare = 'Róstaithe Conaigh a Réiteach / Prepare Hotdog',
        toggle_sell = 'Díolacháin a Scoránaigh / Toggle Selling',
        selling_prep = '[~g~E~s~] Róstaithe Conaigh a Réiteach [Sale: ~g~Díolacháin~w~] / [~g~E~s~] Prepare Hotdog [Sale: ~g~Selling~w~]',
        not_selling = '[~g~E~s~] Róstaithe Conaigh a Réiteach [Sale: ~r~Gan Díolacháin~w~] / [~g~E~s~] Prepare Hotdog [Sale: ~r~Not Selling~w~]',
        sell_dogs = '[~g~7~s~] Díol %{value} x Róstaithe Conaigh ar $%{value2} / [~r~8~s~] Diúltaigh / [~g~7~s~] Sell %{value} x HotDog(s) for $%{value2} / [~r~8~s~] Reject',
        sell_dogs_target = 'Díol %{value} x Róstaithe Conaigh ar $%{value2} / Sell %{value} x HotDog(s) for $%{value2}',
        admin_removed = "Róstaithe Conaigh Scriosta / Hot Dog Stand Removed",
        label_a = "Cáilíochta Foirfe (A) / Perfect Quality (A)",
        label_b = "Cáilíochta Maith (B) / Good Quality (B)",
        label_c = "Cáilíochta Caighdeánach (C) / Standard Quality (C)"
    },
    keymapping = {
        gkey = 'Scaoil breis ar bhiachóir rósta conaigh / Let go of hotdog stand',
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})