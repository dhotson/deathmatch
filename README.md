Deathmatch
====

A multiplayer top down deathmatch game.
Made in 48 hours at Railscamp 11 on the Gold Coast.

[Screenshot](http://i.imgur.com/AN0y1.png "Screenshot")

Dependencies
----

Deathmatch requires Ruby 1.9.

If you're using bundler

    bundle install

Otherwise, install dependencies manually with rubygems

    gem install em-websocket

To start
----

Start the server:

    ruby deathmatch.rb

Serve up statics:

    python -m SimpleHTTPServer

Open in a browser:

    http://127.0.0.1:8000


Developing Deathmatch
----

You'll need guard and coffeescript:

    gem install guard guard-coffeescript

Use guard to recompile coffeescript:

    guard

Credits
----

By [Dennis Hotson](https://github.com/dhotson) and [Paul Annesley](https://github.com/pda)
with help from [Rich Healey](https://github.com/richo), [Josh Amos](https://github.com/joshamos) and [Michael Morris](https://github.com/mtcmorris).

License
----

MIT

Contributions
----

Contributions are welcome. :-)

1. Fork the project
2. Create a feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request