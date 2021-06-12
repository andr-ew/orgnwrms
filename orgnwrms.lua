include 'orgn/orgn'
include 'wrms/wrms'
w = { init = init }

function init()
    orgn.init()
    orgn_:init()
    w.init()
end


