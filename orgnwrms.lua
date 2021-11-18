include 'orgn/orgn' 
include 'wrms/wrms'
w = { init = init }

function init()
    orgn.init()

    params:set('demo start/stop', 0)

    w.init()
    orgn_:init()
end

function cleanup() 
    params:write()
end
