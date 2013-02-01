require 'fluent/log'
$log = Fluent::Log.new(STDERR, Fluent::Log::LEVEL_FATAL)

require 'fluent/plugin/out_jabber'

def create_fluent_config(hash, root = Fluent::Config.new)
  hash.each do|k,v|
    case v
    when String
      root[k.to_s] = v
    when Hash
      child = root.add_element(k.to_s, v[:__arg__] || nil)
      create_fluent_config(v.dup.delete(:__arg__), child)
    else
      raise "Invalid value: #{v.inspect}"
    end
  end
  root
end

describe Fluent::JabberOutput do
  let(:default_config) {
    {
      pit_id: 'jabber',
      room: 'the_room@conference.example.com',
      format: 'message: ${message}',
    }
  }

  let(:chain) { double('chain') }

  context 'configuring(with pit)' do
    before :each do
      config = create_fluent_config(default_config)

      Pit.stub(:get).with('jabber', anything).and_return('jid' => 'jabber@example.com', 'password' => 'pa55w0rd')

      subject.configure(config)
    end

    its(:jid) { should == 'jabber@example.com' }
    its(:password) { should == 'pa55w0rd' }
    its(:room) { should == 'the_room@conference.example.com' }
  end

  context 'configureing(with jid/password)' do
    before :each do
      config_hash = default_config.merge(jid: 'jabber@example.com', password: 'pa55w0rd')
      config_hash.delete :pit_id
      config = create_fluent_config(config_hash)

      subject.configure(config)
    end

    its(:jid) { should == 'jabber@example.com' }
    its(:password) { should == 'pa55w0rd' }
    its(:room) { should == 'the_room@conference.example.com' }
  end

  context 'config contains jid and pit_id' do
    it 'should error' do
      config_hash = default_config.merge(jid: 'jabber@example.com', password: 'pa55w0rd')
      config = create_fluent_config(config_hash)

      expect { subject.configure config }.to raise_error Fluent::ConfigError
    end
  end

  context 'config not contains format' do
    it 'should raise ConfigError' do
      config_hash = default_config.reject{|k,v| [:format].include? k}
      config = create_fluent_config(config_hash)

      expect { subject.configure config }.to raise_error Fluent::ConfigError
    end
  end

  context 'connecting' do
    it 'should connect with configured parameters' do
      Pit.stub(:get).with('jabber', anything).and_return('jid' => 'jabber@example.com', 'password' => 'pa55w0rd')

      jabber_client = double('jabber_client')
      muc_client = double('muc_client')

      Jabber::Client.stub(:new).with(Jabber::JID.new('jabber@example.com')).ordered.and_return(jabber_client)
      jabber_client.should_receive(:connect).ordered
      jabber_client.should_receive(:auth).with('pa55w0rd').ordered

      Jabber::MUC::MUCClient.stub(:new).with(jabber_client).ordered.and_return(muc_client)
      muc_client.should_receive(:join).with('the_room@conference.example.com')

      subject.configure create_fluent_config(default_config)
      subject.start
    end
  end

  context 'emitting' do
    let(:format) { 'hello!' }
    before :each do
      config = create_fluent_config(default_config.merge format: format)

      Pit.stub(:get).with('jabber', anything).and_return('jid' => 'jabber@example.com', 'password' => 'pa55w0rd')

      subject.configure(config)
    end

    it 'should send message to jabber conference room' do
      subject.should_receive(:send_message).with('hello!', nil).twice
      chain.should_receive(:next).once

      subject.emit('tag', [[0, {}], [1, {'a'=>'b'}]], chain)
    end

    context :format do
      let(:format) { 'a=${a}, x.y=${x.y}' }

      it 'should format message with received record' do
        subject.should_receive(:send_message).with('a=1, x.y=2', nil).ordered
        subject.should_receive(:send_message).with('a=1, x.y=', nil).ordered
        chain.should_receive(:next).once

        subject.emit('tag', [[0, {'a'=>1, 'x'=>{'y'=>2}}], [1, {'a'=>1}]], chain)
      end
    end

    context 'special notations' do
      let(:format) { 'a\n\{sharp}' }

      it 'should handle some special notations' do
        subject.should_receive(:send_message).with("a\n#", nil)
        chain.should_receive(:next).once

        subject.emit('tag', [[0, {}]], chain)
      end
    end
  end

  context 'filter' do
    context '|br' do
      it 'should convert CR to <br />' do
        subject.format_with('${a|br}', 0, {'a'=>"a\nb"}, false).should == "a<br />b"
      end
      it 'should convert CR to <br />, after xhtml_escape' do
        subject.format_with('${a|br}', 0, {'a'=>"<>\n"}, false).should == "&lt;&gt;<br />"
      end
    end
  end

  context 'xhtml_format' do
    let(:xhtml_format) { '<p>${message}</p>' }
    let(:format) { '${message}' }
    before :each do
      config_hash = default_config.merge(
        xhtml_format: xhtml_format,
        format: format,
      )
      config = create_fluent_config(config_hash)

      Pit.stub(:get).with('jabber', anything).and_return('jid' => 'jabber@example.com', 'password' => 'pa55w0rd')

      subject.configure(config)
    end

    it 'should send xml-escaped record data to jabber' do
      subject.should_receive(:send_message).with('><', '<p>&gt;&lt;</p>')
      chain.should_receive(:next).once

      subject.emit('tag', [[0, {'message' => '><'}]], chain)
    end
  end
end
