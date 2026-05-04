Config = Config or {}
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true'

-- Job Configuration
Config.RequireJob = false -- Set to true if job is required, false if anyone can use it
Config.JobName = 'hotdog' -- The job name required to use the hotdog stand

-- UI Configuration
Config.ShowTextPrompts = true -- Set to true to show text prompts near the stand
Config.TextDisplayType = 'html' -- Options: 'qb-core' (qb-core DrawText), 'html' (NUI HTML display - recommended), or '3d' (world text)
Config.UISounds = true -- Toggle UI sound feedback (offer chimes and selling on/off tones)

-- Minigame Configuration
-- Provider options:
-- 'auto'        : Try qb-minigames first, then html minigame, then built-in fallback.
-- 'qb-minigames': Force qb-minigames only.
-- 'html'        : Force html/js cooking minigame only.
-- 'builtin'     : Force built-in minigame only.
Config.Minigame = {
    Provider = 'html',
    HTML = {
        Rounds = 4,
        TimePerRoundMs = 2200,
        MaxFaults = 2,
        ComboBonusEvery = 3, -- Recover 1 fault after this many consecutive perfect hits
        BaseWindow = 0.22, -- Starting perfect zone size (0.0-1.0)
        WindowStep = 0.03, -- How much the zone shrinks per round
        MinWindow = 0.11,  -- Smallest possible perfect zone
        HeatSpeedMin = 0.75,
        HeatSpeedMax = 1.3,
    },
    BuiltIn = {
        Rounds = 4,          -- Number of rounds
        TimePerRoundMs = 2200, -- Time window per round
        MaxFaults = 2,       -- If faults exceed this value, minigame is considered failed
    },
}

-- Cooking Outcomes (fault-based doneness mapping)
Config.CookingOutcomes = {
    PerfectMaxFaults = 0,      -- exotic quality
    GoodMaxFaults = 1,         -- rare quality
    UndercookedMaxFaults = 2,  -- common quality
    -- Anything above UndercookedMaxFaults is treated as burnt (no hotdog made)
}

-- Customer personality modifiers (weighted random selection)
Config.CustomerPersonalities = {
    {
        Name = 'friendly',
        Weight = 25,
        PriceMultiplier = 1.10,
        AmountMultiplier = 1.00,
        RejectChance = 0.04,
    },
    {
        Name = 'normal',
        Weight = 45,
        PriceMultiplier = 1.00,
        AmountMultiplier = 1.00,
        RejectChance = 0.10,
    },
    {
        Name = 'picky',
        Weight = 20,
        PriceMultiplier = 0.90,
        AmountMultiplier = 1.00,
        RejectChance = 0.20,
    },
    {
        Name = 'hungry',
        Weight = 10,
        PriceMultiplier = 1.05,
        AmountMultiplier = 1.20,
        RejectChance = 0.08,
    },
}

-- Demand multipliers by in-game hour (24h)
Config.DemandByHour = {
    { Label = 'breakfast', StartHour = 6, EndHour = 10, Multiplier = 1.15 },
    { Label = 'lunch', StartHour = 11, EndHour = 15, Multiplier = 1.25 },
    { Label = 'afternoon', StartHour = 15, EndHour = 18, Multiplier = 1.00 },
    { Label = 'dinner', StartHour = 18, EndHour = 22, Multiplier = 1.20 },
    { Label = 'late-night', StartHour = 22, EndHour = 3, Multiplier = 0.90 },
    { Label = 'early-morning', StartHour = 3, EndHour = 6, Multiplier = 0.80 },
}

-- Economic Configuration
Config.StandDeposit = 250 -- Deposit required to rent a hotdog stand

-- Reputation System
Config.MyLevel = 1 -- Current player level (calculated dynamically)
Config.MaxReputation = 200 -- Maximum reputation points

-- Reputation Thresholds (for level calculation)
Config.ReputationThresholds = {
    [1] = 0,      -- Level 1: 0-49 rep
    [2] = 50,     -- Level 2: 50-99 rep
    [3] = 100,    -- Level 3: 100-199 rep
    [4] = 200,    -- Level 4: 200+ rep
}

Config.Locations = {
    ["take"] = {
        coords = vector4(39.31, -1005.54, 29.48, 240.57),
    },
    ["spawn"] = {
        coords = vector4(38.15, -1001.65, 29.44, 342.5),
    },
}

-- Stock Configuration
Config.Stock = {
    ["exotic"] = {
        Current = 0,
        Max = {
            [1] = 15,
            [2] = 30,
            [3] = 45,
            [4] = 60,
        },
        Label = Lang:t("info.label_a"),
        Price = {
            [1] = {
                min = 8,
                max = 12,
            },
            [2] = {
                min = 9,
                max = 13,
            },
            [3] = {
                min = 10,
                max = 14,
            },
            [4] = {
                min = 11,
                max = 15,
            },
        }
    },
    ["rare"] = {
        Current = 0,
        Max = {
            [1] = 15,
            [2] = 30,
            [3] = 45,
            [4] = 60,
        },
        Label = Lang:t("info.label_b"),
        Price = {
            [1] = {
                min = 6,
                max = 9,
            },
            [2] = {
                min = 7,
                max = 10,
            },
            [3] = {
                min = 8,
                max = 11,
            },
            [4] = {
                min = 9,
                max = 12,
            },
        }
    },
    ["common"] = {
        Current = 0,
        Max = {
            [1] = 15,
            [2] = 30,
            [3] = 45,
            [4] = 60,
        },
        Label = Lang:t('info.label_c'),
        Price = {
            [1] = {
                min = 4,
                max = 6,
            },
            [2] = {
                min = 5,
                max = 7,
            },
            [3] = {
                min = 6,
                max = 9,
            },
            [4] = {
                min = 7,
                max = 9,
            },
        }
    },
}

-- Quality Reputation Increments
Config.ReputationIncrements = {
    exotic = 3,
    rare = 2,
    common = 1,
}
