o = include 'orgn/orgn'
w = include 'wrms/wrms'

function init()
    w.setup()
    w.wrms_:init()
    params:bang()
end

function cleanup()
end
