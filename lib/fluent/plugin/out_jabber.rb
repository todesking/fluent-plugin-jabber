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
  config_param :format, :string, default: nil
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
    raise Fluent::ConfigError, "format and xhtml_format is exclusive!!" if @format && @xhtml_format
    raise Fluent::ConfigError, "format or xhtml_format is required" unless @format || @xhtml_format

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
      send_message create_message(time, record)
    end
    chain.next
  end

  def create_message(time, record)
    message = @format.gsub(/\\n/, "\n").gsub(/\${([\w.]+)}/) { $1.split('.').inject(record) {|r,k| (r||{})[k]} }
  end

  def send_message(message)
    @muc_client.send Jabber::Message.new(@room, message)
  end
end
