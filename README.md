# fluent-plugin-jabber

Fluentd output plugin for XMPP(jabber) protocol.

## Installation

Add this line to your application's Gemfile:

    gem 'fluent-plugin-jabber'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-jabber

## Usage

See source for details.

### Fluentd config

    <match ...>
      type jabber

      # Pit( https://github.com/cho45/pit ) ID for user account information.
      # Need 'jid' and 'password' field.
      pit_id jabber

      # Output target JID. Currently multi user chat only.
      room test@conference.localhost/test
    </match>

### Message format

    {"body": "String for output"}

If 'body' field not set, the plugin raises error.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Changes

### 0.1.0(unreleased)

* Updated Gemfile
* Change file location to fluent plugin standard.
* Add format option
* Add test

### 0.0.1

* Initial release.
