require 'fluent/plugin'
require 'fluent/config'
require 'fluent/output'

require 'xmpp4r'
require 'xmpp4r/muc'

require 'pit'

class Fluent::JabberOutput < Fluent::Output
  Fluent::Plugin.register_output('jabber', self)

  config_param :pit_id, :string

  # Currently, output target is group chat only.
  config_param :room, :string

  config_param :format, :string

  attr_reader :jid
  attr_reader :password

  def configure(conf)
    super

    user_info = Pit.get(@pit_id, require: {
      'jid' => 'jid',
      'password' => 'password',
    })
    @jid = user_info['jid']
    @password = user_info['password']
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
