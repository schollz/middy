-- middy demo
-- 
--
-- llllllll.co/t/middy

mi=include("middy/lib/middy")

function init()
  mi:init({log_level="debug",device=1})
  mi:init_menu()
end

function key(k,z)

end

function redraw()

end
