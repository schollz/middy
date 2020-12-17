-- midimidi
-- 
--
-- llllllll.co/t/midimidi

mi=include("midimidi/lib/midimidi")

function init()
  mi:init({log_level="debug",device=1})
  mi:init_menu()
end

function key(k,z)

end

function redraw()

end
