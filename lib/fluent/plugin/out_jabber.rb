require 'fluent/plugin'
require 'fluent/config'
require 'fluent/output'

require 'xmpp4r'
require 'xmpp4r/muc'

require 'pit'

# Deal with Fluentd's Encoding.default_internal = 'ASCII_8BIT'.
class ::REXML::IOSource
  alias orig_readline readline
  def readline(*args)
    line = orig_readline(*args)
    line = line.force_encoding(::Encoding::UTF_8) if line.encoding == ::Encoding::ASCII_8BIT
    line
  end
end

class Fluent::JabberOutput < Fluent::Output
  Fluent::Plugin.register_output('jabber', self)

  config_param :pit_id, :string, default: nil
  config_param :jid, :string, default: nil
  config_param :password, :string, default: nil

  # Currently, output target is group chat only.
  config_param :room, :string

  # Plain text/XHTML format. These options are exclusive.
  config_param :format, :string
  config_param :xhtml_format, :string, default: nil

  # Enable error/warning logs of XMPP4R
  # This configuration is global
  config_param :jabber_debug_log, :bool, default: false
  config_param :jabber_warnings_log, :bool, default: false

  attr_reader :jid
  attr_reader :password

  def configure(conf)
    super

    raise Fluent::ConfigError, "jid/password and pit_id is exclusive!!" if (@jid || @password) && @pit_id

    if @pit_id
      user_info = Pit.get(@pit_id, require: {
        'jid' => 'jid',
        'password' => 'password',
      })
      @jid = user_info['jid']
      @password = user_info['password']
    end

    Jabber.debug = true if jabber_debug_log
    Jabber.warnings = true if jabber_warnings_log
  end

  def start
    jid = Jabber::JID.new(@jid)
    @client = Jabber::Client.new(jid)
    @client.connect
    @client.auth(@password)

    @muc_client = Jabber::MUC::MUCClient.new(@client)
    @muc_client.join(@room)

    $log.info("out_jabber plugin initialized(jid: #{self.jid}, room: #{self.room})")
  end

  def shutdown
    @client.close
  end

  def emit(tag, es, chain)
    es.each do|time, record|
      send_message plain_text_format(time, record), xhtml_format(time, record)
    end
    chain.next
  end

  def plain_text_format(time, record)
    format_with(@format, time, record, false)
  end

  def xhtml_format(time, record)
    format_with(@xhtml_format, time, record, true)
  end

  def format_with(format_string, time, record, need_escape)
    return nil unless format_string
    format_string.gsub(/\\n/, "\n").gsub(/\\{sharp}/,'#').gsub(/\${([\w.]+)(?:\|([\w]+))?}/) {
      data = $1.split('.').inject(record) {|r,k| (r||{})[k]}
      filter = $2
      case filter
      when nil
        data = escape_xhtml(data) if need_escape
      when 'br'
        data = escape_xhtml(data).gsub(/\n/, '<br />')
      else
        raise "Unknown filter: #{filter}"
      end
      data
    }
  end

  def escape_xhtml(data)
    REXML::Text.new(data.to_s, true, nil, false).to_s
  end

  def send_message(plain_text, xhtml_text)
    message = Jabber::Message.new(@room, plain_text.force_encoding(Encoding::UTF_8))
    set_xhtml_message(message, xhtml_text) if xhtml_text

    @muc_client.send message
  end

  def set_xhtml_message(message, xhtml_text)
    # http://devblog.famundo.com/articles/2006/10/18/ruby-and-xmpp-jabber-part-3-adding-html-to-the-messages
    # Create the html part
    h = REXML::Element::new("html")
    h.add_namespace('http://jabber.org/protocol/xhtml-im')

    # The body part with the correct namespace
    b = REXML::Element::new("body")
    b.add_namespace('http://www.w3.org/1999/xhtml')

    # This suggested method not works for me:
    #   REXML::Text.new( message, false, nil, true, nil, %r/.^/ )
    # So I try alternative.
    REXML::Document.new("<div>#{xhtml_text}</div>").children.each do|c|
      b.add c
    end

    h.add(b)

    # Add the html element to the message
    message.add_element(h)
  end
end
