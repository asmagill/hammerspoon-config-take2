AnyComplete
===========

Provides autocomplete functionality anywhere you can type in text.

Based heavily on Nathan Cahill's code at https://github.com/nathancahill/Anycomplete and some of the enhancement requests.


### Installation

Download `init.lua` and `docs.json` and do the following:

~~~sh
cd ~/.hammerspoon/Spoons
mkdir AnyComplete.spoon
cd AnyComplete.spoon
mv ~/Downloads/{init.lua,docs.json} . -- or wherever you downloaded the files
~~~

### Usage

Add the following to your Hammerspoon `init.lua` file:

~~~lua
local AnyComplete = hs.loadSpoon("AnyComplete")
AnyComplete:bindHotkeys{ toggle = { { "cmd", "alt", "ctrl" }, "g" } }
~~~

### Contents


##### Module Methods
* <a href="#bindHotkeys">AnyComplete:bindHotkeys(mapping) -> self</a>
* <a href="#hide">AnyComplete:hide() -> self</a>
* <a href="#show">AnyComplete:show() -> self</a>
* <a href="#start">AnyComplete:start() -> self</a>
* <a href="#stop">AnyComplete:stop() -> self</a>
* <a href="#toggle">AnyComplete:toggle() -> self</a>

##### Module Variables
* <a href="#queryDebounce">AnyComplete.queryDebounce</a>
* <a href="#queryDefinitions">AnyComplete.queryDefinitions[]</a>
* <a href="#querySite">AnyComplete.querySite</a>

- - -

### Module Methods

<a name="bindHotkeys"></a>
~~~lua
AnyComplete:bindHotkeys(mapping) -> self
~~~
Binds hotkeys for the AnyComplete spoon

Parameters:
 * `mapping` - A table containing hotkey modifier/key details for one or more of the following commands:
   * "show"   - Show the AnyComplete chooser window
   * "hide"   - Hide the AnyComplete chooser window
   * "toggle" - Toggles the visibility of the AnyComplete window

Returns:
 * the AnyComplete spoon object

Notes:
 * the `mapping` table is a table of one or more key-value pairs of the format `command = { { modifiers }, key }` where:
   * `command`   - is one of the commands listed above
   * `modifiers` - is a table containing keyboard modifiers, as specified in `hs.hotkey.bind()`
   * `key`       - is a string containing the name of a keyboard key, as specified in `hs.hotkey.bind()`

- - -

<a name="hide"></a>
~~~lua
AnyComplete:hide() -> self
~~~
Hides the AnyComplete chooser window.

Parameters:
 * None

Returns:
 * the AnyComplete spoon object

- - -

<a name="show"></a>
~~~lua
AnyComplete:show() -> self
~~~
Shows the AnyComplete chooser window.

Parameters:
 * None

Returns:
 * the AnyComplete spoon object

Notes:
 * Automatically invokes [AnyComplete:start()](#start) if this has not already been done.

- - -

<a name="start"></a>
~~~lua
AnyComplete:start() -> self
~~~
Readys the chooser interface for the AnyComplete spoon

Parameters:
 * None

Returns:
 * the AnyComplete spoon object

Notes:
 * This method is included to conform to the expected Spoon format; it will automatically be invoked by [AnyComplete:show](#show) if necessary.

- - -

<a name="stop"></a>
~~~lua
AnyComplete:stop() -> self
~~~
Removes the chooser interface for the NonjourLauncher spoon and any lingering service queries

Parameters:
 * None

Returns:
 * the AnyComplete spoon object

Notes:
 * This method is included to conform to the expected Spoon format; in general, it should be unnecessary to invoke this method directly.

- - -

<a name="toggle"></a>
~~~lua
AnyComplete:toggle() -> self
~~~
Toggles the visibility of the AnyComplete chooser window.

Parameters:
 * None

Returns:
 * the AnyComplete spoon object

Notes::
 * If the chooser window is currently visible, this method will invoke [AnyComplete:hide](#hide); otherwise invokes [AnyComplete:show](#show).

### Module Variables

<a name="queryDebounce"></a>
~~~lua
AnyComplete.queryDebounce
~~~
A number specifying the amount of time in seconds that the keyboard must be idle before performing a new query for possibilit completions. Set to 0 to perform a query after every keystroke. Defaults to 0.3.

Notes:
 * it has been suggested by some of the issues posted at https://github.com/nathancahill/Anycomplete that Google may rate limit or even block your IP address if it detects too many queries in a short period of time. This has not been confirmed in any terms of service, nor is there any detail as to how may queries over what period of time is considered "too many", but this variable is provided as a way of reducing the number of queries performed.

- - -

<a name="queryDefinitions"></a>
~~~lua
AnyComplete.queryDefinitions[]
~~~
A table containing site definitions for completion queries.

This table contains key-value pairs defining the site defintions for completion queries. Each key is a string specifying the shorthand name for a completion site, and each value is a table containing the following key-value pairs:
 * `title`       - a string specifying the title to display at the top of the choosers during completion lookup
 * `acQuery`     - a string specifying the URL for perfoming the actual completion query. Use `%s` as a placeholder to specify where the current value in the chooser query field should be inserted.
 * `searchQuery` - a string specifying the URL to use when the user wants to open a web page with the search results for the entry specified, triggered by holding down the shift key when making your selection.
 * `acParser`    - a function which takes as its sole argument the results from the http query and returns a chooser table where each entry is a table of the form `{ text = "possibility" }`.

Notes:
 * definitions for Google ("google") and DuckDuckGo ("duckduckgo") are already defined.

- - -

<a name="querySite"></a>
~~~lua
AnyComplete.querySite
~~~
A string specifying the key for the site definition to use when performing web queries for autocompletion possibilities. Defaults to "duckduckgo"

Notes:
 * the string must match the key of a definition in [AnyComplete.queryDefinitions](#queryDefinitions) and assiging a new value will generate an error if the definition does not exist -- make sure to add your customizations to `AnyComplete.queryDefinitions` before setting this to a value other than one of the built in defaults.

- - -

### License

>     The MIT License (MIT)
>
> Copyright (c) 2020 Aaron Magill
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>


