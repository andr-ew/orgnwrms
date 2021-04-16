o = include 'orgn/orgn'
w = include 'wrms/wrms'

function init()
    w.setup()
    params:bang()
    w.wrms_:init()
    w.sc.scoot()
end

function cleanup()
end
