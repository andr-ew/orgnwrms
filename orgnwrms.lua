--  ======  ======   ======  ==   =
-- =      = =     = =        = =  =
-- =      = ======  =     == =  = =
--  ======  =     =  ======  =   ==
--  _       ___________ ___  _____ 
-- | | /| / / ___/ __ `__ \/ ___/  
-- | |/ |/ / /  / / / / / (__  )   
-- |__/|__/_/  /_/ /_/ /_/____/    
--
-- orgn + wrms
--
-- version 2.0 @andrew
-- https://norns.community/
-- authors/andrew/orgnwrms
--
-- required: 
-- orgn + wrms installed
-- midi keyboard or grid
--
-- the two bottom right keys on the
-- grid switch the screen between
-- orgn & wrms. the bottom row also
-- has a few parameter mappings
-- for wrms
--
-- full grid documentation available
-- on norns.community

--global variables

pages = 3 --you can add more pages here for the norns encoders

--adjust these variables for midigrid / nonvari grids
g = grid.connect()
grid_width = (g and g.device and g.device.cols >= 16) and 16 or 8
varibright = (g and g.device and g.device.cols >= 16) and true or false

--external libs

tab = require 'tabutil'
cs = require 'controlspec'
mu = require 'musicutil'
pattern_time = require 'pattern_time'

--git submodule libs

nest = include 'lib/nest/core'
Key, Enc = include 'lib/nest/norns'
Text = include 'lib/nest/text'
Grid = include 'lib/nest/grid'

multipattern = include 'lib/nest/util/pattern-tools/multipattern'
of = include 'lib/nest/util/of'
to = include 'lib/nest/util/to'
PatternRecorder = include 'lib/nest/examples/grid/pattern_recorder'

tune, Tune = include 'orgn/lib/tune/tune' 
tune.setup { presets = 8, scales = include 'orgn/lib/tune/scales' }

cartographer, Slice = include 'lib/cartographer/cartographer'
crowify = include 'lib/crowify/lib/crowify' .new(0.01)

--script lib files

orgn, orgn_gfx = include 'orgn/lib/orgn'      --engine params & graphics
demo = include 'orgn/lib/demo'                --egg
Orgn = include 'orgn/lib/ui'                  --nest v2 UI components (norns screen / grid)
map = include 'orgn/lib/params'               --create script params
m = include 'orgn/lib/midi'                   --midi keyboard input

wrms = include 'wrms/lib/globals'      --saving, loading, values, etc
sc, reg = include 'wrms/lib/softcut'   --softcut utilities
wrms_gfx = include 'wrms/lib/graphics' --graphics & animations
include 'wrms/lib/params'              --create params
Wrms = include 'wrms/lib/ui'           --nest v2 UI components

engine.name = "Orgn"

--set up global patterns

function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

pattern, mpat = {}, {}
for i = 1,5 do
    pattern[i] = pattern_time.new() 
    mpat[i] = multipattern.new(pattern[i])
end

--set up nest v2 UI

local App = {}
local page = 2

local function Wrm_macros(args)
    local wrm = args.wrm or 1
    local left = args.left
    local top = 8

    local _rec = Grid.toggle()

    local blinktime = 0.2
    local _trans = to.pattern(mpat, '<< >> grid '..wrm, Grid.trigger, function() 
        return {
            x = { left + 2, left + 3 }, y = top, edge = 'falling',
            fingers = { 1, 2 }, count = { 1, 2 },
            lvl = {
                4,
                function(s, draw)
                    draw(15)
                    clock.sleep(blinktime)
                    draw(4)
                end
            },
            action = function(v, t, d, add, rem, l)
                blinktime = sc.slew(wrm, t[add]) / 2

                print('list')
                tab.print(l)

                if #l == 2 then
                    params:set('dir '..wrm, params:get('dir '..wrm)==1 and 2 or 1)
                else
                    params:delta('oct '..wrm, add==2 and 1 or -1)
                end
            end
        }
    end)

    return function()
        _rec{
            x = left, y = top, edge = 'falling',
            lvl = { sc.punch_in[wrm].recorded and 8 or 4, 15 },
            state = { params:get('rec '..wrm) },
            action = function(v, t)
                if t < 0.5 then params:set('rec '..wrm, v)
                else params:delta('clear '..wrm, 1) end
            end
        }
        _trans()
    end
end

function App.grid()
    local _orgn = Orgn.grid{ 
        wide = grid_width > 8, 
        varibright = varibright,
        no_last_row = true,
    }

    local _page = Grid.number()

    local _macros = {}
    if grid_width > 8 then
        for i = 1,2 do _macros[i] = Wrm_macros{ wrm = i, left = ({ 1,8 })[i] } end
    else
        _macros[1] = Wrm_macros{ wrm = 2, left = 1 }
    end

    return function()
        _orgn()

        _page{
            x = grid_width > 8 and { 15, 16 } or { 7, 8 }, y = 8, lvl = { 4, 15 },
            state = { 
                page, 
                function(v) 
                    page = v  
                    nest.screen.make_dirty()
                end 
            },
        }
        
        if grid_width > 8 then
            for _,_macro in ipairs(_macros) do _macro() end
        else
            _macros[1]()
        end
    end
end

function App.norns()
    local _orgn = Orgn.norns()
    local _wrms = Wrms.vanilla()

    return function()
        if page==1 then _orgn()
        elseif page==2 then _wrms() end
    end
end

local _app = { grid = App.grid(), norns = App.norns() }
nest.connect_grid(_app.grid, g, 240)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns, 24)

--init/cleanup

function init()
    wrms.setup()
    orgn.init()

    params:read()
    params:set('demo start/stop', 0)
    --for some reason the demo crashes all of norns in orgnwrms, so let's not bother with that
    params:hide('demo start/stop')

    wrms.load()

    params:bang()
end

function cleanup() 
    wrms.save()
    params:write()
end
