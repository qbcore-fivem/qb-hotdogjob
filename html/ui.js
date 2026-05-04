var UIVisible = false;
var LastSellPrompt = null;
var SellHighlightTimeout = null;
var LastSellingState = null;
var AudioContextRef = null;
var UISoundsEnabled = true;
var CookingAnimFrame = null;
var CookingGame = {
    active: false,
    rounds: 4,
    timePerRoundMs: 2200,
    maxFaults: 2,
    baseWindow: 0.22,
    windowStep: 0.03,
    minWindow: 0.11,
    heatSpeedMin: 0.75,
    heatSpeedMax: 1.3,
    round: 1,
    faults: 0,
    heat: 0.5,
    direction: 1,
    speed: 1.0,
    windowStart: 0.4,
    windowEnd: 0.6,
    roundEndAt: 0,
    lastTick: 0,
    combo: 0,
    comboBonusEvery: 3,
    comboBonusArmed: false,
    comboMessageUntil: 0,
};

function GetAudioContext() {
    if (AudioContextRef) return AudioContextRef;

    var Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;

    AudioContextRef = new Ctx();
    return AudioContextRef;
}

function PlayTone(freq, durationMs, volume, type) {
    if (!UISoundsEnabled) return;

    var ctx = GetAudioContext();
    if (!ctx) return;

    if (ctx.state === 'suspended') {
        ctx.resume().catch(function() {});
    }

    var now = ctx.currentTime;
    var duration = Math.max((durationMs || 100) / 1000, 0.03);
    var gain = ctx.createGain();
    var osc = ctx.createOscillator();

    osc.type = type || 'sine';
    osc.frequency.setValueAtTime(freq || 440, now);

    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(Math.max(volume || 0.02, 0.0001), now + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(now);
    osc.stop(now + duration + 0.01);
}

function PlayOfferSound() {
    PlayTone(880, 75, 0.02, 'triangle');
    setTimeout(function() {
        PlayTone(1175, 90, 0.018, 'triangle');
    }, 70);
}

function PlaySellingOnSound() {
    PlayTone(620, 80, 0.018, 'sine');
    setTimeout(function() {
        PlayTone(930, 110, 0.02, 'sine');
    }, 75);
}

function PlaySellingOffSound() {
    PlayTone(720, 90, 0.018, 'sine');
    setTimeout(function() {
        PlayTone(460, 120, 0.018, 'sine');
    }, 80);
}

function PlayCookHitSound() {
    PlayTone(780, 80, 0.02, 'triangle');
}

function PlayCookMissSound() {
    PlayTone(280, 120, 0.02, 'sawtooth');
}

function Clamp01(value) {
    return Math.max(0, Math.min(1, value));
}

function SendMinigameResult(quit, faults) {
    var payload = JSON.stringify({ quit: !!quit, faults: Math.max(faults || 0, 0) });
    $.post('https://' + GetParentResourceName() + '/minigameResult', payload);
}

function ResetCookingRound() {
    var windowSize = Math.max(CookingGame.baseWindow - ((CookingGame.round - 1) * CookingGame.windowStep), CookingGame.minWindow);
    var center = (Math.random() * (1.0 - windowSize)) + (windowSize * 0.5);

    CookingGame.windowStart = center - (windowSize * 0.5);
    CookingGame.windowEnd = center + (windowSize * 0.5);
    CookingGame.heat = Math.random();
    CookingGame.direction = Math.random() > 0.5 ? 1 : -1;
    CookingGame.speed = CookingGame.heatSpeedMin + (Math.random() * Math.max(CookingGame.heatSpeedMax - CookingGame.heatSpeedMin, 0.01));
    CookingGame.roundEndAt = performance.now() + CookingGame.timePerRoundMs;
}

function StopCookingMinigame() {
    CookingGame.active = false;
    if (CookingAnimFrame) {
        cancelAnimationFrame(CookingAnimFrame);
        CookingAnimFrame = null;
    }
    $('#cooking-minigame').removeClass('active').hide();
}

function CompleteCookingMinigame(quit) {
    var faults = CookingGame.faults;
    StopCookingMinigame();
    SendMinigameResult(quit, faults);
}

function UpdateCookingUI() {
    var roundEl = $('#cooking-round');
    var faultsEl = $('#cooking-faults');
    var comboEl = $('#cooking-combo');
    var timerEl = $('#cooking-timer');
    var subtitleEl = $('#cooking-subtitle');
    var windowEl = $('#cooking-window');
    var cursorEl = $('#cooking-cursor');

    var remainingMs = Math.max(CookingGame.roundEndAt - performance.now(), 0);
    roundEl.text('Round ' + CookingGame.round + '/' + CookingGame.rounds);
    faultsEl.text('Faults ' + CookingGame.faults + '/' + CookingGame.maxFaults);
    comboEl.text('Combo x' + CookingGame.combo);
    timerEl.text((remainingMs / 1000).toFixed(1) + 's');

    if (performance.now() < CookingGame.comboMessageUntil) {
        subtitleEl.text('COMBO BONUS! Fault -1');
    } else {
        subtitleEl.text('Press E while the marker is in the green zone');
    }

    windowEl.css({
        left: (CookingGame.windowStart * 100) + '%',
        width: ((CookingGame.windowEnd - CookingGame.windowStart) * 100) + '%',
    });

    cursorEl.css({
        left: (CookingGame.heat * 100) + '%',
    });
}

function CookingTick(timestamp) {
    if (!CookingGame.active) return;

    if (!CookingGame.lastTick) {
        CookingGame.lastTick = timestamp;
    }

    var delta = Math.min((timestamp - CookingGame.lastTick) / 1000, 0.05);
    CookingGame.lastTick = timestamp;

    CookingGame.heat += CookingGame.direction * CookingGame.speed * delta;
    if (CookingGame.heat <= 0) {
        CookingGame.heat = 0;
        CookingGame.direction = 1;
    } else if (CookingGame.heat >= 1) {
        CookingGame.heat = 1;
        CookingGame.direction = -1;
    }

    if (performance.now() >= CookingGame.roundEndAt) {
        CookingGame.faults += 1;
        PlayCookMissSound();

        if (CookingGame.faults > CookingGame.maxFaults) {
            CompleteCookingMinigame(true);
            return;
        }

        CookingGame.round += 1;
        if (CookingGame.round > CookingGame.rounds) {
            CompleteCookingMinigame(false);
            return;
        }

        ResetCookingRound();
    }

    UpdateCookingUI();
    CookingAnimFrame = requestAnimationFrame(CookingTick);
}

function StartCookingMinigame(data) {
    var cfg = (data && data.Config) || {};

    CookingGame.rounds = Math.max(parseInt(cfg.Rounds || 4, 10), 1);
    CookingGame.timePerRoundMs = Math.max(parseInt(cfg.TimePerRoundMs || 2200, 10), 600);
    CookingGame.maxFaults = Math.max(parseInt(cfg.MaxFaults || 2, 10), 0);
    CookingGame.baseWindow = Clamp01(cfg.BaseWindow || 0.22);
    CookingGame.windowStep = Math.max(cfg.WindowStep || 0.03, 0);
    CookingGame.minWindow = Clamp01(cfg.MinWindow || 0.11);
    CookingGame.heatSpeedMin = Math.max(cfg.HeatSpeedMin || 0.75, 0.2);
    CookingGame.heatSpeedMax = Math.max(cfg.HeatSpeedMax || 1.3, CookingGame.heatSpeedMin);
    CookingGame.comboBonusEvery = Math.max(parseInt(cfg.ComboBonusEvery || 3, 10), 1);

    CookingGame.active = true;
    CookingGame.round = 1;
    CookingGame.faults = 0;
    CookingGame.lastTick = 0;
    CookingGame.combo = 0;
    CookingGame.comboBonusArmed = false;
    CookingGame.comboMessageUntil = 0;

    $('#cooking-minigame').addClass('active').show();
    ResetCookingRound();
    UpdateCookingUI();

    if (CookingAnimFrame) {
        cancelAnimationFrame(CookingAnimFrame);
    }
    CookingAnimFrame = requestAnimationFrame(CookingTick);
}

$(document).ready(function(){
    document.documentElement.style.background = 'transparent';
    document.documentElement.style.backgroundColor = 'transparent';
    document.body.style.background = 'transparent';
    document.body.style.backgroundColor = 'transparent';

    window.addEventListener('message', function(event){
        var Data = event.data;

        if (Data && Data.action == "UpdateUI") {
            UpdateUI(Data);
        } else if (Data && Data.action == "ShowTextPrompt") {
            ShowTextPrompt(Data);
        } else if (Data && Data.action == "HideTextPrompt") {
            HideTextPrompt();
        } else if (Data && Data.action == "StartCookingMinigame") {
            StartCookingMinigame(Data);
        } else if (Data && Data.action == "StopCookingMinigame") {
            StopCookingMinigame();
        }
    });

    window.addEventListener('keydown', function(event) {
        if (!CookingGame.active) return;
        if (event.code !== 'KeyE') return;

        event.preventDefault();

        var inPerfectWindow = CookingGame.heat >= CookingGame.windowStart && CookingGame.heat <= CookingGame.windowEnd;
        if (inPerfectWindow) {
            CookingGame.combo += 1;

            if (CookingGame.combo > 0 && CookingGame.combo % CookingGame.comboBonusEvery === 0) {
                CookingGame.comboBonusArmed = true;
            }

            if (CookingGame.comboBonusArmed && CookingGame.faults > 0) {
                CookingGame.faults -= 1;
                CookingGame.comboBonusArmed = false;
                CookingGame.comboMessageUntil = performance.now() + 900;
            }

            PlayCookHitSound();
        } else {
            CookingGame.faults += 1;
            CookingGame.combo = 0;
            CookingGame.comboBonusArmed = false;
            PlayCookMissSound();
        }

        if (CookingGame.faults > CookingGame.maxFaults) {
            CompleteCookingMinigame(true);
            return;
        }

        CookingGame.round += 1;
        if (CookingGame.round > CookingGame.rounds) {
            CompleteCookingMinigame(false);
            return;
        }

        ResetCookingRound();
    });
});

function UpdateUI(data) {
    // Validate data structure
    if (!data) {
        console.error('[qb-hotdogjob] UI: Invalid data received');
        return;
    }

    if (data.IsActive) {
        if (data.Settings && data.Settings.UISounds !== undefined && data.Settings.UISounds !== null) {
            UISoundsEnabled = !!data.Settings.UISounds;
        }

        // Validate required data
        if (!data.Stock || !data.Level) {
            console.error('[qb-hotdogjob] UI: Missing Stock or Level data');
            return;
        }

        var wasVisible = UIVisible;
        if (!UIVisible) {
            $(".container").fadeIn(300);
            UIVisible = true;
        }

        // Update stock display
        $.each(data.Stock, function(i, stock){
            if (!stock) return;
            
            var Parent = $(".stock-list").find('[data-stock="'+i+'"]');
            if (Parent.length === 0) return;
            
            var currentStock = stock.Current || 0;
            var maxStock = (stock.Max && stock.Max[data.Level.lvl]) ? stock.Max[data.Level.lvl] : 0;
            
            // Update amount display
            var currentAmountSpan = Parent.find('.current-amount');
            var maxAmountSpan = Parent.find('.max-amount');
            
            if (currentAmountSpan.length > 0) {
                currentAmountSpan.text(currentStock);
            }
            if (maxAmountSpan.length > 0) {
                maxAmountSpan.text(maxStock);
            }
            
            // Update progress bar
            var progressFill = Parent.find('.progress-fill');
            if (progressFill.length > 0 && maxStock > 0) {
                var percentage = Math.min((currentStock / maxStock) * 100, 100);
                progressFill.css('width', percentage + '%');
                
                // Add low-stock class if stock is below 25%
                if (percentage < 25 && percentage > 0) {
                    Parent.addClass('low-stock');
                } else {
                    Parent.removeClass('low-stock');
                }
            }
        });

        // Update level display
        var levelElement = $("#my-level");
        if (levelElement.length > 0) {
            var level = data.Level.lvl || 1;
            var rep = (data.Level.rep !== undefined && data.Level.rep !== null) ? data.Level.rep : 0;
            levelElement.html('Level ' + level + ' • ' + rep + ' XP');
        }

        UpdateStatusIndicator(data.Controls);
        UpdateControls(data.Controls);
    } else {
        if (UIVisible) {
            $(".container").fadeOut(300);
            UIVisible = false;
        }

        UpdateStatusIndicator(null);
    }
}

function UpdateStatusIndicator(controls) {
    var statusPip = $('.status-pip');
    if (statusPip.length === 0) return;

    var isSelling = !!(controls && controls.IsSelling);

    if (LastSellingState !== null && LastSellingState !== isSelling) {
        if (isSelling) {
            PlaySellingOnSound();
        } else {
            PlaySellingOffSound();
        }
    }
    LastSellingState = isSelling;

    if (isSelling) {
        statusPip.addClass('is-selling');
    } else {
        statusPip.removeClass('is-selling');
    }
}

// Convert GTA color codes to HTML with colored spans
function ConvertColorCodesToHTML(text) {
    if (!text) return '';
    
    // GTA color code to HTML color mapping
    var colorMap = {
        '~r~': '#ff4444', // red
        '~g~': '#44ff44', // green
        '~b~': '#4444ff', // blue
        '~y~': '#ffff44', // yellow
        '~p~': '#ff44ff', // purple/magenta
        '~o~': '#ff8844', // orange
        '~c~': '#888888', // gray
        '~m~': '#444444', // dark gray
        '~u~': '#00000000', // black
        '~w~': '#ffffff', // white
        '~s~': '#ffffff', // default/stop (white)
    };
    
    var result = '';
    var currentColor = null;
    var i = 0;
    
    // Process text character by character
    while (i < text.length) {
        // Check for color codes (pattern: ~[a-z]~)
        var codeMatch = text.substr(i, 3).match(/^(~[a-z]~)/);
        
        if (codeMatch) {
            var code = codeMatch[1];
            
            if (code === '~s~') {
                // Close current color span
                if (currentColor) {
                    result += '</span>';
                    currentColor = null;
                }
            } else if (colorMap[code]) {
                // Close previous color if any
                if (currentColor) {
                    result += '</span>';
                }
                // Open new color span
                result += '<span style="color: ' + colorMap[code] + ';">';
                currentColor = colorMap[code];
            }
            i += 3;
        } else {
            var char = text.charAt(i);
            
            // Handle brackets - remove them but keep content
            if (char === '[' || char === ']') {
                i++;
            } else {
                // Add character as-is
                result += char;
                i++;
            }
        }
    }
    
    // Close any remaining open span
    if (currentColor) {
        result += '</span>';
    }
    
    return result;
}

function ShowTextPrompt(data) {
    if (!data || !data.text) {
        HideTextPrompt();
        return;
    }
    
    var textPrompt = $("#text-prompt");
    var textContent = $(".text-prompt-text");
    
    if (textPrompt.length === 0 || textContent.length === 0) {
        console.error('[qb-hotdogjob] UI: Text prompt elements not found');
        return;
    }
    
    // Convert GTA color codes to HTML and set text
    var coloredText = ConvertColorCodesToHTML(data.text);
    textContent.html(coloredText);
    
    // Show with animation
    if (!textPrompt.hasClass('active')) {
        textPrompt.addClass('active');
    }
}

function HideTextPrompt() {
    var textPrompt = $("#text-prompt");
    if (textPrompt.length > 0) {
        textPrompt.removeClass('active');
        // Clear text after animation
        setTimeout(function() {
            if (!textPrompt.hasClass('active')) {
                $(".text-prompt-text").html('');
            }
        }, 300);
    }
}

function CleanControlActionText(text) {
    var value = String(text || '');

    // Strip GTA color tags and bracket markers first.
    value = value.replace(/~[a-z]~/gi, '');
    value = value.replace(/[\[\]]/g, '');

    // Remove a leading single key hint like "G" or "E" if present.
    value = value.replace(/^\s*[A-Z0-9]\s+/i, '');

    return value.trim();
}

function UpdateControls(controls) {
    var controlsPanel = $("#controls-panel");
    if (controlsPanel.length === 0) return;

    var grabRow = $("#control-grab");
    var releaseRow = $("#control-release");
    var prepareRow = $("#control-prepare");
    var grabText = $("#control-grab-text");
    var releaseText = $("#control-release-text");
    var prepareText = $("#control-prepare-text");
    var sellText = $("#control-sell-text");
    var sellRow = $("#control-sell");

    if (!controls) {
        grabRow.hide();
        releaseRow.hide();
        prepareRow.hide();
        sellRow.hide();
        sellRow.removeClass('offer-active');
        LastSellPrompt = null;
        return;
    }

    if (grabText.length > 0 && controls.Grab) {
        grabText.text(CleanControlActionText(controls.Grab));
    }

    if (releaseText.length > 0 && controls.Release) {
        releaseText.text(CleanControlActionText(controls.Release));
    }

    if (prepareText.length > 0 && controls.Prepare) {
        prepareText.text(CleanControlActionText(controls.Prepare));
    }

    if (controls.ShowGrab) {
        grabRow.show();
    } else {
        grabRow.hide();
    }

    if (controls.ShowRelease) {
        releaseRow.show();
    } else {
        releaseRow.hide();
    }

    if (controls.ShowPrepare) {
        prepareRow.show();
    } else {
        prepareRow.hide();
    }

    if (sellText.length > 0 && controls.Sell) {
        sellText.html(ConvertColorCodesToHTML(String(controls.Sell)));
    }

    if (controls.ShowSell && controls.Sell) {
        var sellPrompt = String(controls.Sell);
        var isNewPrompt = LastSellPrompt !== sellPrompt;
        LastSellPrompt = sellPrompt;

        sellRow.show();

        if (isNewPrompt) {
            sellRow.removeClass('offer-active');
            if (SellHighlightTimeout) {
                clearTimeout(SellHighlightTimeout);
            }

            PlayOfferSound();

            // Delay re-adding class so CSS animation reliably retriggers.
            setTimeout(function() {
                sellRow.addClass('offer-active');
                SellHighlightTimeout = setTimeout(function() {
                    sellRow.removeClass('offer-active');
                }, 1600);
            }, 10);
        }
    } else {
        sellRow.hide();
        sellRow.removeClass('offer-active');
        LastSellPrompt = null;
    }
}
