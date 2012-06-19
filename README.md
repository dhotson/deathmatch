Deathmatch
====

A multiplayer top down deathmatch game.

Dependencies
----

    gem install em-websocket

To start
----

Start the server:

    ruby deathmatch.rb

Serve up statics:

    python -m SimpleHTTPServer

Open in a browser:

    http://127.0.0.1:8000


Dev
----

You'll need guard and coffeescript:

    gem install guard guard-coffeescript

Use guard to recompile coffeescript:

    guard

Credits
----

By Dennis Hotson (@dhotson) and Paul Annesley (@pda)
with some help from Rich Healey (@richo), Josh Amos (@joshamos) and Michael Morris (@mtcmorris).

Contributions
----

Contributions are welcome. :-)

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
