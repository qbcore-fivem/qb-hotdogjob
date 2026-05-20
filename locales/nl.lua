local Translations = {
    error = {
        no_money = 'Je hebt niet genoeg geld',
        too_far = 'Je bent te ver van je stand',
        no_stand = 'Je hebt geen hotdog stand',
        cust_refused = 'Klant geweigerd!',
        no_stand_found = 'We vinden je hotdog stand niet terug, je krijgt je waarbog niet terug!',
        no_more = 'Je hebt geen %{value} meer hierover in de raad.',
        deposit_notreturned = 'Je hebt geen hotdog stand meer',
        no_dogs = 'Je hebt geen hotdogs',
    },
    success = {
        deposit = 'Je hebt een borg van $%{deposit} betaald!',
        deposit_returned = 'Je borg van $%{deposit} is teruggestort!',
        sold_hotdogs = '%{value} x Hotdog(s) verkocht voor $%{value2}',
        made_hotdog = 'Je hebt %{value} Hot Dogs gemaakt',
        made_luck_hotdog = 'Je hebt %{value} x %{value2} Hot Dogs gemaakt',
    },
    info = {
        command = "Stand verwijderen (Admin Only)",
        blip_name = 'Hotdog Stand',
        start_working = '[E] Start met werken',
        start_work = 'Start met werken',
        stop_working = '[E] Stop met werken',
        stop_work = 'Stop met werken',
        grab_stall = '[~g~G~s~] Pak kraam vast',
        drop_stall = '[~g~G~s~] Laat kraam los',
        grab = 'Pak kraam',
        prepare = 'Hotdog bereiden',
        toggle_sell = 'Verkopen',
        selling_prep = '[~g~E~s~] Hotdog bereiden [Sale: ~g~verkopen~w~]',
        not_selling = '[~g~E~s~] Hotdog bereiden [Sale: ~r~niet verkopen~w~]',
        sell_dogs = '[~g~7~s~] Verkoop %{value} x HotDogs voor $%{value2} / [~g~8~s~] afwijzen',
        sell_dogs_target = 'Verkoop %{value} x HotDogs voor $%{value2}',
        admin_removed = "Hot Dog Stand verwijderd",
        label_a = "Perfect (A)",
        label_b = "goed (B)",
        label_c = "matig (C)",
    },
        keymapping = {
        gkey = 'Laat je kraam los',
        
    }
}

if GetConvar('qb_locale', 'en') == 'nl' then
    Lang = Lang or Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
