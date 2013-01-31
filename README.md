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

      # Or, put JID/password directly(exclusive for pit_id)
      jid name@example.com
      password pa55w0rd

      # Output target JID. Currently multi user chat only.
      #
      # NOTE: Group chat could'nt accept nickname that already in used.
      # It cause "conflict: That nickname is registered by another person" error.
      # To prevent it, specify unique nickname per plugin definition.
      room test@conference.localhost/unique_nickname

      format Hello!\n${user.name} # ${user.name} replaced with record['user']['name']

      # Enable detailed log of XMPP4R
      jabber_debug_log true
      jabber_warnings_log true
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

### 0.2.0(unreleased)

* Add xhtml_format option

### 0.1.1

* Fix Encoding::CompatibilityError while parsing XMPP messages caused by default_internal is ASCII_8BIT.
* add jabber_debug_log and jabber_warnings_log options.

### 0.1.0

* Add license
* Updated Gemfile
* Change file location to fluent plugin standard.
* Add format option
* Add test
* Add jid/password option

### 0.0.1

* Initial release.
