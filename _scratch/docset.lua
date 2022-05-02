--
-- Requirements: hs.webview -- currently a proposed module addition
--                  (see https://github.com/Hammerspoon/hammerspoon/pull/544)
--               luarocks-5.3, lsqlite3 lua-rock, and sqlite3 installed with extension support
--                  (stock 10.11 sqlite3 doesn't have this... not sure about earlier OS X's,
--                  but the brew versions work)
--               Uncompressed Hammerspoon.docset (Dash 2 version will work, not sure yet how to
--                  uncompress Dash 3 version yet...)
--
-- Update _rootPath to match where your docset is located
-- Update package.loadlib line to match your sqlite3 library
--
-- CMD-F when webview is front window will prompt for a search term

local module = {}
local _rootPath = "/Users/amagill/Documents/Hammerspoon/Hammerspoon.docset"
local _baseURL  = "file://".._rootPath.."/Contents/Resources/Documents"

local w = require("hs.webview")

local getSearchData = function(_root)
--     package.loadlib("/usr/local/opt/sqlite/lib/libsqlite3.dylib","*")
--     local l = require("lsqlite3")
    local l = require("hs.sqlite3")

    local _path  = _root.."/Contents/Resources/docSet.dsidx"

    local db = l.open(_path)

    local searchData = {}
    for row in db:nrows("SELECT * FROM searchindex") do
        table.insert(searchData, {
            id = row.id,
            name = row.name,
            kind = row.type,
            path = row.path,
        })
    end

    db:close()

    return searchData
end

local dataSet = getSearchData(_rootPath)

local webView

local doSearch = function(message)
--     print(inspect(message))
    message = tostring(message.body)
    local results = {}
    for i, v in ipairs(dataSet) do
        if v.name:match(message) then
            table.insert(results, v)
        end
    end

    local htmlResults = [[
<html>
    <head><title>Dash Search Results</title></head>
    <body>
        <h3>Search for ']]..message..[[':</h3>
        <hr>
]]

    if (#results == 0) then
        htmlResults = htmlResults..[[
        <i>No results found</i>
]]
    else
        htmlResults = htmlResults.."<table>"
        for i,v in ipairs(results) do
            htmlResults = htmlResults..[[
<tr><td>]]..v.kind..[[</td><td><a href="]].._baseURL.."/"..v.path..[[">]]..v.name..[[</a></td></tr>
]]
        end
        htmlResults = htmlResults.."</table>"
    end

    htmlResults = htmlResults..[[
        <hr>
        <div align="right"><i>Search performed at: ]]..os.date()..[[</i></div>
    </body>
</html>
]]

    webView:html(htmlResults, _baseURL)
end

local ucc = w.usercontent.new("dashamajig"):injectScript({ source = [[
function KeyPressHappened(e)
{
  if (!e) e=window.event;
  var code;
  if ((e.charCode) && (e.keyCode==0))
    code = e.charCode ;
  else
    code = e.keyCode;
//  console.log(code) ;
  if ((code == 102) && e.metaKey) {
      var textMesg = window.prompt("Enter a search term:","") ;
      if (textMesg != null) {
          try {
              webkit.messageHandlers.dashamajig.postMessage(textMesg);
          } catch(err) {
              console.log('The controller does not exist yet');
          }
      }
      return false ;
  } else {
      return true ;
  }
}

document.onkeypress = KeyPressHappened;
]], mainFrame = true, injectionTime = "documentStart"}):setCallback(doSearch)

webView = w.new({ x = 50, y = 50,h = 500, w = 900 }, { developerExtrasEnabled = true }, ucc)
                        :windowStyle(1+2+4+8)
                        :allowTextEntry(true)
                        :url(_baseURL.."/index.html")
                        :allowGestures(true)
                        :show()

-- For debugging purposes... may remove
module.webView = webView
module.doSearch = doSearch
module.ucc = ucc
module.dataSet = dataSet
module._rootPath = _rootPath
return module
