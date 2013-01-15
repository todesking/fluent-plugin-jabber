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

  def configure(conf)
    super
  end

  def start
    user_info = Pit.get(@pit_id, require: {
      'jid' => 'jid',
      'password' => 'password',
    })

    jid = Jabber::JID.new(user_info['jid'])
    @client = Jabber::Client.new(jid)
    @client.connect
    @client.auth(user_info['password'])

    @muc_client = Jabber::MUC::MUCClient.new(@client)
    @muc_client.join(@room)

    $log.info("out_jabber plugin initialized(jid: #{user_info['jid']}, room: #{@room})")
  end

  def shutdown
    @client.close
  end

  def emit(tag, es, chain)
    es.each do|time, record|
      @muc_client.send create_message(time, record)
    end
    chain.next
  end

  def create_message(time, record)
    raise "record['body'] is empty" unless record['body']
    Jabber::Message.new(@room, record['body'])
  end
end
